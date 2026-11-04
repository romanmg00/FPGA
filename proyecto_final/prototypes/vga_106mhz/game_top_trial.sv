// Experiment: the same game (walls, HUD, moving block) with a 106.5 MHz pixel clock.
// It does NOT use clk_wiz_0 or clk_wiz_1: it instantiates the MMCM primitive directly,
// so there is no IP to reconfigure. To try it, add this file and vga_out_trial.sv
// to the Vivado project, mark game_top_trial as top (Set as Top) and generate the
// bitstream. Pins come from game_top.xdc, unchanged, except that this top has no btn[4].
// game_top.xdc no longer defines the board clock, because clk_wiz_0's IP does that and
// this design has no Wizard, so also add game_top_trial.xdc.
// Known limits, because this is an experiment and not part of the milestone: its divider
// is reset by rst, the bug fixed in game_top, so CPU_RESET does not return the block to
// its start. clk_juego also has no defined clock, so timing is not signed off.
//
// Parameter USE_VESA75:
//   1 (case B) -> vga_out_trial: VESA 1280x800 @ 75 Hz timing (1696 x 838)
//   0 (case A) -> original vga_out: slide 7 timing (1680 x 828) -> ~76.2 Hz, non-standard
//
// MMCM: 100 MHz / D=5 * M=53.25 = VCO 1065 MHz; / O=10.0 = 106.5 MHz exactly.
// Game clock: counter directly on clk_pix (no second wizard), only for this experiment:
//   106,500,000 / (2 * 60) = 887,500 cycles between toggles -> 20 bits.

module game_top_trial #(
    parameter bit USE_VESA75 = 1'b1
)(
    input  logic        clk, cpu_resetn,
    input  logic [11:0] sw,
    input  logic [3:0]  btn,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs
);

    logic [10:0] blkpos_x, blkpos_y;
    logic [10:0] curr_x, curr_y;
    logic [3:0]  draw_r, draw_g, draw_b;
    logic        clk_pix, clk_pix_mmcm, clkfb, locked;
    logic        clk_juego;
    logic [19:0] clk_cnt;
    logic        rst;

    // reset while the button is pressed OR while the MMCM is not yet locked
    assign rst = ~cpu_resetn | ~locked;

    // ---------------- 106.5 MHz pixel clock (MMCM primitive, no IP) ----------------
    MMCME2_BASE #(
        .CLKIN1_PERIOD    (10.0),    // 100 MHz input
        .DIVCLK_DIVIDE    (5),       // D
        .CLKFBOUT_MULT_F  (53.25),   // M  -> VCO = 100 / 5 * 53.25 = 1065 MHz
        .CLKOUT0_DIVIDE_F (10.0)     // O  -> 1065 / 10 = 106.5 MHz
    ) u_mmcm (
        .CLKIN1   (clk),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb),           // internal feedback
        .CLKOUT0  (clk_pix_mmcm),
        .LOCKED   (locked),
        .RST      (1'b0),
        .PWRDWN   (1'b0),
        // unused outputs
        .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(),
        .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6()
    );

    BUFG u_bufg_pix (.I(clk_pix_mmcm), .O(clk_pix));

    // ---------------- ~60 Hz game clock (divider directly on clk_pix) ----------------
    always_ff @(posedge clk_pix) begin
        if (rst) begin
            clk_cnt   <= 20'd0;
            clk_juego <= 1'b0;
        end
        else if (clk_cnt == 20'd887499) begin
            clk_cnt   <= 20'd0;
            clk_juego <= ~clk_juego;
        end
        else
            clk_cnt <= clk_cnt + 1'b1;
    end

    // ---------------- same blocks as game_top ----------------
    position_logic u_position_logic (
        .rst      (rst),
        .clk      (clk_juego),
        .btn      (btn),
        .blkpos_x (blkpos_x),
        .blkpos_y (blkpos_y)
    );

    drawcon u_drawcon (
        .curr_x   (curr_x),
        .curr_y   (curr_y),
        .blkpos_x (blkpos_x),
        .blkpos_y (blkpos_y),
        .sw       (sw),
        .draw_r   (draw_r),
        .draw_g   (draw_g),
        .draw_b   (draw_b)
    );

    generate
        if (USE_VESA75) begin : g_vesa75
            vga_out_trial u_vga_out (
                .clk_pix(clk_pix), .rst(rst), .tick_60hz(),
                .curr_x(curr_x), .curr_y(curr_y),
                .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
                .pix_r(vga_r), .pix_g(vga_g), .pix_b(vga_b),
                .hsync(vga_hs), .vsync(vga_vs)
            );
        end
        else begin : g_slide7
            vga_out u_vga_out (
                .clk_pix(clk_pix), .rst(rst), .tick_60hz(),
                .curr_x(curr_x), .curr_y(curr_y),
                .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
                .pix_r(vga_r), .pix_g(vga_g), .pix_b(vga_b),
                .hsync(vga_hs), .vsync(vga_vs)
            );
        end
    endgenerate

endmodule
