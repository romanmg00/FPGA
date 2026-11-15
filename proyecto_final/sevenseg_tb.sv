// Self-checking bench for sevenseg: all 32 codes. The expected segments of each glyph are
// written as the letters of the lit segments (a top, b top right, c bottom right, d bottom,
// e bottom left, f top left, g middle), from the glyph drawings, not copied from the design.
module sevenseg_tb;
    import game_pkg::*;

    logic [4:0] num;
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

    // What each code should show. 0-15 are homework 1's hex digits; the letters are named
    // through game_pkg, so a wrong code there fails here too.
    function automatic string lit_segments(logic [4:0] code, output string glyph);
        case (code)
            5'h00: begin glyph = "0"; return "abcdef";  end
            5'h01: begin glyph = "1"; return "bc";      end
            5'h02: begin glyph = "2"; return "abdeg";   end
            5'h03: begin glyph = "3"; return "abcdg";   end
            5'h04: begin glyph = "4"; return "bcfg";    end
            5'h05: begin glyph = "5"; return "acdfg";   end
            5'h06: begin glyph = "6"; return "acdefg";  end
            5'h07: begin glyph = "7"; return "abc";     end
            5'h08: begin glyph = "8"; return "abcdefg"; end
            5'h09: begin glyph = "9"; return "abcdfg";  end
            5'h0A: begin glyph = "A"; return "abcefg";  end
            5'h0B: begin glyph = "b"; return "cdefg";   end
            5'h0C: begin glyph = "C"; return "adef";    end
            5'h0D: begin glyph = "d"; return "bcdeg";   end
            5'h0E: begin glyph = "E"; return "adefg";   end
            5'h0F: begin glyph = "F"; return "aefg";    end
            GLYPH_P: begin glyph = "P"; return "abefg";  end
            GLYPH_L: begin glyph = "L"; return "def";    end
            GLYPH_G: begin glyph = "G"; return "acdef";  end
            GLYPH_A: begin glyph = "A"; return "abcefg"; end
            default: begin glyph = " "; return "";       end   // GLYPH_BLANK and 21-31
        endcase
    endfunction

    initial begin
        string lit, glyph;

        // The letters must not take a hex code, and each needs its own.
        if (GLYPH_P < 16 || GLYPH_L < 16 || GLYPH_G < 16 || GLYPH_A < 16 || GLYPH_BLANK < 16)
            fail("a letter glyph reuses a hex code (0-15)");
        if (GLYPH_P == GLYPH_L || GLYPH_P == GLYPH_G || GLYPH_P == GLYPH_A || GLYPH_P == GLYPH_BLANK ||
            GLYPH_L == GLYPH_G || GLYPH_L == GLYPH_A || GLYPH_L == GLYPH_BLANK ||
            GLYPH_G == GLYPH_A || GLYPH_G == GLYPH_BLANK || GLYPH_A == GLYPH_BLANK)
            fail("two glyphs share a code");

        for (int code = 0; code < 32; code++) begin
            num = 5'(code);
            #10;
            lit = lit_segments(num, glyph);
            if ({a, b, c, d, e, f, g} !== pins_for(lit))
                fail($sformatf("code %0d (\"%s\"): pins abcdefg = %b, expected %b",
                               code, glyph, {a, b, c, d, e, f, g}, pins_for(lit)));
        end

        // The "O" of GOAL is the 0 glyph; blank lights nothing.
        num = 5'h00; #10;
        if ({a, b, c, d, e, f, g} !== pins_for("abcdef")) fail("0 is not the O of GOAL");
        num = GLYPH_BLANK; #10;
        if ({a, b, c, d, e, f, g} !== 7'b1111111) fail("blank lights a segment");

        $display("PASS sevenseg_tb");
        $finish;
    end

endmodule
