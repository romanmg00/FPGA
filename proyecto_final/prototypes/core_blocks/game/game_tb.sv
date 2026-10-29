// game_tb: replays the 12 M2 scenarios through game_core + fast_core on two
// independent clocks and writes each Step log in model/steplog.py format.
// Compare with: python3 tools/steplog_diff.py <name>.model.log <name>.hdl.log
// (run_game.sh does this for every scenario).
//
// Inputs enter at the board-facing seams of fast_core: one-cycle debounced
// button pulses, and UART bytes through uart_cmd_decode. Switch levels go to
// game_core's raw synchronizer inputs. Each scenario starts with a reset of
// both domains held across one game edge, as the stretched reset will be.
// The game clock is N fast cycles plus PHASE ns, free-running (no alignment).
module game_tb;
    import game_pkg::*;
    parameter integer N = 16384;          // fast cycles per game tick
    parameter integer PHASE = 3;          // extra ns per game half period (keeps clocks unrelated)
    parameter integer WINDOW = 12000;     // fast_core publish window, below N

    logic clk = 0, clk_juego = 0, rst_fast = 1, rst_game = 1;
    always #5 clk = !clk;                                  // 100 MHz sim fast clock
    always #(N * 5 + PHASE) clk_juego = !clk_juego;

    // Scenario parameters and board inputs
    logic [31:0] seed;
    logic fixed_seed;
    logic [12:0] start_p1, start_p2;
    logic [1:0] dir_p1, dir_p2;
    logic [15:0] sw = 0;
    logic [4:0] btn_pulse = 0;
    logic [7:0] rx_byte = 0;
    logic rx_valid = 0;

    // Interconnect
    logic tick_tgl, cmd_new_match, cmd_survive_p1, cmd_survive_p2;
    logic [1:0] cmd_op;
    logic [3:0] cmd_seq, rsp_seq, rsp_code_p1, rsp_code_p2, batch_axes_p1, batch_axes_p2;
    logic batch_start;
    logic [31:0] cmd_seed_mix;
    logic [12:0] cmd_a_p1, cmd_a_p2, cmd_b_p1, cmd_b_p2;
    logic [2:0] cmd_collected, phase, uart_cmd;
    logic paused, crashed_p1, crashed_p2, head_on, page_lives, overrun, uart_cmd_valid;
    logic [7:0] phase_ticks, round_index;
    logic [12:0] head_p1, head_p2;
    logic [1:0] shown_p1, shown_p2, lives_p1, lives_p2, result, log_kind;
    logic [5:0] points_p1, points_p2, points_goal;
    logic [15:0] step_count;
    // fast_core outputs
    logic [2:0] snap_phase;
    logic snap_paused, snap_crashed_p1, snap_crashed_p2, snap_page_lives, tick_seen;
    logic [7:0] snap_phase_ticks;
    logic [12:0] snap_head_p1, snap_head_p2, slot0_cell, slot1_cell, slot2_cell;
    logic [5:0] snap_points_p1, snap_points_p2;
    logic [1:0] snap_lives_p1, snap_lives_p2;
    logic [3:0] b_rdata;
    logic slot0_valid, slot1_valid, slot2_valid, svc_busy, late_publish;

    game_core dut_game (.clk(clk_juego), .rst(rst_game), .sw_pause(sw[0]), .sw_goal_lo(sw[14]),
        .sw_goal_hi(sw[15]), .start_p1, .start_p2, .start_dir_p1(dir_p1), .start_dir_p2(dir_p2),
        .rsp_seq, .rsp_code_p1, .rsp_code_p2, .batch_axes_p1, .batch_axes_p2, .batch_start,
        .tick_tgl, .cmd_op, .cmd_seq, .cmd_new_match, .cmd_seed_mix, .cmd_a_p1, .cmd_a_p2,
        .cmd_b_p1, .cmd_b_p2, .cmd_survive_p1, .cmd_survive_p2, .cmd_collected,
        .phase, .paused, .phase_ticks, .head_p1, .head_p2, .shown_p1, .shown_p2,
        .crashed_p1, .crashed_p2, .head_on, .points_p1, .points_p2, .points_goal,
        .lives_p1, .lives_p2, .result, .page_lives, .round_index, .step_count, .log_kind, .overrun);

    uart_cmd_decode u_dec (.clk, .rst(rst_fast), .rx_valid, .rx_byte, .cmd(uart_cmd), .cmd_valid(uart_cmd_valid));

    fast_core #(.WINDOW(WINDOW)) dut_fast (.clk, .rst(rst_fast), .seed, .fixed_seed, .tick_tgl,
        .cmd_op, .cmd_seq, .cmd_new_match, .cmd_seed_mix, .cmd_a_p1, .cmd_a_p2, .cmd_b_p1, .cmd_b_p2,
        .cmd_survive_p1, .cmd_survive_p2, .cmd_collected,
        .g_phase(phase), .g_paused(paused), .g_phase_ticks(phase_ticks),
        .g_head_p1(head_p1), .g_head_p2(head_p2), .g_shown_p1(shown_p1), .g_shown_p2(shown_p2), .g_crashed_p1(crashed_p1), .g_crashed_p2(crashed_p2),
        .g_points_p1(points_p1), .g_points_p2(points_p2), .g_lives_p1(lives_p1), .g_lives_p2(lives_p2),
        .g_page_lives(page_lives), .rsp_seq, .rsp_code_p1, .rsp_code_p2,
        .batch_axes_p1, .batch_axes_p2, .batch_start, .btn_pulse, .uart_cmd_valid, .uart_cmd,
        .snap_phase, .snap_paused, .snap_phase_ticks, .snap_head_p1, .snap_head_p2,
        .snap_shown_p1(), .snap_shown_p2(),
        .snap_crashed_p1, .snap_crashed_p2, .snap_points_p1, .snap_points_p2,
        .snap_lives_p1, .snap_lives_p2, .snap_page_lives, .tick_seen,
        .b_addr(13'd0), .b_rdata, .slot0_valid, .slot1_valid, .slot2_valid,
        .slot0_cell, .slot1_cell, .slot2_cell, .svc_busy, .late_publish);

    // --- Step-log formatting (model/steplog.py) ------------------------------
    function automatic string phase_name(input logic [2:0] p);
        case (p)
            3'd0: return "IDLE"; 3'd1: return "PLAY"; 3'd2: return "CRASH";
            3'd3: return "READY"; 3'd4: return "MATCH_OVER"; 3'd5: return "PREP";
            default: return "?";
        endcase
    endfunction
    function automatic string letter(input logic [1:0] d);
        case (d) 2'd0: return "U"; 2'd1: return "R"; 2'd2: return "D"; default: return "L"; endcase
    endfunction
    function automatic string cell_text(input logic v, input logic [12:0] c);
        if (!v) return "-";
        return $sformatf("%0d,%0d", c[6:0], c[12:7]);
    endfunction
    function automatic string res(input logic [1:0] r);
        case (r) 2'd0: return "-"; 2'd1: return "P1"; 2'd2: return "P2"; default: return "draw"; endcase
    endfunction

    // --- scenario replay -----------------------------------------------------
    integer ev_f, log_f, ticks, end_tick, ev_tick, ev_kind, ev_val, r, total_lines, scenarios;
    integer p1x, p1y, p1d, p2x, p2y, p2d, fx, late_total, overrun_total;
    string names[$], name, line;

    task automatic pulse_btn(input logic [4:0] mask);
        @(posedge clk) btn_pulse <= mask;
        @(posedge clk) btn_pulse <= 0;
        repeat (2) @(posedge clk);
    endtask
    task automatic send_byte(input logic [7:0] b);
        @(posedge clk) begin rx_byte <= b; rx_valid <= 1; end
        @(posedge clk) rx_valid <= 0;
        repeat (3) @(posedge clk);
    endtask
    task automatic reset_both();
        rst_fast <= 1; rst_game <= 1;
        @(posedge clk_juego);                       // the reset edge, not a counted tick
        #1 rst_game <= 0;
        @(posedge clk) rst_fast <= 0;
        ticks = 0;
    endtask

    // Apply every event of `tick`; ev_* holds the next unread event.
    task automatic apply_inputs(input integer tick);
        while (ev_tick == tick) begin
            case (ev_kind)
                0: reset_both();
                1: pulse_btn(ev_val[4:0]);
                2: send_byte(ev_val[7:0]);
                3: sw = ev_val[15:0];
                default: $fatal(1, "bad event kind %0d", ev_kind);
            endcase
            r = $fscanf(ev_f, "%d %d %d", ev_tick, ev_kind, ev_val);
        end
    endtask

    initial begin
        fx = $fopen("src/prototypes/core_blocks/game/scenarios/manifest.txt", "r");
        if (fx == 0) $fatal(1, "missing manifest");
        while ($fscanf(fx, "%s", name) == 1) names.push_back(name);
        $fclose(fx);
        total_lines = 0; scenarios = 0; late_total = 0; overrun_total = 0;
        foreach (names[i]) begin
            name = names[i];
            ev_f = $fopen({"src/prototypes/core_blocks/game/scenarios/", name, ".events"}, "r");
            if (ev_f == 0) $fatal(1, "missing events for %s", name);
            r = $fscanf(ev_f, "%d %d %d %d %d %d %d %d %d", seed, fx, p1x, p1y, p1d, p2x, p2y, p2d, end_tick);
            fixed_seed = fx[0];
            start_p1 = {p1y[5:0], p1x[6:0]}; start_p2 = {p2y[5:0], p2x[6:0]};
            dir_p1 = p1d[1:0]; dir_p2 = p2d[1:0];
            sw = 0;
            r = $fscanf(ev_f, "%d %d %d", ev_tick, ev_kind, ev_val);
            log_f = $fopen({name, ".hdl.log"}, "w");
            reset_both();
            repeat (N - 400) @(posedge clk);
            for (int tick = 1; tick <= end_tick; tick++) begin
                apply_inputs(tick);
                @(posedge clk_juego);
                ticks++;
                repeat (N - 400) @(posedge clk);    // fast work for this tick is done
                if (late_publish) late_total++;
                if (overrun) overrun_total++;
                if (log_kind != 0) begin
                    line = $sformatf("tick=%0d round=%0d step=%0d phase=%s p1=%0d,%0d,%s p2=%0d,%0d,%s crash=%0d%0d points=%0d,%0d lives=%0d,%0d goal=%0d r0=%s r1=%s r2=%s result=%s",
                        ticks, round_index, log_kind == 1 ? 0 : step_count, phase_name(phase),
                        head_p1[6:0], head_p1[12:7], letter(shown_p1),
                        head_p2[6:0], head_p2[12:7], letter(shown_p2),
                        crashed_p1, crashed_p2, points_p1, points_p2, lives_p1, lives_p2, points_goal,
                        cell_text(slot0_valid, slot0_cell), cell_text(slot1_valid, slot1_cell),
                        cell_text(slot2_valid, slot2_cell), res(result));
                    $fdisplay(log_f, "%s", line);
                    total_lines++;
                end
            end
            $fclose(log_f);
            $fclose(ev_f);
            scenarios++;
            $display("REPLAYED %s ticks=%0d", name, end_tick);
        end
        if (overrun_total != 0) $fatal(1, "Step cadence overrun seen in %0d ticks", overrun_total);
        if (late_total != 0) $fatal(1, "late publish seen in %0d ticks", late_total);
        $display("SUMMARY scenarios=%0d log_lines=%0d N=%0d PHASE=%0d WINDOW=%0d", scenarios, total_lines, N, PHASE, WINDOW);
        $display("PASS game_tb");
        $finish;
    end
endmodule
