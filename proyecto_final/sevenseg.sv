// Seven-segment decoder
// Leters
// Outputs a-g are active low, as the Nexys A7 needs: 0 lights a segment.
module sevenseg
    import game_pkg::*;
(
    input  logic [4:0] num,
    output logic a, b, c, d, e, f, g
);
    logic [6:0] disp;   // abcdefg display segments, 1 = lit

    always_comb begin
        case (num)
            //               abcdefg
            5'h00:   disp = 7'b1111110;   // 0, also the "O" of GOAL
            5'h01:   disp = 7'b0110000;
            5'h02:   disp = 7'b1101101;
            5'h03:   disp = 7'b1111001;
            5'h04:   disp = 7'b0110011;
            5'h05:   disp = 7'b1011011;
            5'h06:   disp = 7'b1011111;
            5'h07:   disp = 7'b1110000;
            5'h08:   disp = 7'b1111111;
            5'h09:   disp = 7'b1111011;
            5'h0A:   disp = 7'b1110111;
            5'h0B:   disp = 7'b0011111;
            5'h0C:   disp = 7'b1001110;
            5'h0D:   disp = 7'b0111101;
            5'h0E:   disp = 7'b1001111;
            5'h0F:   disp = 7'b1000111;
            // GOAL on the scoreboard.
            GLYPH_P: disp = 7'b1100111;
            GLYPH_L: disp = 7'b0001110;
            GLYPH_G: disp = 7'b1011110;
            GLYPH_A: disp = 7'b1110111;
            default: disp = 7'b0000000;   // Default case blank
        endcase
    end

    // Active low
    assign {a, b, c, d, e, f, g} = ~disp;

endmodule
