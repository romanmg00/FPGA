// Eight seven-segment digits from one set of a-g pins, as in the course's homework 1: a 3-bit
// counter sel picks one digit at a time, an 8:1 mux sends its code to sevenseg, and a 3:8
// decoder lights its anode. Digit 0 is the rightmost. Scanning fast enough makes all eight
// look lit at once.
//
// Differences from the homework:
// - The homework clocked this module from bit 16 of a counter, used as a clock. The design
//   has one Clocking Wizard and clk_juego, and no other clock (ADR 0006), so here clk is
//   clk_pix and a counter makes scan_en, one cycle every SLOT_CYCLES: sel only advances then.
// - Digit codes are 5 bits, for sevenseg's extra glyphs (P, L, G, A, blank).
//
// SLOT_CYCLES = 10,432 at 83,455,882 Hz lights each digit for 125 us, so every digit is
// refreshed at about 1 kHz (1 ms per scan of all eight). SLOT_CYCLES = 1 advances every
// cycle, as the homework did. Exactly one anode is low in every cycle: no dark periods.
module multidigit #(
    parameter int SLOT_CYCLES = 10_432
) (
    input  logic       clk,     // clk_pix
    input  logic       rst,
    input  logic [4:0] dig0, dig1, dig2, dig3, dig4, dig5, dig6, dig7,
    output logic       a, b, c, d, e, f, g,
    output logic [7:0] an       // active low, an[0] = digit 0
);

    // Counts 0 to SLOT_CYCLES-1. LAST has the counter's width, so the comparison matches.
    localparam int W = (SLOT_CYCLES > 1) ? $clog2(SLOT_CYCLES) : 1;
    localparam logic [W-1:0] LAST = W'(SLOT_CYCLES - 1);

    logic [W-1:0] slot_cnt;
    logic         scan_en;     // 1 for one clk cycle at the end of each digit's slot
    logic [2:0]   sel;         // which digit is currently lit (0-7)
    logic [4:0]   cur_digit;   // code of the selected digit
    logic [7:0]   an_decode;   // selected digit, active high

    // Clock enable for the scan: restarts after its last value
    always_ff @(posedge clk) begin
        if (rst || scan_en)
            slot_cnt <= '0;
        else
            slot_cnt <= slot_cnt + 1'b1;
    end
    assign scan_en = (slot_cnt == LAST);

    // 3-bit counter, one step per slot; wraps from 7 to 0 by itself
    always_ff @(posedge clk) begin
        if (rst)
            sel <= 3'd0;
        else if (scan_en)
            sel <= sel + 1'b1;
    end

    // 8:1 multiplexer for the selected digit
    always_comb begin
        case (sel)
            3'd0: cur_digit = dig0;
            3'd1: cur_digit = dig1;
            3'd2: cur_digit = dig2;
            3'd3: cur_digit = dig3;
            3'd4: cur_digit = dig4;
            3'd5: cur_digit = dig5;
            3'd6: cur_digit = dig6;
            3'd7: cur_digit = dig7;
            default: cur_digit = 5'h00;        // unreachable: sel has 8 values
        endcase
    end

    // 3:8 decoder, active high, one digit selected
    always_comb begin
        case (sel)
            3'd0: an_decode = 8'b00000001;
            3'd1: an_decode = 8'b00000010;
            3'd2: an_decode = 8'b00000100;
            3'd3: an_decode = 8'b00001000;
            3'd4: an_decode = 8'b00010000;
            3'd5: an_decode = 8'b00100000;
            3'd6: an_decode = 8'b01000000;
            3'd7: an_decode = 8'b10000000;
            default: an_decode = 8'b00000000;   // unreachable
        endcase
    end

    // Convert to active low
    assign an = ~an_decode;

    // Seven-segment decoder
    sevenseg seg_decoder (.num(cur_digit), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g));

endmodule
