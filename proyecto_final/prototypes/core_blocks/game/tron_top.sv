// tron_top: first playable board build of the Tron core. Owner: Alan
// (game_top). Ports follow contract section 2, plus dp (the 7-segment
// decimal points, held off; an unused pin would float to the default pull-down
// and light them).
//
// Clocks (ADR 0002): board clk feeds only the two Clocking Wizards.
//   clk_pix    83.46 MHz requested (83.455882 achieved, video/FINDINGS.md):
//              vga_out, drawcon_game, fast_core (Arena service, input batch,
//              snapshot), button debounce, UART receive, 7-segment scan.
//   clk_base   4.6875 MHz: game_clk_div and reset_stretch only.
//   clk_juego  clk_base / 78126 = 59.999 Hz through a BUFG: game_core.
// Crossings (all PROVISIONAL, ADR 0003 item 2 open; see game/FINDINGS.md):
//   cpu_resetn -> reset_stretch (2-FF, clk_base) -> rst_req -> 2-FF per domain.
//   btn -> btn_debounce 2-FF (clk_pix); uart_rx -> uart_sync_2ff (clk_pix);
//   sw[0], sw[15:14] -> 2-FF inside game_core (clk_juego).
//   game_core <-> fast_core: tick_tgl 2-FF plus the quiet-window mailbox and
//   snapshot buses described in fast_core.sv (QUALIFIED = 0), or the req/ack
//   crossing and batch_fifo (QUALIFIED = 1, crossing/FINDINGS.md).
module tron_top #(
    parameter bit QUALIFIED = 1'b0,                     // fast -> game crossing, see above
    parameter bit RSP_REG = 1'b0,                       // with QUALIFIED: capture the codes first
    parameter integer STEP_TICKS = game_pkg::STEP_TICKS,  // game ticks per Step (ADR 0006)
    parameter integer CLK_PIX_HZ = 83455882,
    parameter integer GAME_HALF_CYCLES = 39063,
    parameter logic [31:0] SEED = 32'h1D2C3B4A,         // model LFSR_SEED
    parameter bit FIXED_SEED = 1'b0,                    // 0: mix the Start tick into the LFSR
    parameter string SPRITE_DIR = "sprites/"          // set by run_tron.tcl to the .mem folder
) (
    input  logic        clk, cpu_resetn,
    input  logic [4:0]  btn,
    input  logic [15:0] sw,
    input  logic        uart_rx,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs,
    output logic [6:0]  seg,
    output logic        dp,
    output logic [7:0]  an,
    output logic [15:0] led
);
    import game_pkg::*;

    // --- clocks and resets -------------------------------------------------
    logic clk_in, clk_pix, clk_base, clk_juego, rst_req, rst_pix, rst_game;
`ifdef SYNTHESIS
    IBUF u_clk_ibuf (.I(clk), .O(clk_in));
`else
    assign clk_in = clk;
`endif
    tron_pixel_clock u_pixel_wiz (.clk_in1(clk_in), .clk_out1(clk_pix));
    tron_base_clock  u_base_wiz  (.clk_in1(clk_in), .clk_out1(clk_base));
    game_clk_div #(.half_cycles(GAME_HALF_CYCLES)) u_div (.clk_base, .rst(1'b0), .clk_juego);
    reset_stretch #(.HOLD(6 * 2 * GAME_HALF_CYCLES)) u_reset (.clk(clk_base), .cpu_resetn, .rst_req);
    board_reset_sync u_reset_pix  (.clk(clk_pix),   .async_reset(rst_req), .rst(rst_pix));
    board_reset_sync u_reset_game (.clk(clk_juego), .async_reset(rst_req), .rst(rst_game));

    tron_system #(.QUALIFIED(QUALIFIED), .RSP_REG(RSP_REG), .STEP_TICKS(STEP_TICKS), .CLK_PIX_HZ(CLK_PIX_HZ), .SEED(SEED), .FIXED_SEED(FIXED_SEED), .SPRITE_DIR(SPRITE_DIR)) u_system (
        .clk_pix, .clk_juego, .rst_pix, .rst_game, .btn, .sw, .uart_rx,
        .vga_r, .vga_g, .vga_b, .vga_hs, .vga_vs, .seg, .an, .led);
    assign dp = 1'b1;
endmodule
