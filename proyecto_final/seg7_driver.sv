// The Physical Scoreboard on the eight 7-segment digits, on clk_pix (contract section 4,
// ADR 0008). It turns the values into eight glyph codes and multidigit scans them.
// Left (dig7) to right (dig0):
//   Points  P 2 n n P 1 n n    P2 on an[7:4], P1 on an[3:0]; two decimal digits each
//   Lives   L 2 0 n L 1 0 n    with the leading zero
//   Goal    G O A L _ _ n 0    the goal {SW15, SW14} selects: 10, 20, 30 or 40
// Any other view code shows Points. The inputs must be clk_pix registers that change
// together: game_top crosses them from clk_juego, and this module only reads them.
module seg7_driver
    import game_pkg::*;
#(
    parameter int SLOT_CYCLES = 10_432   // multidigit: about 1 kHz per digit at clk_pix
) (
    input  logic       clk,                    // clk_pix
    input  logic       rst,
    input  logic [5:0] points_p1, points_p2,   // 0-45 in a legal Match: 39 + 3 + 3
    input  logic [1:0] lives_p1, lives_p2,     // 0-3
    input  logic [1:0] view,                   // from seg7_view
    input  logic [1:0] goal_sel,               // {SW15, SW14}
    output logic [6:0] seg,                    // seg[0] = a ... seg[6] = g, active low
    output logic [7:0] an                      // active low, an[0] = rightmost digit
);

    logic [4:0] dig0, dig1, dig2, dig3, dig4, dig5, dig6, dig7;

    // Tens and units of a value 0-63, as digit codes 0-9
    function automatic logic [4:0] tens(input logic [5:0] value);
        return 5'(value / 10);
    endfunction
    function automatic logic [4:0] units(input logic [5:0] value);
        return 5'(value % 10);
    endfunction

    always_comb begin
        case (view)
            VIEW_LIVES:
                {dig7, dig6, dig5, dig4, dig3, dig2, dig1, dig0} =
                    {GLYPH_L, 5'd2, 5'd0, 5'(lives_p2), GLYPH_L, 5'd1, 5'd0, 5'(lives_p1)};
            VIEW_GOAL:
                {dig7, dig6, dig5, dig4, dig3, dig2, dig1, dig0} =
                    {GLYPH_G, 5'd0, GLYPH_A, GLYPH_L, GLYPH_BLANK, GLYPH_BLANK, 5'(goal_sel) + 5'd1, 5'd0};
            default:   // VIEW_POINTS
                {dig7, dig6, dig5, dig4, dig3, dig2, dig1, dig0} =
                    {GLYPH_P, 5'd2, tens(points_p2), units(points_p2),
                     GLYPH_P, 5'd1, tens(points_p1), units(points_p1)};
        endcase
    end

    multidigit #(.SLOT_CYCLES(SLOT_CYCLES)) u_multidigit (
        .clk(clk), .rst(rst),
        .dig0(dig0), .dig1(dig1), .dig2(dig2), .dig3(dig3),
        .dig4(dig4), .dig5(dig5), .dig6(dig6), .dig7(dig7),
        .a(seg[0]), .b(seg[1]), .c(seg[2]), .d(seg[3]), .e(seg[4]), .f(seg[5]), .g(seg[6]),
        .an(an)
    );

endmodule
