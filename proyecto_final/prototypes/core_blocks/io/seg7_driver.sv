// Owner Alan. Contract section 4 proposal; ALL ports/parameters PROVISIONAL.
// clk_pix fast clock, NOT board clk. Inputs MUST already be a coherent clk_pix
// snapshot of clk_juego Points/Lives/page. Crossing remains UNSELECTED (ADR 0003
// item 2). This module only latches that snapshot at a scan-frame boundary.
// Candidate 6-bit Points accommodates 45; Lives 2-bit. seg[0]=a .. seg[6]=g.
// Board an and seg active low. Each digit revisited ~1 kHz (8 kHz slot rate).
module seg7_driver #(
    parameter integer CLK_HZ = 83460000,
    parameter integer DIGIT_HZ = 1000
) (
    input logic clk_pix, rst,
    input logic [5:0] points_p1, points_p2,
    input logic [1:0] lives_p1, lives_p2,
    input logic page_lives,
    output logic [6:0] seg,
    output logic [7:0] an
);
    import game_pkg::*;
    localparam integer SLOT_CYCLES = CLK_HZ / (8 * DIGIT_HZ);
    localparam integer COUNT_W = SLOT_CYCLES > 1 ? $clog2(SLOT_CYCLES) : 1;
    logic [COUNT_W-1:0] count;
    logic [2:0] digit;
    logic [5:0] value_p1, value_p2;
    logic lives_frame;
    logic [3:0] glyph;
    always_ff @(posedge clk_pix) begin
        if (rst) begin
            count <= '0;
            digit <= '0;
            value_p1 <= '0;
            value_p2 <= '0;
            lives_frame <= 1'b0;
        end else if (count == SLOT_CYCLES - 1) begin
            count <= '0;
            digit <= digit + 1'b1;
            if (digit == 7) begin
                value_p1 <= page_lives ? {4'b0,lives_p1} : points_p1;
                value_p2 <= page_lives ? {4'b0,lives_p2} : points_p2;
                lives_frame <= page_lives;
            end
        end else count <= count + 1'b1;
    end
    always_comb begin
        an = ~(8'b1 << digit);
        case (digit)
            0: glyph = value_p1 % 10;
            1: glyph = value_p1 / 10;
            2: glyph = 1;
            3: glyph = lives_frame ? 11 : 10;
            4: glyph = value_p2 % 10;
            5: glyph = value_p2 / 10;
            6: glyph = 2;
            7: glyph = lives_frame ? 11 : 10;
            default: glyph = 15;
        endcase
        case (glyph)
            0: seg = 7'h40; 1: seg = 7'h79; 2: seg = 7'h24;
            3: seg = 7'h30; 4: seg = 7'h19; 5: seg = 7'h12;
            6: seg = 7'h02; 7: seg = 7'h78; 8: seg = 7'h00;
            9: seg = 7'h10; 10: seg = 7'h0c; 11: seg = 7'h47;
            default: seg = 7'h7f;
        endcase
    end
endmodule
