// Drawn position of one bike: slides from its previous Cell to its current one over STEPS
// ticks of clk_juego, so the square moves a few pixels every tick instead of a whole
// 16 px Cell once per Step (ADR 0010). Only the drawing changes: the game rules, Crashes
// and position_logic stay Cell-based. The drawing runs one Step behind the game.
// A jump of more than one Cell (back to the start) is drawn at once, not slid.
// draw_x/draw_y are registers, so the glide arithmetic stays out of the clk_pix path:
// drawcon only compares against stored values.
module bike_glide #(
    parameter int STEPS = 6                     // = STEP_TICKS of position_logic, 1..15
) (
    input  logic        clk,                    // clk_juego
    input  logic        rst,
    input  logic [10:0] pos_x, pos_y,           // from position_logic (Cell x16)
    output logic [10:0] draw_x, draw_y          // to drawcon, registered
);
    logic [10:0] seen_x, seen_y;                // pos one tick ago: detects a Step
    logic [10:0] from_x, from_y;                // Cell the slide starts from
    logic [3:0]  g;                             // ticks into the slide, 0..STEPS
    logic        moved, one_cell;
    logic [10:0] fx, fy, off;
    logic [3:0]  g_next;

    // Pixels covered after t ticks, rounded: 0, 3, 5, 8, 11, 13, 16 for STEPS = 6.
    function automatic logic [10:0] offset(input logic [3:0] t);
        return 11'((16 * int'(t) + STEPS / 2) / STEPS);
    endfunction

    // Moves off pixels from 'from' toward 'to', on one axis.
    function automatic logic [10:0] toward(input logic [10:0] from, to, off);
        if (to > from) return from + off;
        if (to < from) return from - off;
        return to;
    endfunction

    always_comb begin
        moved    = (pos_x != seen_x) || (pos_y != seen_y);
        one_cell = (((pos_x == seen_x + 11'd16) || (pos_x + 11'd16 == seen_x)) && pos_y == seen_y)
                || (((pos_y == seen_y + 11'd16) || (pos_y + 11'd16 == seen_y)) && pos_x == seen_x);
        // A one-Cell Step starts a new slide from where the bike was; any other jump is
        // drawn at once.
        fx     = moved ? (one_cell ? seen_x : pos_x) : from_x;
        fy     = moved ? (one_cell ? seen_y : pos_y) : from_y;
        g_next = moved ? (one_cell ? 4'd1 : 4'(STEPS))
                       : (g == 4'(STEPS) ? g : g + 4'd1);
        off    = offset(g_next);
    end

    always_ff @(posedge clk) begin
        seen_x <= pos_x;
        seen_y <= pos_y;
        if (rst) begin
            from_x <= pos_x;
            from_y <= pos_y;
            g      <= 4'(STEPS);
            draw_x <= pos_x;
            draw_y <= pos_y;
        end else begin
            from_x <= fx;
            from_y <= fy;
            g      <= g_next;
            draw_x <= toward(fx, pos_x, off);
            draw_y <= toward(fy, pos_y, off);
        end
    end
endmodule
