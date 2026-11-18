// Author: Alan (AIF31).
// Scoreboard on clk_pix: turns Points, Lives and the goal into the eight digits of the view
// (P2 on the left four, P1 on the right four) and multidigit scans them.
// Inputs must already be clk_pix registers.
module seg7_driver #(parameter int COUNT_BITS = 17) (   // multidigit's scan counter
    input  logic       clk,                    // clk_pix
    input  logic       rst,
    input  logic [5:0] points_p1, points_p2,   // 0-45 in a legal Match: 39 + 3 + 3
    input  logic [1:0] lives_p1, lives_p2,     // 0-3
    input  logic [1:0] view,                   // from seg7_view: 0 Points, 1 Lives, 2 Goal
    input  logic [1:0] goal_sel,               // {SW15, SW14}
    output logic [6:0] seg,                    // seg[0] = a ... seg[6] = g, active low
    output logic [7:0] an                      // active low, an[0] = rightmost digit
);

    logic [3:0] dig0, dig1, dig2, dig3, dig4, dig5, dig6, dig7;

    always_comb
    begin
        case (view)
            2'd1:                        // Lives:  L 2 0 n   L 1 0 n
            begin
                dig7 = 4'd11;            // L
                dig6 = 4'd2;
                dig5 = 4'd0;
                dig4 = lives_p2;
                dig3 = 4'd11;            // L
                dig2 = 4'd1;
                dig1 = 4'd0;
                dig0 = lives_p1;
            end
            2'd2:                        // Goal:   G O A L _ _ n 0
            begin
                dig7 = 4'd12;            // G
                dig6 = 4'd0;             // O
                dig5 = 4'd13;            // A
                dig4 = 4'd11;            // L
                dig3 = 4'd15;            // blank
                dig2 = 4'd15;            // blank
                dig1 = goal_sel + 1;     // 1-4: goal 10, 20, 30, 40
                dig0 = 4'd0;
            end
            default:                     // Points (0, and the unused 3): P 2 n n   P 1 n n
            begin
                dig7 = 4'd10;            // P
                dig6 = 4'd2;
                dig5 = points_p2 / 10;   // tens
                dig4 = points_p2 % 10;   // units
                dig3 = 4'd10;            // P
                dig2 = 4'd1;
                dig1 = points_p1 / 10;   // tens
                dig0 = points_p1 % 10;   // units
            end
        endcase
    end

    multidigit #(.COUNT_BITS(COUNT_BITS)) u_multidigit (
        .clk(clk), .rst(rst),
        .dig0(dig0), .dig1(dig1), .dig2(dig2), .dig3(dig3),
        .dig4(dig4), .dig5(dig5), .dig6(dig6), .dig7(dig7),
        .a(seg[0]), .b(seg[1]), .c(seg[2]), .d(seg[3]), .e(seg[4]), .f(seg[5]), .g(seg[6]),
        .an(an)
    );

endmodule
