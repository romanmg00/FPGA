// Shared constants (contract section 5). The contract lists the whole package; a constant
// is added here when a module first uses it, so nothing in this file is unused or a second
// copy of a value another file already sets. STEP_TICKS, for example, still lives in
// game_top.sv.
package game_pkg;

    // Glyph codes for sevenseg's 5-bit num (Physical Scoreboard, ADR 0008). Codes 0-15 show
    // 0-9 and A-F, as in the course's homework 1. The letters the Scoreboard needs get their
    // own codes from 16, so a hex code always means its hex digit. The "O" of GOAL is code 0.
    localparam logic [4:0] GLYPH_P     = 5'd16;
    localparam logic [4:0] GLYPH_L     = 5'd17;
    localparam logic [4:0] GLYPH_G     = 5'd18;
    localparam logic [4:0] GLYPH_A     = 5'd19;
    localparam logic [4:0] GLYPH_BLANK = 5'd20;   // all segments off; so are codes 21-31

endpackage
