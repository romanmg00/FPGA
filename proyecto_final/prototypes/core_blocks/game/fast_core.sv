// fast_core: the clk_pix half of the Tron core: the fast side of the
// mailbox, arena_svc, the input batch and the render snapshot. Owner: Alan
// (Roman's drawcon reads the snapshot and Arena port B). Domain: clk = clk_pix.
//
// PROVISIONAL (ADR 0005), modelled on prototipos/tron_fpga/model/mailbox.py,
// input_batch.py and game_top.py; the crossing (ADR 0003 item 2) is open.
// Crossings into this module, all from game_core (clk_juego):
//   tick_tgl      2-FF synchronizer, then edge detect -> tick_seen.
//   cmd_*, g_*    multi-bit buses, latched only on tick_seen. They changed on
//                 the same clk_juego edge as tick_tgl, so they are stable
//                 before the synchronizer's second stage (constrain each path
//                 with set_max_delay -datapath_only below one clk_pix period).
// Crossings out of this module (QUALIFIED = 0), into game_core capture registers:
//   rsp_*, batch_*  change only (a) on tick_seen, or (b) when a command
//                 finishes within WINDOW cycles after tick_seen. game_core
//                 samples them on the next clk_juego edge, about 1.39 M
//                 clk_pix cycles after tick_seen, so they are quiet at every
//                 sampling edge. A command that overruns the window publishes
//                 at the next tick_seen instead and sets late_publish.
// QUALIFIED = 1 (two-phase req/ack, crossing/FINDINGS.md): a response is
//   published as soon as its command finishes; rsp_seq[0] is the ack toggle
//   that game_core synchronizes, and rsp_code_* stay held until the next
//   command, which game_core issues only after using them. late_publish then
//   only flags a command that took more than WINDOW cycles. batch_* go to
//   batch_fifo, written on batch_wr (the cycle after tick_seen).
module fast_core #(
    parameter bit     QUALIFIED = 1'b0,
    parameter integer WINDOW = 1 << 18              // ~3.1 ms at 83.46 MHz (model SERVICE_WINDOW)
) (
    input  logic        clk, rst,
    input  logic [31:0] seed,
    input  logic        fixed_seed,
    // from game_core
    input  logic        tick_tgl,
    input  logic [1:0]  cmd_op,
    input  logic [3:0]  cmd_seq,
    input  logic        cmd_new_match,
    input  logic [31:0] cmd_seed_mix,
    input  logic [12:0] cmd_a_p1, cmd_a_p2, cmd_b_p1, cmd_b_p2,
    input  logic        cmd_survive_p1, cmd_survive_p2,
    input  logic [2:0]  cmd_collected,
    input  logic [2:0]  g_phase,
    input  logic        g_paused,
    input  logic [7:0]  g_phase_ticks,
    input  logic [12:0] g_head_p1, g_head_p2,
    input  logic [1:0]  g_shown_p1, g_shown_p2,
    input  logic        g_crashed_p1, g_crashed_p2,
    input  logic [5:0]  g_points_p1, g_points_p2,
    input  logic [1:0]  g_lives_p1, g_lives_p2,
    input  logic        g_page_lives,
    // to game_core
    output logic [3:0]  rsp_seq,
    output logic [3:0]  rsp_code_p1, rsp_code_p2,
    output logic [3:0]  batch_axes_p1, batch_axes_p2,
    output logic        batch_start,
    output logic        batch_wr,                   // batch_* were just published (batch_fifo write)
    // inputs, already in clk_pix
    input  logic [4:0]  btn_pulse,                  // {C, R, L, D, U} one-cycle press pulses
    input  logic        uart_cmd_valid,
    input  logic [2:0]  uart_cmd,                   // 0 W, 1 D, 2 S, 3 A (= DIR_*), 4 Start
    // render snapshot for drawcon and the Scoreboard
    output logic [2:0]  snap_phase,
    output logic        snap_paused,
    output logic [7:0]  snap_phase_ticks,
    output logic [12:0] snap_head_p1, snap_head_p2,
    output logic [1:0]  snap_shown_p1, snap_shown_p2,
    output logic        snap_crashed_p1, snap_crashed_p2,
    output logic [5:0]  snap_points_p1, snap_points_p2,
    output logic [1:0]  snap_lives_p1, snap_lives_p2,
    output logic        snap_page_lives,
    output logic        tick_seen,
    // Arena port B and status
    input  logic [12:0] b_addr,
    output logic [3:0]  b_rdata,
    output logic        slot0_valid, slot1_valid, slot2_valid,
    output logic [12:0] slot0_cell, slot1_cell, slot2_cell,
    output logic        svc_busy, late_publish
);
    import game_pkg::*;

    // --- tick_seen: the synchronized game-clock edge -------------------------
    logic tick_sync, tick_d;
    sync_2ff u_tick_sync (.clk, .rst, .async_in(tick_tgl), .sync_out(tick_sync));
    always_ff @(posedge clk) begin
        if (rst) begin tick_d <= 0; tick_seen <= 0; end
        else begin tick_d <= tick_sync; tick_seen <= tick_sync ^ tick_d; end
    end

    // --- command payload, latched on tick_seen -------------------------------
    logic [1:0]  q_op;
    logic [3:0]  q_seq, fast_seq;
    logic        q_new_match, q_survive_p1, q_survive_p2;
    logic [31:0] q_seed_mix;
    logic [12:0] q_a_p1, q_a_p2, q_b_p1, q_b_p2;
    logic [2:0]  q_collected;
    logic        svc_start, svc_done, in_flight, pend_publish;
    logic [3:0]  svc_code_p1, svc_code_p2;
    logic [18:0] win_cnt;
    localparam logic [18:0] WIN = 19'(WINDOW);

    arena_svc u_svc (.clk, .rst, .start(svc_start), .op(q_op), .new_match(q_new_match),
        .seed_mix(q_seed_mix), .seed, .fixed_seed, .a_p1(q_a_p1), .a_p2(q_a_p2),
        .b_p1(q_b_p1), .b_p2(q_b_p2), .survive_p1(q_survive_p1), .survive_p2(q_survive_p2),
        .collected(q_collected), .busy(svc_busy), .done(svc_done),
        .code_p1(svc_code_p1), .code_p2(svc_code_p2),
        .slot0_valid, .slot1_valid, .slot2_valid, .slot0_cell, .slot1_cell, .slot2_cell,
        .b_addr, .b_rdata);

    // Take a new command once its payload is latched and the service is idle.
    always_comb svc_start = !tick_seen && !in_flight && !svc_busy && q_seq != fast_seq && q_op != 2'd0;

    always_ff @(posedge clk) begin
        if (rst) begin
            q_op <= 0; q_seq <= 0; fast_seq <= 0; q_new_match <= 0; q_seed_mix <= 0;
            q_a_p1 <= 0; q_a_p2 <= 0; q_b_p1 <= 0; q_b_p2 <= 0;
            q_survive_p1 <= 0; q_survive_p2 <= 0; q_collected <= 0;
            in_flight <= 0; pend_publish <= 0; win_cnt <= 0; late_publish <= 0;
            rsp_seq <= 0; rsp_code_p1 <= 0; rsp_code_p2 <= 0;
        end else begin
            if (tick_seen) begin
                q_op <= cmd_op; q_seq <= cmd_seq; q_new_match <= cmd_new_match;
                q_seed_mix <= cmd_seed_mix; q_a_p1 <= cmd_a_p1; q_a_p2 <= cmd_a_p2;
                q_b_p1 <= cmd_b_p1; q_b_p2 <= cmd_b_p2;
                q_survive_p1 <= cmd_survive_p1; q_survive_p2 <= cmd_survive_p2;
                q_collected <= cmd_collected;
                win_cnt <= 0;
            end else if (win_cnt != WIN) win_cnt <= win_cnt + 1'b1;

            if (svc_start) begin
                fast_seq <= q_seq;
                in_flight <= 1;
            end
            // Publish inside the quiet window, else at the next tick_seen.
            if (svc_done && in_flight) begin
                in_flight <= 0;
                if (QUALIFIED) begin
                    rsp_seq <= fast_seq; rsp_code_p1 <= svc_code_p1; rsp_code_p2 <= svc_code_p2;
                    if (win_cnt == WIN) late_publish <= 1;
                end else if (win_cnt != WIN && !tick_seen) begin
                    rsp_seq <= fast_seq; rsp_code_p1 <= svc_code_p1; rsp_code_p2 <= svc_code_p2;
                end else begin
                    pend_publish <= 1; late_publish <= 1;
                end
            end else if (pend_publish && tick_seen) begin
                pend_publish <= 0;
                rsp_seq <= fast_seq; rsp_code_p1 <= svc_code_p1; rsp_code_p2 <= svc_code_p2;
            end
        end
    end

    // --- render snapshot, latched on tick_seen -------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            snap_phase <= G_IDLE; snap_paused <= 0; snap_phase_ticks <= 0;
            snap_head_p1 <= 0; snap_head_p2 <= 0; snap_shown_p1 <= 0; snap_shown_p2 <= 0;
            snap_crashed_p1 <= 0; snap_crashed_p2 <= 0;
            snap_points_p1 <= 0; snap_points_p2 <= 0;
            snap_lives_p1 <= 2'(LIVES_START); snap_lives_p2 <= 2'(LIVES_START);
            snap_page_lives <= 0;
        end else if (tick_seen) begin
            snap_phase <= g_phase; snap_paused <= g_paused; snap_phase_ticks <= g_phase_ticks;
            snap_head_p1 <= g_head_p1; snap_head_p2 <= g_head_p2;
            snap_shown_p1 <= g_shown_p1; snap_shown_p2 <= g_shown_p2;
            snap_crashed_p1 <= g_crashed_p1; snap_crashed_p2 <= g_crashed_p2;
            snap_points_p1 <= g_points_p1; snap_points_p2 <= g_points_p2;
            snap_lives_p1 <= g_lives_p1; snap_lives_p2 <= g_lives_p2;
            snap_page_lives <= g_page_lives;
        end
    end

    // --- input batch: per-tick axis latches, gated by the snapshot ----------
    // An event counts only if the snapshot shows the right phase, unpaused:
    // directions in G_PLAY, Start in G_IDLE, G_READY or G_MATCH.
    logic turns_ok, start_ok;
    logic [3:0] lat_p1, lat_p2, nxt_p1, nxt_p2;
    logic lat_start, nxt_start;
    always_comb begin
        turns_ok = snap_phase == G_PLAY && !snap_paused;
        start_ok = (snap_phase == G_IDLE || snap_phase == G_READY || snap_phase == G_MATCH) && !snap_paused;
        // A tick_seen publishes and clears; an event in the same cycle opens the next batch.
        nxt_p1 = tick_seen ? 4'd0 : lat_p1;
        nxt_p2 = tick_seen ? 4'd0 : lat_p2;
        nxt_start = tick_seen ? 1'b0 : lat_start;
        if (btn_pulse[BTN_C] && start_ok) nxt_start = 1'b1;
        if (turns_ok) begin
            // One sample: UP beats DOWN and RIGHT beats LEFT
            if (btn_pulse[BTN_U]) nxt_p1[3:2] = 2'b10;
            else if (btn_pulse[BTN_D]) nxt_p1[3:2] = 2'b11;
            if (btn_pulse[BTN_R]) nxt_p1[1:0] = 2'b10;
            else if (btn_pulse[BTN_L]) nxt_p1[1:0] = 2'b11;
        end
        if (uart_cmd_valid) begin
            if (uart_cmd == 3'd4) begin
                if (start_ok) nxt_start = 1'b1;
            end else if (turns_ok) begin
                case (uart_cmd[1:0])
                    DIR_UP:    nxt_p2[3:2] = 2'b10;
                    DIR_DOWN:  nxt_p2[3:2] = 2'b11;
                    DIR_RIGHT: nxt_p2[1:0] = 2'b10;
                    default:   nxt_p2[1:0] = 2'b11;
                endcase
            end
        end
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            lat_p1 <= 0; lat_p2 <= 0; lat_start <= 0;
            batch_axes_p1 <= 0; batch_axes_p2 <= 0; batch_start <= 0; batch_wr <= 0;
        end else begin
            lat_p1 <= nxt_p1; lat_p2 <= nxt_p2; lat_start <= nxt_start;
            batch_wr <= tick_seen;
            if (tick_seen) begin
                batch_axes_p1 <= lat_p1; batch_axes_p2 <= lat_p2; batch_start <= lat_start;
            end
        end
    end
endmodule
