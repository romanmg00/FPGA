// Which view the Scoreboard shows, on clk_juego (spec, Physical Scoreboard; ADR 0008).
// Points and Lives alternate, VIEW_TICKS ticks each (180, about 3 s). While waiting for a new
// Match (before the first one, and at Match-over), the Goal view joins them:
// Points -> Lives -> Goal -> Points. A change of {SW15, SW14} while waiting jumps to the Goal
// view and restarts its time, so the switches show their effect at once. A new Match starts
// on Points. Views: 0 Points, 1 Lives, 2 Goal (seg7_driver uses the same numbers).
module seg7_view #(parameter int VIEW_TICKS = 180) (   // 180 ticks at 59.99997 Hz = 3.0 s
    input  logic       clk,         // clk_juego
    input  logic       rst,
    input  logic       new_match,   // 1 on the tick a Start begins a new Match
    input  logic       waiting,     // waiting for a new Match, where Start takes the goal
    input  logic [1:0] goal_sel,    // synchronized {SW15, SW14}
    output logic [1:0] view         // 0 Points, 1 Lives, 2 Goal
);

    logic [7:0] timer;      // counts 0 to VIEW_TICKS-1 (8 bits hold up to 255)
    logic [1:0] last_sel;   // goal_sel one tick earlier
    logic       sel_changed;

    // Reset gives 00, the switch synchronizers' reset value
    always_ff @(posedge clk)
    begin
        if (rst)
            last_sel <= 2'b00;
        else
            last_sel <= goal_sel;
    end
    assign sel_changed = (goal_sel != last_sel);

    // Priority: reset or a new Match, then a switch change while waiting, then the timer.
    always_ff @(posedge clk)
    begin
        if (rst || new_match)
        begin
            view  <= 2'd0;          // Points
            timer <= 8'd0;
        end
        else if (waiting && sel_changed)
        begin
            view  <= 2'd2;          // Goal
            timer <= 8'd0;
        end
        else if (timer == VIEW_TICKS - 1)
        begin
            timer <= 8'd0;
            case (view)
                2'd0:    view <= 2'd1;                    // Points -> Lives
                2'd1:    view <= waiting ? 2'd2 : 2'd0;   // Lives -> Goal while waiting, else Points
                default: view <= 2'd0;                    // Goal -> Points
            endcase
        end
        else
            timer <= timer + 1'b1;
    end

endmodule
