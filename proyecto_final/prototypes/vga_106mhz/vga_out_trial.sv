// Experiment: 1280x800 at 75 Hz (VESA DMT) with a 106.5 MHz pixel clock.
// It has the same ports as vga_out, so in game_top only the module name changes.
// The counters live inside this module so counters.sv is not touched.
//
// VESA timing for 1280x800 @ 75 Hz (106.5 MHz):
//   horizontal: SYNC 128 | BP 208 | VISIBLE 1280 | FP 80  -> total 1696
//   vertical:   SYNC 6   | BP 29  | VISIBLE 800  | FP 3   -> total 838
//   hsync active low, vsync active high (the same polarities as vga_out)
// Same zone order as vga_out: SYNC -> BP -> VISIBLE -> FP.
// Frame: 1696 * 838 = 1,421,248 cycles -> 106.5 MHz / 1,421,248 = 74.93 Hz.

module vga_out_trial (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [10:0] curr_x,
    output logic [10:0] curr_y,
    output logic        tick_60hz,
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync
);

    // horizontal limits
    localparam logic [10:0] H_SYNC_END  = 11'd128;   // 0..127 sync
    localparam logic [10:0] H_VIS_START = 11'd336;   // 128 + 208
    localparam logic [10:0] H_VIS_END   = 11'd1616;  // 336 + 1280
    localparam logic [10:0] H_LAST      = 11'd1695;  // total 1696

    // vertical limits
    localparam logic [10:0] V_SYNC_END  = 11'd6;     // 0..5 sync
    localparam logic [10:0] V_VIS_START = 11'd35;    // 6 + 29
    localparam logic [10:0] V_VIS_END   = 11'd835;   // 35 + 800
    localparam logic [10:0] V_LAST      = 11'd837;   // total 838

    logic [10:0] hcnt, vcnt;
    logic        visible;

    // counters (same structure as counters.sv, with the new totals)
    always_ff @(posedge clk_pix) begin
        if (rst) begin
            hcnt <= 11'd0;
            vcnt <= 11'd0;
        end
        else if (hcnt == H_LAST) begin
            hcnt <= 11'd0;
            if (vcnt == V_LAST) vcnt <= 11'd0;
            else                vcnt <= vcnt + 1'b1;
        end
        else
            hcnt <= hcnt + 1'b1;
    end

    always_comb begin
        tick_60hz = 1'b0;
        curr_x  = hcnt - H_VIS_START;
        curr_y  = vcnt - V_VIS_START;
        visible = (hcnt >= H_VIS_START && hcnt < H_VIS_END) &&
                  (vcnt >= V_VIS_START && vcnt < V_VIS_END);
    end

    always_ff @(posedge clk_pix) begin
        hsync <= ~(hcnt < H_SYNC_END);   // active low
        vsync <=  (vcnt < V_SYNC_END);   // active high
        if (visible) begin
            pix_r <= draw_r;
            pix_g <= draw_g;
            pix_b <= draw_b;
        end
        else begin
            pix_r <= 4'b0;
            pix_g <= 4'b0;
            pix_b <= 4'b0;
        end
    end

endmodule
