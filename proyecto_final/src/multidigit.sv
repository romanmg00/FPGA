// Author: Alan (AIF31), adapted from his CS-256 homework 1; scan enable on clk_pix (#34).
// Eight 7-segment digits on one set of a-g pins; digit 0 is the rightmost.
// On clk_pix, sel moves to the next digit each time the 17-bit counter is full:
// 2^17 cycles = 1.57 ms per digit, 12.6 ms for all eight.
module multidigit #(parameter int COUNT_BITS = 17) (
    input  logic       clk,     // clk_pix
    input  logic       rst,
    input  logic [3:0] dig0, dig1, dig2, dig3, dig4, dig5, dig6, dig7,
    output logic       a, b, c, d, e, f, g,
    output logic [7:0] an       // active low, an[0] = digit 0
);

    logic [COUNT_BITS-1:0] count;   // counts up and wraps around by itself, like counter17
    logic [2:0] sel;                // which digit is currently lit (0-7)
    logic [3:0] cur_digit;          // value of the selected digit
    logic [7:0] an_decode;          // selected digit

    // Free-running counter on clk_pix
    always_ff @(posedge clk)
    begin
        if (rst)
            count <= 0;
        else
            count <= count + 1'b1;
    end

    // 3-bit counter: next digit each time count is full (all ones)
    always_ff @(posedge clk)
    begin
        if (rst)
            sel <= 3'd0;
        else if (count == {COUNT_BITS{1'b1}})
            sel <= sel + 1'b1;
    end

    // 8:1 multiplexer for selected digit
    always_comb
    begin
        case (sel)
            3'd0: cur_digit = dig0;
            3'd1: cur_digit = dig1;
            3'd2: cur_digit = dig2;
            3'd3: cur_digit = dig3;
            3'd4: cur_digit = dig4;
            3'd5: cur_digit = dig5;
            3'd6: cur_digit = dig6;
            3'd7: cur_digit = dig7;
            default: cur_digit = 4'h0;
        endcase
    end

    // 3:8 decoder for active high, one digit selected
    always_comb
    begin
        case (sel)
            3'd0: an_decode = 8'b00000001;
            3'd1: an_decode = 8'b00000010;
            3'd2: an_decode = 8'b00000100;
            3'd3: an_decode = 8'b00001000;
            3'd4: an_decode = 8'b00010000;
            3'd5: an_decode = 8'b00100000;
            3'd6: an_decode = 8'b01000000;
            3'd7: an_decode = 8'b10000000;
            default: an_decode = 8'b00000000;
        endcase
    end

    // Convert to active low
    assign an = ~an_decode;
    // Seven segment decoder
    sevenseg seg_decoder (.num(cur_digit), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g));

endmodule
