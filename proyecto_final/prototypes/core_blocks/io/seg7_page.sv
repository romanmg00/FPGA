// Owner Alan. clk_juego (~60 Hz). ALL ports/parameters PROVISIONAL.
// Crossing: page_lives/page_goal with Points/Lives and goal_sel -> clk_pix coherent
// snapshot, UNSELECTED (ADR 0003 item 2); do not independently synchronize payload bits.
// Default follows model/seg7.py and locked Physical Scoreboard rule: runs in Pause.
//
// Pages: Points, then Lives, every VIEW_TICKS. While waiting for a new Match
// (waiting: G_IDLE or G_MATCH, where Start takes the Points Goal) a third page
// shows the goal {SW15, SW14} selects: Points -> Lives -> Goal -> Points. A
// change of goal_sel while waiting jumps to the Goal page and restarts its
// time, so the switches show their effect at once. Proposed 12 Nov 2026 after
// the first board check; proposed in ADR 0008, not part of the locked Scoreboard rule yet.
module seg7_page #(
    parameter integer VIEW_TICKS = game_pkg::SCORE_VIEW_TICKS,
    parameter bit RUN_DURING_PAUSE = 1'b1
) (
    input logic clk_juego, rst, new_match, pause,
    input logic waiting,                 // G_IDLE or G_MATCH, phase before this edge
    input logic [1:0] goal_sel,          // synchronized {SW15, SW14}
    output logic page_lives,
    output logic page_goal               // never both set
);
    import game_pkg::*;
    localparam integer COUNT_W = VIEW_TICKS > 1 ? $clog2(VIEW_TICKS) : 1;
    logic [COUNT_W-1:0] count;
    logic [1:0] last_sel;
    always_ff @(posedge clk_juego) begin
        if (rst) last_sel <= '0;
        else last_sel <= goal_sel;
        if (rst || new_match) begin
            count <= '0;
            page_lives <= 1'b0;
            page_goal <= 1'b0;
        end else if (RUN_DURING_PAUSE || !pause) begin
            if (waiting && goal_sel != last_sel) begin
                count <= '0;
                page_lives <= 1'b0;
                page_goal <= 1'b1;
            end else if (count == VIEW_TICKS - 1) begin
                count <= '0;
                page_lives <= !page_lives && !page_goal;           // Points -> Lives
                page_goal <= page_lives && waiting;                 // Lives -> Goal while waiting
            end else count <= count + 1'b1;
        end
    end
endmodule
