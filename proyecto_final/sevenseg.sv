// Seven-segment decoder: num 0-9 shows the digit, 10-13 show P, L, G, A for the Scoreboard
// and 14-15 are blank. Outputs a-g are active low (0 lights a segment).
module sevenseg(
    input  logic [3:0] num,
    output logic a, b, c, d, e, f, g
    );
    logic [6:0] disp; // abcdefg display segments

    always_comb
    begin
        case (num)
            //              abcdefg
            4'd0:  disp = 7'b1111110;   // also the O of GOAL
            4'd1:  disp = 7'b0110000;
            4'd2:  disp = 7'b1101101;
            4'd3:  disp = 7'b1111001;
            4'd4:  disp = 7'b0110011;
            4'd5:  disp = 7'b1011011;
            4'd6:  disp = 7'b1011111;
            4'd7:  disp = 7'b1110000;
            4'd8:  disp = 7'b1111111;
            4'd9:  disp = 7'b1111011;
            4'd10: disp = 7'b1100111;   // P (Points)
            4'd11: disp = 7'b0001110;   // L (Lives)
            4'd12: disp = 7'b1011110;   // G (GOAL)
            4'd13: disp = 7'b1110111;   // A (GOAL)
            default: disp = 7'b0000000; // 14, 15: blank
        endcase
    end
    // Active low
    assign {a, b, c, d, e, f, g} = ~disp;

endmodule
