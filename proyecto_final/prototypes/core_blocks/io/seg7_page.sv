// Owner Alan. clk_juego (~60 Hz). ALL ports/parameters PROVISIONAL.
// Crossing: page_lives with Points/Lives -> clk_pix coherent snapshot, UNSELECTED
// (ADR 0003 item 2); do not independently synchronize payload bits.
// Default follows model/seg7.py and locked Physical Scoreboard rule: runs in Pause.
module seg7_page #(
    parameter integer VIEW_TICKS = game_pkg::SCORE_VIEW_TICKS,
    parameter bit RUN_DURING_PAUSE = 1'b1
) (
    input logic clk_juego, rst, new_match, pause,
    output logic page_lives
);
    import game_pkg::*;
    localparam integer COUNT_W = VIEW_TICKS > 1 ? $clog2(VIEW_TICKS) : 1;
    logic [COUNT_W-1:0] count;
    always_ff @(posedge clk_juego) begin
        if (rst || new_match) begin
            count <= '0;
            page_lives <= 1'b0;
        end else if (RUN_DURING_PAUSE || !pause) begin
            if (count == VIEW_TICKS - 1) begin
                count <= '0;
                page_lives <= !page_lives;
            end else count <= count + 1'b1;
        end
    end
endmodule
