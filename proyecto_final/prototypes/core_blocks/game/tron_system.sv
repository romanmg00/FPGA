// tron_system: everything in the Tron core below the clocks and resets,
// so a bench can run it on two plain clocks. Owner: Alan (game_top).
// Domains: clk_pix (inputs, fast_core, drawcon_game, vga_out, seg7_driver,
// LEDs) and clk_juego (game_core); rst_pix and rst_game are already
// synchronous to their clocks and asserted together for several game edges
// (reset_stretch). Crossings: see tron_top.sv and fast_core.sv; QUALIFIED
// selects the req/ack crossing and batch_fifo (crossing/FINDINGS.md).
// PROVISIONAL (ADR 0005).
module tron_system #(
    parameter bit QUALIFIED = 1'b0,                     // 0 mailbox (ADR 0003 default), 1 req/ack
    parameter bit RSP_REG = 1'b0,                       // with QUALIFIED: capture the codes ("captured")
    parameter integer STEP_TICKS = game_pkg::STEP_TICKS,  // ADR 0006: configurable, fixed in play
    parameter integer CLK_PIX_HZ = 83455882,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer WINDOW = 1 << 18,
    parameter logic [31:0] SEED = 32'h1D2C3B4A,         // model LFSR_SEED
    parameter bit FIXED_SEED = 1'b0,                    // 0: mix the Start tick into the LFSR
    parameter string SPRITE_DIR = "src/prototypes/core_blocks/game/sprites/"
) (
    input  logic        clk_pix, clk_juego, rst_pix, rst_game,
    input  logic [4:0]  btn,
    input  logic [15:0] sw,
    input  logic        uart_rx,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs,
    output logic [6:0]  seg,
    output logic [7:0]  an,
    output logic [15:0] led
);
    import game_pkg::*;

    // --- inputs (clk_pix) ----------------------------------------------------
    logic [4:0] btn_pulse;
    logic rx_sync, rx_valid, framing_error, uart_cmd_valid;
    logic [7:0] rx_byte;
    logic [2:0] uart_cmd;
    btn_debounce #(.CLK_HZ(CLK_PIX_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) u_btn (.clk(clk_pix), .rst(rst_pix), .btn, .btn_pulse);
    uart_sync_2ff #(.reset_value(1'b1)) u_rx_sync (.clk(clk_pix), .rst(rst_pix), .async_in(uart_rx), .sync_out(rx_sync));
    uart_rx #(.clk_hz(CLK_PIX_HZ)) u_rx (.clk(clk_pix), .rst(rst_pix), .rx(rx_sync), .rx_byte, .rx_valid, .framing_error);
    uart_cmd_decode u_dec (.clk(clk_pix), .rst(rst_pix), .rx_valid, .rx_byte, .cmd(uart_cmd), .cmd_valid(uart_cmd_valid));

    // --- game domain ---------------------------------------------------------
    localparam logic [12:0] START_P1 = {SAL_CY, SAL_P1_CX};
    localparam logic [12:0] START_P2 = {SAL_CY, SAL_P2_CX};
    logic tick_tgl, cmd_new_match, cmd_survive_p1, cmd_survive_p2;
    logic [1:0] cmd_op;
    logic [3:0] cmd_seq, rsp_seq, rsp_code_p1, rsp_code_p2, batch_axes_p1, batch_axes_p2;
    logic [3:0] g_axes_p1, g_axes_p2;                   // the batch as game_core sees it
    logic batch_start, batch_wr, g_start, batch_overflow;
    logic [31:0] cmd_seed_mix;
    logic [12:0] cmd_a_p1, cmd_a_p2, cmd_b_p1, cmd_b_p2, head_p1, head_p2;
    logic [2:0] cmd_collected, phase;
    logic paused, crashed_p1, crashed_p2, head_on, page_lives, overrun;
    logic [7:0] phase_ticks, round_index;
    logic [1:0] shown_p1, shown_p2, lives_p1, lives_p2, result, log_kind;
    logic [5:0] points_p1, points_p2, points_goal;
    logic [15:0] step_count;

    game_core #(.QUALIFIED(QUALIFIED), .RSP_REG(RSP_REG), .STEP_TICKS(STEP_TICKS)) u_game (.clk(clk_juego), .rst(rst_game),
        .sw_pause(sw[0]), .sw_goal_lo(sw[14]), .sw_goal_hi(sw[15]),
        .start_p1(START_P1), .start_p2(START_P2), .start_dir_p1(DIR_RIGHT), .start_dir_p2(DIR_LEFT),
        .rsp_seq, .rsp_code_p1, .rsp_code_p2, .batch_axes_p1(g_axes_p1), .batch_axes_p2(g_axes_p2),
        .batch_start(g_start),
        .tick_tgl, .cmd_op, .cmd_seq, .cmd_new_match, .cmd_seed_mix, .cmd_a_p1, .cmd_a_p2,
        .cmd_b_p1, .cmd_b_p2, .cmd_survive_p1, .cmd_survive_p2, .cmd_collected,
        .phase, .paused, .phase_ticks, .head_p1, .head_p2, .shown_p1, .shown_p2,
        .crashed_p1, .crashed_p2, .head_on, .points_p1, .points_p2, .points_goal,
        .lives_p1, .lives_p2, .result, .page_lives, .round_index, .step_count, .log_kind, .overrun);

    // --- fast domain ---------------------------------------------------------
    logic [2:0] snap_phase;
    logic snap_paused, snap_crashed_p1, snap_crashed_p2, snap_page_lives, tick_seen;
    logic [7:0] snap_phase_ticks;
    logic [1:0] snap_shown_p1, snap_shown_p2;
    logic [12:0] snap_head_p1, snap_head_p2, slot0_cell, slot1_cell, slot2_cell, b_addr;
    logic [5:0] snap_points_p1, snap_points_p2;
    logic [1:0] snap_lives_p1, snap_lives_p2;
    logic [3:0] b_rdata;
    logic slot0_valid, slot1_valid, slot2_valid, svc_busy, late_publish;

    fast_core #(.QUALIFIED(QUALIFIED), .WINDOW(WINDOW)) u_fast (.clk(clk_pix), .rst(rst_pix), .seed(SEED), .fixed_seed(FIXED_SEED), .tick_tgl,
        .cmd_op, .cmd_seq, .cmd_new_match, .cmd_seed_mix, .cmd_a_p1, .cmd_a_p2, .cmd_b_p1, .cmd_b_p2,
        .cmd_survive_p1, .cmd_survive_p2, .cmd_collected,
        .g_phase(phase), .g_paused(paused), .g_phase_ticks(phase_ticks),
        .g_head_p1(head_p1), .g_head_p2(head_p2), .g_shown_p1(shown_p1), .g_shown_p2(shown_p2), .g_crashed_p1(crashed_p1), .g_crashed_p2(crashed_p2),
        .g_points_p1(points_p1), .g_points_p2(points_p2), .g_lives_p1(lives_p1), .g_lives_p2(lives_p2),
        .g_page_lives(page_lives), .rsp_seq, .rsp_code_p1, .rsp_code_p2,
        .batch_axes_p1, .batch_axes_p2, .batch_start, .batch_wr, .btn_pulse, .uart_cmd_valid, .uart_cmd,
        .snap_phase, .snap_paused, .snap_phase_ticks, .snap_head_p1, .snap_head_p2,
        .snap_shown_p1, .snap_shown_p2,
        .snap_crashed_p1, .snap_crashed_p2, .snap_points_p1, .snap_points_p2,
        .snap_lives_p1, .snap_lives_p2, .snap_page_lives, .tick_seen,
        .b_addr, .b_rdata, .slot0_valid, .slot1_valid, .slot2_valid,
        .slot0_cell, .slot1_cell, .slot2_cell, .svc_busy, .late_publish);

    // --- input batches into the game domain ----------------------------------
    generate
        if (QUALIFIED) begin : g_batch_fifo
            logic batch_valid_unused;
            batch_fifo #(.W(9)) u_batch (.wclk(clk_pix), .wrst(rst_pix), .wen(batch_wr),
                .wdata({batch_start, batch_axes_p1, batch_axes_p2}), .overflow(batch_overflow),
                .rclk(clk_juego), .rrst(rst_game), .rdata({g_start, g_axes_p1, g_axes_p2}),
                .rvalid(batch_valid_unused));
        end else begin : g_batch_direct
            assign {g_start, g_axes_p1, g_axes_p2} = {batch_start, batch_axes_p1, batch_axes_p2};
            assign batch_overflow = 1'b0;
        end
    endgenerate

    // --- video and Scoreboard (clk_pix) --------------------------------------
    logic [10:0] curr_x, curr_y;
    logic [3:0] draw_r, draw_g, draw_b;
    logic tick_60hz_unused;
    drawcon_game #(.SPRITE_DIR(SPRITE_DIR)) u_draw (.clk(clk_pix), .curr_x, .curr_y, .b_rdata,
        .snap_phase, .snap_paused, .snap_phase_ticks, .snap_head_p1, .snap_head_p2,
        .snap_shown_p1, .snap_shown_p2, .snap_crashed_p1, .snap_crashed_p2,
        .points_p1(snap_points_p1), .points_p2(snap_points_p2),
        .lives_p1(snap_lives_p1), .lives_p2(snap_lives_p2), .b_addr, .draw_r, .draw_g, .draw_b);
    vga_out u_vga (.clk_pix, .rst(rst_pix), .draw_r, .draw_g, .draw_b, .curr_x, .curr_y,
        .tick_60hz(tick_60hz_unused), .pix_r(vga_r), .pix_g(vga_g), .pix_b(vga_b),
        .hsync(vga_hs), .vsync(vga_vs));
    seg7_driver #(.CLK_HZ(CLK_PIX_HZ)) u_seg7 (.clk_pix, .rst(rst_pix),
        .points_p1(snap_points_p1), .points_p2(snap_points_p2),
        .lives_p1(snap_lives_p1), .lives_p2(snap_lives_p2), .page_lives(snap_page_lives), .seg, .an);

    // --- debug LEDs (clk_pix) ------------------------------------------------
    // led[2:0] phase, led[3] paused, led[4] late publish (sticky), led[5]
    // Arena service busy, led[6] UART framing error seen, led[7] UART byte
    // seen, led[8] batch_fifo overflow (sticky, QUALIFIED only), led[15] ~1 Hz
    // heartbeat from tick_seen (proves clk_juego runs).
    logic [5:0] beat;
    logic rx_seen, frame_seen;
    always_ff @(posedge clk_pix) begin
        if (rst_pix) begin beat <= 0; rx_seen <= 0; frame_seen <= 0; end
        else begin
            if (tick_seen) beat <= beat + 1'b1;
            if (rx_valid) rx_seen <= !rx_seen;
            if (framing_error) frame_seen <= 1;
        end
    end
    always_comb begin
        led = '0;
        led[2:0] = snap_phase;
        led[3] = snap_paused;
        led[4] = late_publish;
        led[5] = svc_busy;
        led[6] = frame_seen;
        led[7] = rx_seen;
        led[8] = batch_overflow;
        led[15] = beat[5];
    end
endmodule
