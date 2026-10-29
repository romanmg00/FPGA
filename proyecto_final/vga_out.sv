module vga_out (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [10:0] curr_x,
    output logic [10:0] curr_y,
    output logic        tick_60hz,
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync
);

    logic [10:0] hcnt;
    logic [10:0] vcnt;
    logic visible;

    counters c_counter(
        .clk    (clk_pix), 
        .rst    (rst), 
        .hcnt   (hcnt), 
        .vcnt   (vcnt)
        );

    // Handout ("VGA Sync Signals", "Visible Pixel Counter"): sync and colour
    // come from the counters through assignments, so curr_x/curr_y name the
    // pixel on the pins in this same cycle (VGA and Sprite Design Plan,
    // Decision B). Changed 29 Oct 2026 from registered outputs, which put the
    // pins one cycle behind curr_x/curr_y (core_blocks/video/FINDINGS.md).
    // tick_60hz stays 0: with ADR 0002 the game clock comes from the divider.
    always_comb begin
        tick_60hz = 1'b0;
        curr_x = hcnt - 11'd336;
        curr_y = vcnt - 11'd27;
        visible = (hcnt >= 11'd336 && hcnt < 11'd1616) && (vcnt >= 11'd27 && vcnt < 11'd827);
        hsync = ~(hcnt < 11'd136);
        vsync = (vcnt < 11'd3);
        pix_r = visible ? draw_r : 4'b0;
        pix_g = visible ? draw_g : 4'b0;
        pix_b = visible ? draw_b : 4'b0;
    end

endmodule
