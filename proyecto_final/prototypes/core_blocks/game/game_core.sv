// game_core: the game-clock half of the Tron core (match_ctrl G3 with the Step
// unit, Turn units and score unit). Owners: Alan (match_ctrl, score_unit),
// Roman (turn_unit, Step FSM, step_resolve), composed here as provisional
// evidence. Domain: clk = clk_juego (~60 Hz, ADR 0002).
//
// Mirrors prototipos/tron_fpga/model/game_top.py Game._game_edge register by
// register, so the HDL Step log can be compared with the model's.
//
// PROVISIONAL (ADR 0005): every port. The crossing (ADR 0003 item 2) is
// open; QUALIFIED selects one of two candidates:
//   game -> fast  (both) cmd_* and snap_* change only on a clk_juego edge, and
//                 tick_tgl toggles on every edge so the fast side can latch
//                 them after a 2-FF synchronizer (fast_core).
//   fast -> game, QUALIFIED = 0: the model's stable-payload mailbox. rsp_* and
//                 batch_* are published by the fast side only in a bounded
//                 window after it sees tick_tgl. This core registers them
//                 once per edge (cap_*) and uses the captured copy at the
//                 following edge: a command issued at edge k is answered at
//                 k + 2. Vivado reports the cap_* registers as unknown CDC.
//   fast -> game, QUALIFIED = 1: two-phase req/ack (crossing/FINDINGS.md).
//                 cmd_seq[0] is the request toggle; the fast side holds
//                 rsp_code_* and echoes it on rsp_seq[0] once they are final.
//                 Only rsp_seq[0] is synchronized (2-FF, ASYNC_REG); the held
//                 codes are used directly, and only under that synchronized
//                 qualification (idle), at edge k + 3. Every register a code
//                 can change is written on each resolve (enable = resolve),
//                 never held on a code-dependent condition, so the enable
//                 stays synchronized. batch_* come from batch_fifo's
//                 game-domain read register.
//   QUALIFIED = 1, RSP_REG = 1 ("captured"): the held codes are first copied
//                 into code_q, enabled only by a new synchronized toggle, and
//                 the game uses code_q: answered at k + 4, so READ2 + COMMIT
//                 take 8 ticks (ADR 0007: STEP_TICKS 8..10). No game register
//                 then depends combinationally on a fast-domain word.
// A Step launch that finds the last COMMIT unfinished is deferred, not
// overlapped: it waits with step_cnt held and sets the sticky overrun flag.
// sw_pause and sw_goal are raw pins: 2-FF synchronized here (model sw_sync).
// Crash code 6 is written by the fast side's COMMIT (ADR 0003 item 4).
module game_core #(
    parameter bit     QUALIFIED   = 1'b0,
    parameter bit     RSP_REG     = 1'b0,                    // QUALIFIED only: capture the codes first
    parameter integer STEP_TICKS  = game_pkg::STEP_TICKS,
    parameter integer CRASH_TICKS = game_pkg::CRASH_TICKS,
    parameter integer VIEW_TICKS  = game_pkg::SCORE_VIEW_TICKS
) (
    input  logic        clk, rst,
    input  logic        sw_pause, sw_goal_lo, sw_goal_hi,    // raw pins
    input  logic [12:0] start_p1, start_p2,                  // {cy, cx}
    input  logic [1:0]  start_dir_p1, start_dir_p2,
    // fast -> game (stable bus, captured every edge)
    input  logic [3:0]  rsp_seq,
    input  logic [3:0]  rsp_code_p1, rsp_code_p2,
    input  logic [3:0]  batch_axes_p1, batch_axes_p2,        // {v_valid, v_down, h_valid, h_left}
    input  logic        batch_start,
    // game -> fast
    output logic        tick_tgl,
    output logic [1:0]  cmd_op,                              // 1 PREPARE, 2 READ2, 3 COMMIT
    output logic [3:0]  cmd_seq,
    output logic        cmd_new_match,
    output logic [31:0] cmd_seed_mix,
    output logic [12:0] cmd_a_p1, cmd_a_p2,                  // PREPARE heads, READ2 targets, COMMIT old heads
    output logic [12:0] cmd_b_p1, cmd_b_p2,                  // COMMIT new heads
    output logic        cmd_survive_p1, cmd_survive_p2,
    output logic [2:0]  cmd_collected,                       // COMMIT: Reward slots to replace
    // render snapshot and Scoreboard (game -> fast)
    output logic [2:0]  phase,
    output logic        paused,
    output logic [7:0]  phase_ticks,
    output logic [12:0] head_p1, head_p2,
    output logic [1:0]  shown_p1, shown_p2,
    output logic        crashed_p1, crashed_p2, head_on,
    output logic [5:0]  points_p1, points_p2, points_goal,
    output logic [1:0]  lives_p1, lives_p2, result,
    output logic        page_lives,
    output logic        page_goal,                           // Scoreboard Goal page (seg7_page)
    output logic [1:0]  goal_sel,                            // synchronized {SW15, SW14}, for the Goal page
    // bench and debug
    output logic [7:0]  round_index,
    output logic [15:0] step_count,
    output logic [1:0]  log_kind,                            // 1 Round prepared, 2 Step outcome, this edge
    output logic        overrun                              // sticky: a launch waited for the last COMMIT
);
    import game_pkg::*;
    localparam logic [2:0] G_PREP = 3'd5;                    // model's preparation phase (Hardware Map)
    localparam logic [1:0] OP_PREPARE = 2'd1, OP_READ2 = 2'd2, OP_COMMIT = 2'd3;
    localparam logic [1:0] S_IDLE = 2'd0, S_READ = 2'd1, S_COMMIT = 2'd2;

    // --- fast -> game crossing and switch synchronizers ----------------------
    logic       rsp_idle;                                    // the outstanding command is answered
    logic [3:0] use_code_p1, use_code_p2, use_axes_p1, use_axes_p2;
    logic       use_start;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic pause_s1, pause_s2;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic goal_lo_s1, goal_lo_s2, goal_hi_s1, goal_hi_s2;
    logic [31:0] tick_cnt;

    // --- state ---------------------------------------------------------------
    logic [1:0]  state;
    logic [12:0] target_p1, target_p2;
    logic [1:0]  launched_p1, launched_p2;
    logic [7:0]  step_cnt;
    logic        prep_match;

    // --- combinational view of this edge (model's pre-edge values) ----------
    logic idle, running, step_due, launch, sw_paused, step_ready;
    (* DIRECT_ENABLE = "yes" *) logic resolve;               // keep the qualification on CE pins
    logic start, start_new, start_release, prep_done, crash_done;
    logic [7:0] phase_ticks_inc;
    logic [1:0] heading_p1, heading_p2, pending_p1, pending_p2, chosen_p1, chosen_p2;
    logic [12:0] next_p1, next_p2, new_p1, new_p2;
    logic c1, c2, ho;
    logic [1:0] slot_p1, slot_p2;
    logic goal_hit, prepare, prepare_new;

    generate
        if (QUALIFIED) begin : g_qualified
            (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic rsp_meta, rsp_sync;
            logic       rsp_tgl_q;                           // RSP_REG: toggle of the codes in code_q
            logic [3:0] code_q_p1, code_q_p2;
            always_ff @(posedge clk) begin
                if (rst) begin rsp_meta <= 0; rsp_sync <= 0; rsp_tgl_q <= 0; end
                else begin rsp_meta <= rsp_seq[0]; rsp_sync <= rsp_meta; rsp_tgl_q <= rsp_sync; end
            end
            always_ff @(posedge clk) begin                   // enable: a new synchronized toggle only
                if (rst) begin code_q_p1 <= 0; code_q_p2 <= 0; end
                else if (rsp_sync != rsp_tgl_q) begin code_q_p1 <= rsp_code_p1; code_q_p2 <= rsp_code_p2; end
            end
            always_comb begin
                rsp_idle = (RSP_REG ? rsp_tgl_q : rsp_sync) == cmd_seq[0];
                use_code_p1 = RSP_REG ? code_q_p1 : rsp_code_p1;
                use_code_p2 = RSP_REG ? code_q_p2 : rsp_code_p2;
                use_axes_p1 = batch_axes_p1; use_axes_p2 = batch_axes_p2; use_start = batch_start;
            end
        end else begin : g_mailbox
            logic [3:0] cap_seq, cap_code_p1, cap_code_p2, cap_axes_p1, cap_axes_p2;
            logic       cap_start;
            always_ff @(posedge clk) begin                   // every edge, paused or not
                if (rst) begin
                    cap_seq <= 0; cap_code_p1 <= 0; cap_code_p2 <= 0;
                    cap_axes_p1 <= 0; cap_axes_p2 <= 0; cap_start <= 0;
                end else begin
                    cap_seq <= rsp_seq; cap_code_p1 <= rsp_code_p1; cap_code_p2 <= rsp_code_p2;
                    cap_axes_p1 <= batch_axes_p1; cap_axes_p2 <= batch_axes_p2; cap_start <= batch_start;
                end
            end
            always_comb begin
                rsp_idle = cap_seq == cmd_seq;
                use_code_p1 = cap_code_p1; use_code_p2 = cap_code_p2;
                use_axes_p1 = cap_axes_p1; use_axes_p2 = cap_axes_p2; use_start = cap_start;
            end
        end
    endgenerate

    always_comb begin
        sw_paused = pause_s2;
        idle      = rsp_idle;
        running   = phase == G_PLAY && !sw_paused;
        step_ready = state == S_IDLE || (state == S_COMMIT && idle);
        step_due  = running && step_cnt == 8'(STEP_TICKS - 1);
        launch    = step_due && step_ready;
        resolve   = state == S_READ && idle && !sw_paused;
        phase_ticks_inc = (phase_ticks == 8'hFF) ? phase_ticks : phase_ticks + 8'd1;
        start     = !sw_paused && use_start && (phase == G_IDLE || phase == G_READY || phase == G_MATCH) && idle;
        start_new = start && (phase == G_IDLE || phase == G_MATCH);
        start_release = start && phase == G_READY;
        prep_done = !sw_paused && !start && phase == G_PREP && idle;
        crash_done = !sw_paused && !start && phase == G_CRASH && phase_ticks_inc >= 8'(CRASH_TICKS) && idle;
        prepare_new = start_new;
        prepare   = start_new || (crash_done && result == 2'd0);
        // The Heading this edge's launch takes: the Pending Turn after this
        // edge's batch (turn_unit applies the batch, then launches).
        chosen_p1 = pending_p1;
        chosen_p2 = pending_p2;
        if (running) begin
            if (heading_p1[0] && use_axes_p1[3]) chosen_p1 = use_axes_p1[2] ? DIR_DOWN : DIR_UP;
            if (!heading_p1[0] && use_axes_p1[1]) chosen_p1 = use_axes_p1[0] ? DIR_LEFT : DIR_RIGHT;
            if (heading_p2[0] && use_axes_p2[3]) chosen_p2 = use_axes_p2[2] ? DIR_DOWN : DIR_UP;
            if (!heading_p2[0] && use_axes_p2[1]) chosen_p2 = use_axes_p2[0] ? DIR_LEFT : DIR_RIGHT;
        end
        // Goal reached by this outcome without a Crash (the only outcome where
        // the model reads the new result on the same edge without a Crash).
        goal_hit = (points_p1 + (slot_p1 == 2'd2 ? 6'd3 : slot_p1 != 2'd3 ? 6'd1 : 6'd0)) >= points_goal ||
                   (points_p2 + (slot_p2 == 2'd2 ? 6'd3 : slot_p2 != 2'd3 ? 6'd1 : 6'd0)) >= points_goal;
    end

    turn_unit u_turn_p1 (.clk, .rst, .load(prepare), .load_heading(start_dir_p1),
        .v_valid(use_axes_p1[3]), .v_down(use_axes_p1[2]), .h_valid(use_axes_p1[1]), .h_left(use_axes_p1[0]),
        .apply(running), .launch, .heading(heading_p1), .pending(pending_p1));
    turn_unit u_turn_p2 (.clk, .rst, .load(prepare), .load_heading(start_dir_p2),
        .v_valid(use_axes_p2[3]), .v_down(use_axes_p2[2]), .h_valid(use_axes_p2[1]), .h_left(use_axes_p2[0]),
        .apply(running), .launch, .heading(heading_p2), .pending(pending_p2));
    next_cell u_next_p1 (.head(head_p1), .heading(chosen_p1), .target(next_p1));
    next_cell u_next_p2 (.head(head_p2), .heading(chosen_p2), .target(next_p2));
    step_resolve u_resolve (.head_p1, .head_p2, .target_p1, .target_p2,
        .code_p1(use_code_p1), .code_p2(use_code_p2), .new_head_p1(new_p1), .new_head_p2(new_p2),
        .crashed_p1(c1), .crashed_p2(c2), .head_on(ho), .collected_p1(slot_p1), .collected_p2(slot_p2));
    score_unit u_score (.clk, .rst, .new_match(start_new), .step_outcome(resolve),
        .goal_sel({goal_hi_s2, goal_lo_s2}), .crashed_p1(c1), .crashed_p2(c2),
        .collected_valid_p1(slot_p1 != 2'd3), .collected_valid_p2(slot_p2 != 2'd3),
        .collected_slot_p1(slot_p1), .collected_slot_p2(slot_p2),
        .points_p1, .points_p2, .lives_p1, .lives_p2, .points_goal, .result);
    seg7_page #(.VIEW_TICKS(VIEW_TICKS), .RUN_DURING_PAUSE(1'b1)) u_page (
        .clk_juego(clk), .rst, .new_match(start_new), .pause(sw_paused),
        .waiting(phase == G_IDLE || phase == G_MATCH), .goal_sel, .page_lives, .page_goal);
    assign goal_sel = {goal_hi_s2, goal_lo_s2};

    always_ff @(posedge clk) begin
        if (rst) begin
            pause_s1 <= 0; pause_s2 <= 0; goal_lo_s1 <= 0; goal_lo_s2 <= 0;
            goal_hi_s1 <= 0; goal_hi_s2 <= 0;
            tick_cnt <= 0; tick_tgl <= 0;
            cmd_op <= 0; cmd_seq <= 0; cmd_new_match <= 0; cmd_seed_mix <= 0;
            cmd_a_p1 <= 0; cmd_a_p2 <= 0; cmd_b_p1 <= 0; cmd_b_p2 <= 0;
            cmd_survive_p1 <= 0; cmd_survive_p2 <= 0; cmd_collected <= 0;
            phase <= G_IDLE; paused <= 0; phase_ticks <= 0;
            head_p1 <= start_p1; head_p2 <= start_p2;
            shown_p1 <= start_dir_p1; shown_p2 <= start_dir_p2;
            crashed_p1 <= 0; crashed_p2 <= 0; head_on <= 0;
            state <= S_IDLE; target_p1 <= start_p1; target_p2 <= start_p2;
            launched_p1 <= start_dir_p1; launched_p2 <= start_dir_p2;
            step_cnt <= 0; prep_match <= 0;
            round_index <= 0; step_count <= 0; log_kind <= 0; overrun <= 0;
        end else begin
            // Every edge, paused or not
            pause_s1 <= sw_pause; pause_s2 <= pause_s1;
            goal_lo_s1 <= sw_goal_lo; goal_lo_s2 <= goal_lo_s1;
            goal_hi_s1 <= sw_goal_hi; goal_hi_s2 <= goal_hi_s1;
            tick_cnt <= tick_cnt + 1;
            tick_tgl <= !tick_tgl;
            paused <= sw_paused;
            log_kind <= 0;

            if (sw_paused) begin
                if (state == S_COMMIT && idle) state <= S_IDLE;  // an issued COMMIT still completes
            end else begin
                phase_ticks <= phase_ticks_inc;

                // Step outcome (edge k + 2)
                if (resolve) begin
                    state <= S_COMMIT;
                    head_p1 <= new_p1; head_p2 <= new_p2;
                    shown_p1 <= launched_p1; shown_p2 <= launched_p2;
                    crashed_p1 <= c1; crashed_p2 <= c2; head_on <= ho;
                    cmd_op <= OP_COMMIT; cmd_seq <= cmd_seq + 1;
                    cmd_a_p1 <= head_p1; cmd_a_p2 <= head_p2;
                    cmd_b_p1 <= new_p1; cmd_b_p2 <= new_p2;
                    cmd_survive_p1 <= !c1; cmd_survive_p2 <= !c2;
                    cmd_collected <= {slot_p1 == 2'd2 || slot_p2 == 2'd2,
                                      slot_p1 == 2'd1 || slot_p2 == 2'd1,
                                      slot_p1 == 2'd0 || slot_p2 == 2'd0};
                    step_count <= step_count + 1;
                    log_kind <= 2'd2;
                    // A READ2 is only open in G_PLAY, so "no change" is G_PLAY:
                    // written, not held, to keep the enable code-independent.
                    phase <= (c1 || c2) ? G_CRASH : goal_hit ? G_MATCH : G_PLAY;
                    if (c1 || c2 || goal_hit) phase_ticks <= 0;
                end else if (state == S_COMMIT && idle) begin
                    state <= S_IDLE;
                end

                // Step launch (edge k); deferred while the last COMMIT is open
                if (step_due && !step_ready) overrun <= 1;
                if (launch) begin
                    state <= S_READ;
                    target_p1 <= next_p1; target_p2 <= next_p2;
                    launched_p1 <= chosen_p1; launched_p2 <= chosen_p2;
                    cmd_op <= OP_READ2; cmd_seq <= cmd_seq + 1;
                    cmd_a_p1 <= next_p1; cmd_a_p2 <= next_p2;
                end
                if (running && !(step_due && !step_ready)) step_cnt <= launch ? 8'd0 : step_cnt + 8'd1;

                // match_ctrl
                if (start_release) begin
                    step_cnt <= 0; phase <= G_PLAY; phase_ticks <= 0;
                end else if (prep_done) begin
                    if (prep_match) begin
                        step_cnt <= 0; phase <= G_PLAY;
                    end else phase <= G_READY;
                    phase_ticks <= 0;
                    log_kind <= 2'd1;
                end else if (crash_done && result != 2'd0) begin
                    phase <= G_MATCH; phase_ticks <= 0;
                end
                if (prepare) begin                       // round_init + PREPARE
                    head_p1 <= start_p1; head_p2 <= start_p2;
                    shown_p1 <= start_dir_p1; shown_p2 <= start_dir_p2;
                    target_p1 <= start_p1; target_p2 <= start_p2;
                    launched_p1 <= start_dir_p1; launched_p2 <= start_dir_p2;
                    cmd_op <= OP_PREPARE; cmd_seq <= cmd_seq + 1;
                    cmd_new_match <= prepare_new; cmd_seed_mix <= tick_cnt;
                    cmd_a_p1 <= start_p1; cmd_a_p2 <= start_p2;
                    prep_match <= prepare_new;
                    round_index <= prepare_new ? 8'd1 : round_index + 8'd1;
                    step_count <= 0;
                    crashed_p1 <= 0; crashed_p2 <= 0; head_on <= 0;
                    phase <= G_PREP; phase_ticks <= 0;
                end
            end
        end
    end
endmodule
