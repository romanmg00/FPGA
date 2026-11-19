// Author: Alan (AIF31).
// Scoreboard view on clk_juego: 0 Points, 1 Lives, 2 Goal, 180 ticks (3 s) each. Goal joins
// only while waiting for a new Match, where a {SW15, SW14} change jumps to it; a new Match
// starts on Points.
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
