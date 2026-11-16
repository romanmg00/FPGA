// Shared constants (contract section 5). The contract lists the whole package; a constant
// is added here when a module first uses it, so nothing in this file is unused or a second
// copy of a value another file already sets. STEP_TICKS, for example, still lives in
// game_top.sv.
package game_pkg;

    // own codes from 16, so a hex code always means its hex digit. The "O" of GOAL is code 0.
    localparam logic [4:0] GLYPH_P     = 5'd16; // P for "Points" on the scoreboard
    localparam logic [4:0] GLYPH_L     = 5'd17; // L for "Lives" on the scoreboard
    localparam logic [4:0] GLYPH_G     = 5'd18; // G for "GOAL" on the scoreboard
    localparam logic [4:0] GLYPH_A     = 5'd19; // A for "GOAL" on the scoreboard
    localparam logic [4:0] GLYPH_BLANK = 5'd20;   // all segments off
    
    // SCORE_VIEW_TICKS ticks of clk_juego: 180 at 59.99997 Hz is 3.0 s.
    localparam int SCORE_VIEW_TICKS = 180;
    // The scoreboard shows one of three views, each for SCORE_VIEW_TICKS ticks of clk_juego.
    localparam logic [1:0] VIEW_POINTS = 2'd0, VIEW_LIVES = 2'd1, VIEW_GOAL = 2'd2;

endpackage
