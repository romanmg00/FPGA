// Self-checking bench for seg7_driver, from its pins only, with SLOT_CYCLES = 2. Every cycle
// exactly one anode is low. Each check reads one whole scan back as eight characters, dig7
// first, with a segment table written from the glyph drawings, and compares it with the
// text the spec and ADR 0008 give for that view (built with $sformatf, not by the design's
// arithmetic). seg is decoded as seg[0] = a ... seg[6] = g.
module seg7_driver_tb;
    import game_pkg::*;

    logic       clk = 1'b0, rst = 1'b1;
    logic [5:0] points_p1 = '0, points_p2 = '0;
    logic [1:0] lives_p1 = '0, lives_p2 = '0, view = VIEW_POINTS, goal_sel = 2'b00;
    logic [6:0] seg;
    logic [7:0] an;

    seg7_driver #(.SLOT_CYCLES(2)) dut (.*);

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "seg7_driver_tb failed");
    endfunction

    // Active-low pins {a, ..., g} to the character they show; "?" if no glyph matches.
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

    function automatic int lit_digit(logic [7:0] an_now);
        int found = -1;
        if ($isunknown(an_now)) return -1;
        for (int i = 0; i < 8; i++)
            if (!an_now[i]) begin
                if (found != -1) return -1;
                found = i;
            end
        return found;
    endfunction

    // Exactly one digit lit in every cycle, reset included.
    always begin
        @(posedge clk);
        #1;
        if (lit_digit(an) < 0) fail($sformatf("an = %b, not exactly one low anode", an));
    end

    task automatic tick();
        @(posedge clk);
        #2;
    endtask

    // Reads one whole scan as eight characters, dig7 first.
    task automatic expect_frame(string what, string expected);
        string got = "????????";
        while (lit_digit(an) != 7) tick();   // skip a partial frame
        while (lit_digit(an) != 0) tick();
        for (int k = 0; k < 8; k++) begin
            while (lit_digit(an) != k) tick();
            got[7 - k] = decode({seg[0], seg[1], seg[2], seg[3], seg[4], seg[5], seg[6]});
        end
        if (got != expected) fail($sformatf("%s: shows \"%s\", expected \"%s\"", what, got, expected));
    endtask

    initial begin
        repeat (3) tick();
        rst = 1'b0;
        expect_frame("power-up", "P200P100");

        // Points: every value 0-63 on both banks, P2 on the left. 45 is the largest legal
        // total (39 + 3 + 3); 6 bits reach 63.
        for (int p = 0; p < 64; p++) begin
            points_p1 = 6'(p);
            points_p2 = 6'(63 - p);
            expect_frame("Points", $sformatf("P2%02dP1%02d", 63 - p, p));
        end

        // Lives 0-3, with the leading zero.
        view = VIEW_LIVES;
        for (int l = 0; l < 4; l++) begin
            lives_p1 = 2'(l);
            lives_p2 = 2'(3 - l);
            expect_frame("Lives", $sformatf("L2%02dL1%02d", 3 - l, l));
        end

        // Goal: GOAL, two blanks and the goal of {SW15, SW14}; Points and Lives do not show.
        view = VIEW_GOAL;
        points_p1 = 6'd45;
        lives_p2 = 2'd3;
        for (int s = 0; s < 4; s++) begin
            goal_sel = 2'(s);
            expect_frame("Goal", $sformatf("G0AL  %0d0", s + 1));
        end

        // The unused view code shows Points.
        view = 2'd3;
        points_p1 = 6'd9;
        points_p2 = 6'd10;
        expect_frame("view code 3", "P210P109");

        // Back to Points from Goal.
        view = VIEW_POINTS;
        expect_frame("Points again", "P210P109");

        $display("PASS seg7_driver_tb");
        $finish;
    end

    initial begin
        #1ms;
        fail("timeout");
    end

endmodule
