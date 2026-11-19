// Author: Alan (AIF31).
// Drawn position of one bike: slides from its previous Cell to its current one over STEP_TICKS
// ticks of clk_juego, so the square moves a few pixels every tick instead of a whole
// 16 px Cell once per Step (ADR 0010). Only the drawing changes: the game rules, Crashes
// and position_logic stay Cell-based. The drawing runs one Step behind the game.
// A jump of more than one Cell (back to the start) is drawn at once, not slid.
// glide_x/glide_y are registers, so the glide arithmetic stays out of the clk_pix path:
// drawcon only compares against stored values.
module bike_glide #(
    parameter int STEP_TICKS = 6                // = STEP_TICKS of position_logic, 1..15
) (
    input  logic        clk,                    // clk_juego
    input  logic        rst,
    input  logic [10:0] blkpos_x, blkpos_y,     // from position_logic (Cell x16)
    output logic [10:0] glide_x, glide_y        // to drawcon, registered
);
    logic [10:0] blkpos_x_last, blkpos_y_last;  // blkpos one tick earlier: detects a Step
    logic [10:0] from_x, from_y;                // Cell the slide starts from
    logic [3:0]  glide_tick;                    // ticks into the slide, 0..STEP_TICKS
    logic        moved, one_cell;
    logic [10:0] from_x_next, from_y_next, offset_px;
    logic [3:0]  glide_tick_next;

    // Pixels covered after t ticks, rounded: 0, 3, 5, 8, 11, 13, 16 for STEP_TICKS = 6.
    function automatic logic [10:0] offset(input logic [3:0] t);
        return 11'((16 * int'(t) + STEP_TICKS / 2) / STEP_TICKS);
    endfunction

    // Moves off pixels from 'from' toward 'to', on one axis.
    function automatic logic [10:0] toward(input logic [10:0] from, to, off);
        if (to > from) return from + off;
        if (to < from) return from - off;
        return to;
    endfunction

    always_comb begin
        moved    = (blkpos_x != blkpos_x_last) || (blkpos_y != blkpos_y_last);
        one_cell = (((blkpos_x == blkpos_x_last + 11'd16) || (blkpos_x + 11'd16 == blkpos_x_last)) && blkpos_y == blkpos_y_last)
                || (((blkpos_y == blkpos_y_last + 11'd16) || (blkpos_y + 11'd16 == blkpos_y_last)) && blkpos_x == blkpos_x_last);
        // A one-Cell Step starts a new slide from where the bike was; any other jump is
        // drawn at once.
        from_x_next     = moved ? (one_cell ? blkpos_x_last : blkpos_x) : from_x;
        from_y_next     = moved ? (one_cell ? blkpos_y_last : blkpos_y) : from_y;
        glide_tick_next = moved ? (one_cell ? 4'd1 : 4'(STEP_TICKS))
                                : (glide_tick == 4'(STEP_TICKS) ? glide_tick : glide_tick + 4'd1);
        offset_px       = offset(glide_tick_next);
    end

    always_ff @(posedge clk) begin
        blkpos_x_last <= blkpos_x;
        blkpos_y_last <= blkpos_y;
        if (rst) begin
            from_x     <= blkpos_x;
            from_y     <= blkpos_y;
            glide_tick <= 4'(STEP_TICKS);
            glide_x    <= blkpos_x;
            glide_y    <= blkpos_y;
        end else begin
            from_x     <= from_x_next;
            from_y     <= from_y_next;
            glide_tick <= glide_tick_next;
            glide_x    <= toward(from_x_next, blkpos_x, offset_px);
            glide_y    <= toward(from_y_next, blkpos_y, offset_px);
        end
    end
endmodule
