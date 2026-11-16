// Self-checking bench for sevenseg: all 16 codes. The expected segments of each glyph are
// written as the letters of the lit segments (a top, b top right, c bottom right, d bottom,
// e bottom left, f top left, g middle), from the glyph drawings, not copied from the design.
module sevenseg_tb;

    logic [3:0] num;
    logic a, b, c, d, e, f, g;

    sevenseg dut (.num, .a, .b, .c, .d, .e, .f, .g);

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "sevenseg_tb failed");
    endfunction

    // Letters of the lit segments to the active-low pins {a, b, c, d, e, f, g}.
    function automatic logic [6:0] pins_for(string lit);
        logic [6:0] on = '0;   // bit 6 = a ... bit 0 = g
        for (int i = 0; i < lit.len(); i++)
            on[6 - (int'(lit.getc(i)) - int'("a"))] = 1'b1;
        return ~on;
    endfunction

    // What each code should show: 0-9, then P, L, G, A, then blank.
    function automatic string lit_segments(logic [3:0] code, output string glyph);
        case (code)
            4'd0:  begin glyph = "0"; return "abcdef";  end
            4'd1:  begin glyph = "1"; return "bc";      end
            4'd2:  begin glyph = "2"; return "abdeg";   end
            4'd3:  begin glyph = "3"; return "abcdg";   end
            4'd4:  begin glyph = "4"; return "bcfg";    end
            4'd5:  begin glyph = "5"; return "acdfg";   end
            4'd6:  begin glyph = "6"; return "acdefg";  end
            4'd7:  begin glyph = "7"; return "abc";     end
            4'd8:  begin glyph = "8"; return "abcdefg"; end
            4'd9:  begin glyph = "9"; return "abcdfg";  end
            4'd10: begin glyph = "P"; return "abefg";   end
            4'd11: begin glyph = "L"; return "def";     end
            4'd12: begin glyph = "G"; return "acdef";   end
            4'd13: begin glyph = "A"; return "abcefg";  end
            default: begin glyph = " "; return "";      end   // 14, 15
        endcase
    endfunction

    initial begin
        string lit, glyph;

        for (int code = 0; code < 16; code++) begin
            num = 4'(code);
            #10;
            lit = lit_segments(num, glyph);
            if ({a, b, c, d, e, f, g} !== pins_for(lit))
                fail($sformatf("code %0d (\"%s\"): pins abcdefg = %b, expected %b",
                               code, glyph, {a, b, c, d, e, f, g}, pins_for(lit)));
        end

        // The O of GOAL is the 0 glyph; blank lights nothing.
        num = 4'd0; #10;
        if ({a, b, c, d, e, f, g} !== pins_for("abcdef")) fail("0 is not the O of GOAL");
        num = 4'd15; #10;
        if ({a, b, c, d, e, f, g} !== 7'b1111111) fail("blank lights a segment");

        $display("PASS sevenseg_tb");
        $finish;
    end

endmodule
