// Which view the Scoreboard shows, on clk_juego (spec, Physical Scoreboard; ADR 0008).
// Points and Lives alternate, VIEW_TICKS ticks each (180, about 3 s). While waiting for a new
// Match (before the first one, and at Match-over), the Goal view joins them:
// Points -> Lives -> Goal -> Points. A change of {SW15, SW14} while waiting jumps to the Goal
// view and restarts its time, so the switches show their effect at once. A new Match starts
// on Points. Crash, ready wait and Pause do not stop the views: there is no pause input.
// Same behaviour as PageTimer in prototipos/tron_fpga/model/seg7.py.
module seg7_view
    import game_pkg::*;
#(
    parameter int VIEW_TICKS = SCORE_VIEW_TICKS
) (
    input  logic       clk,         // clk_juego
    input  logic       rst,
    input  logic       new_match,   // 1 on the tick a Start begins a new Match
    input  logic       waiting,     // waiting for a new Match, where Start takes the goal
    input  logic [1:0] goal_sel,    // synchronized {SW15, SW14}
    output logic [1:0] view         // VIEW_POINTS, VIEW_LIVES or VIEW_GOAL
);

    // Counts 0 to VIEW_TICKS-1. LAST has the counter's width, so the comparison matches.
    localparam int W = (VIEW_TICKS > 1) ? $clog2(VIEW_TICKS) : 1;
    localparam logic [W-1:0] LAST = W'(VIEW_TICKS - 1);

    logic [W-1:0] timer;
    logic [1:0]   last_sel;   // goal_sel one tick earlier
    logic         sel_changed;

    // Reset gives 00, the switch synchronizers' reset value. If the switches are not at 00,
    // their synchronized value changes after reset and the Goal view shows it, as in the model.
    always_ff @(posedge clk) begin
        if (rst)
            last_sel <= 2'b00;
        else
            last_sel <= goal_sel;
    end
    assign sel_changed = (goal_sel != last_sel);

    // Priority: reset or a new Match, then a switch change while waiting, then the timer.
    always_ff @(posedge clk) begin
        if (rst || new_match) begin
            view  <= VIEW_POINTS;
            timer <= '0;
        end
        else if (waiting && sel_changed) begin
            view  <= VIEW_GOAL;
            timer <= '0;
        end
        else if (timer == LAST) begin
            timer <= '0;
            case (view)
                VIEW_POINTS: view <= VIEW_LIVES;
                VIEW_LIVES:  view <= waiting ? VIEW_GOAL : VIEW_POINTS;
                default:     view <= VIEW_POINTS;   // after Goal
            endcase
        end
        else begin
            timer <= timer + 1'b1;
        end
    end

endmodule
