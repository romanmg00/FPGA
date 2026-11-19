// Author: Alan (AIF31).
// Self-checking bench for multidigit, from its pins: one low anode every cycle, the right
// glyph, scan order, digit time (COUNT_BITS = 2 and the default 17) and whole frames.
module multidigit_tb;
    localparam int FAST_SLOT = 4;         // 2^2
    localparam int REAL_SLOT = 131_072;   // 2^17: 1.57 ms per digit at 83,455,882 Hz

    logic clk = 1'b0, rst = 1'b1;
    logic [3:0] dig [0:7];               // bench-only array; the ports are dig0..dig7
    logic       fa, fb, fc, fd, fe, ff, fg, ra, rb, rc, rd, re, rf, rg;
    logic [7:0] fan, ran;

    multidigit #(.COUNT_BITS(2)) dut_fast (
        .clk, .rst,
        .dig0(dig[0]), .dig1(dig[1]), .dig2(dig[2]), .dig3(dig[3]),
        .dig4(dig[4]), .dig5(dig[5]), .dig6(dig[6]), .dig7(dig[7]),
        .a(fa), .b(fb), .c(fc), .d(fd), .e(fe), .f(ff), .g(fg), .an(fan)
    );
    multidigit dut_real (
        .clk, .rst,
        .dig0(dig[0]), .dig1(dig[1]), .dig2(dig[2]), .dig3(dig[3]),
        .dig4(dig[4]), .dig5(dig[5]), .dig6(dig[6]), .dig7(dig[7]),
        .a(ra), .b(rb), .c(rc), .d(rd), .e(re), .f(rf), .g(rg), .an(ran)
    );

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "multidigit_tb failed");
    endfunction

    // Active-low pins {a, ..., g} to the character they show; "?" if no glyph matches.
    // Written from the glyph drawings, not from sevenseg.
    function automatic byte decode(logic [6:0] pins);
        case (~pins)       // abcdefg, 1 = lit
            7'b1111110: return "0";   7'b0110000: return "1";   7'b1101101: return "2";
            7'b1111001: return "3";   7'b0110011: return "4";   7'b1011011: return "5";
            7'b1011111: return "6";   7'b1110000: return "7";   7'b1111111: return "8";
            7'b1111011: return "9";   7'b1100111: return "P";   7'b0001110: return "L";
            7'b1011110: return "G";   7'b1110111: return "A";   7'b0000000: return " ";
            default:    return "?";
        endcase
    endfunction

    // The character a code should show.
    function automatic byte expected_char(logic [3:0] code);
        if (code <= 4'd9) return byte'("0" + code);
        case (code)
            4'd10:   return "P";
            4'd11:   return "L";
            4'd12:   return "G";
            4'd13:   return "A";
            default: return " ";   // 14, 15
        endcase
    endfunction

    // Index of the one low anode, or -1 if none or more than one is low.
    function automatic int lit_digit(logic [7:0] an);
        int found = -1;
        if ($isunknown(an)) return -1;
        for (int i = 0; i < 8; i++)
            if (!an[i]) begin
                if (found != -1) return -1;
                found = i;
            end
        return found;
    endfunction

    // Per-instance scan state, checked once per cycle just after the clock edge.
    typedef struct {
        int k_prev;      // digit lit in the previous cycle
        int run_len;     // cycles the current digit has been lit
        int slots;       // completed slots since reset
    } scan_t;

    task automatic check_scan(string name, int slot_cycles, logic [7:0] an, logic [6:0] pins,
                              bit in_reset, ref scan_t st);
        int k = lit_digit(an);
        byte shown;
        if (k < 0) fail($sformatf("%s: an = %b, not exactly one low anode", name, an));
        shown = decode(pins);
        if (shown != expected_char(dig[k]))
            fail($sformatf("%s: digit %0d shows \"%s\" (pins %b), its code %0d should show \"%s\"",
                           name, k, shown, pins, dig[k], expected_char(dig[k])));
        if (in_reset) begin
            // rst was sampled at this edge: the scan restarts on digit 0 with a full slot.
            if (k != 0) fail($sformatf("%s: digit %0d lit in reset", name, k));
            st.run_len = 1;
            st.slots = 0;
        end else if (k == st.k_prev) begin
            st.run_len++;
            if (st.run_len > slot_cycles)
                fail($sformatf("%s: digit %0d lit for more than %0d cycles", name, k, slot_cycles));
        end else begin
            if (k != (st.k_prev + 1) % 8)
                fail($sformatf("%s: scan went from digit %0d to %0d", name, st.k_prev, k));
            if (st.run_len != slot_cycles)
                fail($sformatf("%s: digit %0d was lit %0d cycles, expected %0d",
                               name, st.k_prev, st.run_len, slot_cycles));
            st.run_len = 1;
            st.slots++;
        end
        st.k_prev = k;
    endtask

    scan_t fast_st = '{0, 0, 0}, real_st = '{0, 0, 0};
    always begin
        @(posedge clk);
        #1;
        check_scan("fast", FAST_SLOT, fan, {fa, fb, fc, fd, fe, ff, fg}, rst, fast_st);
        check_scan("real", REAL_SLOT, ran, {ra, rb, rc, rd, re, rf, rg}, rst, real_st);
    end

    task automatic tick();
        @(posedge clk);
        #2;   // after the checker
    endtask

    // Sets the eight digits from left (dig7) to right (dig0), between clock edges.
    task automatic show(logic [3:0] d7, d6, d5, d4, d3, d2, d1, d0);
        @(negedge clk);
        {dig[7], dig[6], dig[5], dig[4], dig[3], dig[2], dig[1], dig[0]} = {d7, d6, d5, d4, d3, d2, d1, d0};
    endtask

    // Reads one whole scan of the fast instance as eight characters, dig7 first.
    task automatic expect_frame(string expected);
        string got = "????????";
        while (lit_digit(fan) != 7) tick();   // skip a partial frame
        while (lit_digit(fan) != 0) tick();
        for (int k = 0; k < 8; k++) begin
            while (lit_digit(fan) != k) tick();
            got[7 - k] = decode({fa, fb, fc, fd, fe, ff, fg});
        end
        if (got != expected) fail($sformatf("frame \"%s\", expected \"%s\"", got, expected));
    endtask

    initial begin
        for (int i = 0; i < 8; i++) dig[i] = 4'd15;   // blank
        repeat (3) tick();
        @(negedge clk) rst = 1'b0;

        // The three Scoreboard views of ADR 0008, and both banks.
        // Codes: 10 P, 11 L, 12 G, 13 A, 14 and 15 blank.
        show(4'd10, 4'd2, 4'd4, 4'd5, 4'd10, 4'd1, 4'd0, 4'd9);
        expect_frame("P245P109");
        show(4'd11, 4'd2, 4'd0, 4'd3, 4'd11, 4'd1, 4'd0, 4'd1);
        expect_frame("L203L101");
        show(4'd12, 4'd0, 4'd13, 4'd11, 4'd15, 4'd15, 4'd2, 4'd0);
        expect_frame("G0AL  20");

        // Every code, in every position.
        show(4'd0, 4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7);
        expect_frame("01234567");
        show(4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13, 4'd14, 4'd15);
        expect_frame("89PLGA  ");

        // Codes changing at any time: the checker requires the lit digit to show its new
        // code in the same cycle.
        for (int n = 0; n < 200; n++) begin
            @(negedge clk);
            dig[$urandom_range(7)] = 4'($urandom_range(15));
        end

        // Reset in the middle of a scan: back to digit 0 with a full slot (checker).
        while (lit_digit(fan) != 5) tick();
        @(negedge clk) rst = 1'b1;
        @(negedge clk) rst = 1'b0;
        show(4'd10, 4'd2, 4'd1, 4'd0, 4'd10, 4'd1, 4'd0, 4'd0);
        expect_frame("P210P100");

        // The real instance: more than one full scan at the default COUNT_BITS.
        while (real_st.slots < 9) tick();
        $display("real instance: %0d slots of %0d cycles; at 83,455,882 Hz each digit is lit %.2f ms and all eight are refreshed every %.1f ms",
                 real_st.slots, REAL_SLOT, 1.0e3 * REAL_SLOT / 83_455_882.0, 8.0e3 * REAL_SLOT / 83_455_882.0);

        $display("PASS multidigit_tb");
        $finish;
    end

    initial begin
        #30ms;
        fail("timeout");
    end

endmodule
