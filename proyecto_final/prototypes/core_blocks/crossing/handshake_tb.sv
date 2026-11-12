// handshake_tb: protocol bench for the fast -> game response channel of the
// qualified crossing (game_core QUALIFIED = 1). Independent of fast_core and
// the model: a behavioural fast side answers each command after a random
// service delay and sprays random junk on rsp_code_* while it is busy, so any
// use of the codes before the synchronized qualification would pick junk.
//
// Delays cover: well inside the tick, just before the next game edge, just
// after it, and more than a tick. A toggle published less than 1 ns before a
// game edge is, at random, made visible just after that edge instead: the
// digital stand-in for a first synchronizer stage that resolves late.
//
// Checked at every game edge:
//   C1 a Step resolves only with the final codes of its own READ2, and those
//      codes were stable for more than two game periods;
//   C2 a new command is issued only when the previous one was answered
//      (rsp_sync == cmd_seq[0] before the edge): one outstanding command;
//   C3 each READ2 resolves exactly once;
//   C4 latency: with the toggle visible before game edge e1, the Step resolves
//      at e1 + 2 + RSP_REG (k + 3 + RSP_REG when the service ends inside the
//      tick), unless Pause intervened;
//   C5 phase A (service always inside the tick, no Pause): every READ2
//      resolves at k + 3 + RSP_REG and launches are exactly STEP apart, with
//      no deferred launch. Phase B (all delays, Pause): deferrals allowed, and
//      every launch is at least STEP after the last one.
// RSP_REG = 1 with STEP = 8 is the "captured" variant (ADR 0007).
module handshake_tb;
    import game_pkg::*;
    parameter integer STEPS_A = 600;          // Steps with service inside the tick
    parameter integer STEPS_B = 2400;         // Steps with every delay class and Pause
    parameter bit RSP_REG = 1'b0;             // game_core captures the codes first
    parameter integer STEP = 6;               // game ticks per Step
    localparam real HALF = 5003.0;            // ns; game period TG = 10006 ns
    localparam real TG = 2.0 * HALF;

    logic clk = 0, rst = 1;
    always #(HALF) clk = !clk;

    logic sw_pause = 0;
    logic [3:0] rsp_seq = 0, rsp_code_p1 = 0, rsp_code_p2 = 0, axes_p1 = 0, axes_p2 = 0;
    logic tick_tgl, cmd_new_match, cmd_survive_p1, cmd_survive_p2;
    logic [1:0] cmd_op;
    logic [3:0] cmd_seq;
    logic [31:0] cmd_seed_mix;
    logic [12:0] cmd_a_p1, cmd_a_p2, cmd_b_p1, cmd_b_p2, head_p1, head_p2;
    logic [2:0] cmd_collected, phase;
    logic paused, crashed_p1, crashed_p2, head_on, page_lives, page_goal, overrun;
    logic [1:0] goal_sel;
    logic [7:0] phase_ticks, round_index;
    logic [1:0] shown_p1, shown_p2, lives_p1, lives_p2, result, log_kind;
    logic [5:0] points_p1, points_p2, points_goal;
    logic [15:0] step_count;

    game_core #(.QUALIFIED(1'b1), .RSP_REG(RSP_REG), .STEP_TICKS(STEP), .CRASH_TICKS(4), .VIEW_TICKS(8)) dut (.clk, .rst,
        .sw_pause, .sw_goal_lo(1'b1), .sw_goal_hi(1'b1),
        .start_p1({SAL_CY, SAL_P1_CX}), .start_p2({SAL_CY, SAL_P2_CX}),
        .start_dir_p1(DIR_RIGHT), .start_dir_p2(DIR_LEFT),
        .rsp_seq, .rsp_code_p1, .rsp_code_p2, .batch_axes_p1(axes_p1), .batch_axes_p2(axes_p2),
        .batch_start(1'b1), .tick_tgl, .cmd_op, .cmd_seq, .cmd_new_match, .cmd_seed_mix,
        .cmd_a_p1, .cmd_a_p2, .cmd_b_p1, .cmd_b_p2, .cmd_survive_p1, .cmd_survive_p2, .cmd_collected,
        .phase, .paused, .phase_ticks, .head_p1, .head_p2, .shown_p1, .shown_p2,
        .crashed_p1, .crashed_p2, .head_on, .points_p1, .points_p2, .points_goal,
        .lives_p1, .lives_p2, .result, .page_lives, .page_goal, .goal_sel, .round_index, .step_count, .log_kind, .overrun);

    integer errors = 0;
    task automatic fail(input string what);
        errors++;
        if (errors <= 20) $error("%s", what);
    endtask

    function automatic integer edge_index(input real t);      // posedge m is at HALF + m * TG
        return $rtoi((t - HALF) / TG + 0.5);
    endfunction
    function automatic integer next_edge(input real t);       // first posedge strictly after t
        return $rtoi($floor((t - HALF) / TG)) + 1;
    endfunction

    // --- behavioural fast side ------------------------------------------------
    bit phase_b = 0;
    integer issued = 0;                        // commands seen; id of the newest
    logic [3:0] final_p1 [int], final_p2 [int];
    real pub_time [int], vis_time [int], issue_time [int];
    integer expect_edge [int];
    integer n_inject = 0, n_junk = 0, n_before = 0, n_after = 0, n_long = 0;
    bit busy = 0;

    function automatic real service_delay();
        integer r = $urandom_range(99);
        if (!phase_b || r < 70) return 24.0 + $urandom_range(30000) / 10.0;     // 24 ns .. 3 us
        if (r < 85) begin n_before++; return TG - 0.05 - $urandom_range(5000) / 100.0; end
        if (r < 95) begin n_after++;  return TG + 0.05 + $urandom_range(5000) / 100.0; end
        n_long++;
        return TG * (1.0 + $urandom_range(150, 1) / 100.0) + 0.37;   // never on an edge
    endfunction
    function automatic logic [3:0] read_code();
        integer r = $urandom_range(999);
        if (r < 880) return CELL_EMPTY;
        if (r < 910) return CELL_REWARD0;
        if (r < 940) return CELL_REWARD1;
        if (r < 970) return CELL_REWARD2;
        if (r < 980) return CELL_WALL;
        if (r < 990) return CELL_P1_TRAIL;
        return CELL_P2_HEAD;
    endfunction

    task automatic serve(input integer id, input logic [3:0] seq);
        real t_end, t_pub, tn;
        logic [3:0] f1, f2;
        issue_time[id] = $realtime;
        t_end = $realtime + service_delay();
        f1 = read_code(); f2 = read_code();
        #5;                                    // tick_seen comes a few fast cycles after the edge
        while ($realtime + 7.0 < t_end) begin
            rsp_code_p1 = $urandom; rsp_code_p2 = $urandom; n_junk++;
            #7;
        end
        #(t_end - $realtime);
        rsp_code_p1 = f1; rsp_code_p2 = f2;
        t_pub = $realtime;
        final_p1[id] = f1; final_p2[id] = f2; pub_time[id] = t_pub;
        tn = HALF + next_edge(t_pub) * TG;
        if (tn - t_pub < 1.0 && $urandom_range(1)) begin
            #(tn - t_pub + 0.5);               // synchronizer resolves late: old value at tn
            n_inject++;
        end
        rsp_seq = seq;
        vis_time[id] = $realtime;
        expect_edge[id] = next_edge($realtime) + 2 + RSP_REG;
        busy = 0;
    endtask

    initial begin
        logic [3:0] seen;
        seen = 0;
        forever begin
            @(cmd_seq);
            if (cmd_seq == seen) continue;
            if (busy) fail($sformatf("command %0d issued while command %0d was in service", issued + 1, issued));
            seen = cmd_seq;
            issued++;
            busy = 1;
            fork
                automatic integer id = issued;
                automatic logic [3:0] s = cmd_seq;
                serve(id, s);
            join_none
        end
    end

    // --- checks at each game edge (pre-edge values) ---------------------------
    integer read2_id [int];                    // edge of launch -> command id, by command id
    integer launch_edge [int];
    bit paused_during [int];
    bit resolved [int];
    integer last_launch = -1, n_resolve = 0, n_read2 = 0, n_defer = 0, lat3 = 0, lat_other = 0;
    integer cur_read2 = -1, steps_a_done = 0;
    integer hist [8] = '{default: 0};

    always @(posedge clk) if (!rst) begin
        automatic integer e = edge_index($realtime);
        // C2: one outstanding command
        if ((dut.launch || dut.resolve || dut.prepare) && !dut.idle)
            fail($sformatf("edge %0d: command issued while the last was unanswered", e));
        if (dut.step_due && !dut.step_ready) n_defer++;
        if (sw_pause && cur_read2 >= 0) paused_during[cur_read2] = 1;
        // C1, C3, C4: resolution
        if (dut.resolve) begin
            n_resolve++;
            if (cur_read2 < 0) fail($sformatf("edge %0d: resolve without a READ2", e));
            else begin
                if (resolved.exists(cur_read2)) fail($sformatf("READ2 %0d resolved twice", cur_read2));
                resolved[cur_read2] = 1;
                if (!pub_time.exists(cur_read2))
                    fail($sformatf("edge %0d: READ2 %0d resolved before its response", e, cur_read2));
                else begin
                    if (dut.use_code_p1 !== final_p1[cur_read2] || dut.use_code_p2 !== final_p2[cur_read2])
                        fail($sformatf("edge %0d: READ2 %0d used codes %h,%h, final %h,%h", e, cur_read2,
                            dut.use_code_p1, dut.use_code_p2, final_p1[cur_read2], final_p2[cur_read2]));
                    if ($realtime - pub_time[cur_read2] <= 2.0 * TG - 2.0)
                        fail($sformatf("edge %0d: READ2 %0d codes stable only %0.3f ns", e, cur_read2,
                            $realtime - pub_time[cur_read2]));
                    if (!paused_during.exists(cur_read2) && e != expect_edge[cur_read2])
                        fail($sformatf("READ2 %0d resolved at edge %0d, expected %0d (launch %0d issue %0.3f pub %0.3f visible %0.3f, edge %0d at %0.3f)",
                            cur_read2, e, expect_edge[cur_read2], launch_edge[cur_read2], issue_time[cur_read2],
                            pub_time[cur_read2], vis_time[cur_read2], e, $realtime));
                    if (e - launch_edge[cur_read2] < 8) hist[e - launch_edge[cur_read2]]++;
                    if (e - launch_edge[cur_read2] == 3 + RSP_REG) lat3++; else lat_other++;
                    if (!phase_b && e - launch_edge[cur_read2] != 3 + RSP_REG)
                        fail($sformatf("phase A: READ2 %0d resolved at k + %0d", cur_read2, e - launch_edge[cur_read2]));
                end
                cur_read2 = -1;
                if (!phase_b) steps_a_done++;
            end
        end
        // C5: launch cadence
        if (dut.launch) begin
            n_read2++;
            cur_read2 = issued + 1;            // the command this edge issues
            launch_edge[cur_read2] = e;
            if (sw_pause) paused_during[cur_read2] = 1;
            if (last_launch >= 0 && dut.phase == G_PLAY && dut.step_count != 0) begin
                if (!phase_b && e - last_launch != STEP)
                    fail($sformatf("phase A: launch interval %0d", e - last_launch));
                if (e - last_launch < STEP)
                    fail($sformatf("launch interval %0d below STEP", e - last_launch));
            end
            last_launch = e;
        end
        if (dut.prepare || dut.start_release || dut.prep_done) last_launch = -1;
    end

    // Random Turns on the (already qualified) batch inputs; Pause in phase B.
    always @(negedge clk) begin
        axes_p1 <= ($urandom_range(9) == 0) ? {1'b1, 1'($urandom), 1'b1, 1'($urandom)} : 4'd0;
        axes_p2 <= ($urandom_range(9) == 0) ? {1'b1, 1'($urandom), 1'b1, 1'($urandom)} : 4'd0;
        if (phase_b && $urandom_range(199) == 0) sw_pause <= !sw_pause;
    end

    initial begin
        repeat (3) @(posedge clk);
        #1 rst = 0;
        wait (steps_a_done >= STEPS_A);
        @(negedge clk) phase_b = 1;
        wait (n_resolve >= STEPS_A + STEPS_B);
        @(negedge clk) sw_pause = 0;
        repeat (40) @(posedge clk);
        if (overrun && n_defer == 0) fail("overrun flag set without a deferred launch");
        $display("STATS read2=%0d resolved=%0d commands=%0d deferred_edges=%0d junk_writes=%0d", n_read2, n_resolve, issued, n_defer, n_junk);
        $display("STATS delays: before_edge=%0d after_edge=%0d long=%0d late_sync_injected=%0d", n_before, n_after, n_long, n_inject);
        $display("STATS RSP_REG=%0d STEP=%0d READ2 latency k+%0d=%0d other=%0d  histogram k+3..k+7: %0d %0d %0d %0d %0d",
            RSP_REG, STEP, 3 + RSP_REG, lat3, lat_other, hist[3], hist[4], hist[5], hist[6], hist[7]);
        if (errors != 0) $fatal(1, "%0d protocol errors", errors);
        $display("PASS handshake_tb");
        $finish;
    end
    initial begin
        #(TG * 200000);
        $fatal(1, "timeout: resolved %0d", n_resolve);
    end
endmodule
