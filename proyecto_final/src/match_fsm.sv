// Author: Alan (AIF31).
// Match control (G3), a Moore FSM on clk_juego: a 1-tick round_start for Roman's round_fsm
// (btn[4] of position_logic), a restart for each new Match, and after the 2 s Crash display the
// next Round or the end of the Match.
module match_fsm (
    input  logic clk,             // clk_juego (~60 Hz)
    input  logic rst,             // rst_juego
    input  logic start_btn,       // BTNC after sync_2ff; that synchronizer is never reset
    input  logic crash,           // crash1 || crash2 from position_logic, on the Step tick
    input  logic crash_done,      // from position_logic: the 2 s Crash display is over
    input  logic match_over,      // from score_unit: a Player has no Lives left
    input  logic pause,           // SW0 after sync_2ff
    output logic waiting,         // waiting for a new Match: seg7_view adds the Goal view
    output logic new_match,       // 1 tick: score_unit starts a new Match, seg7_view shows Points
    output logic restart,         // 1 tick: resets position_logic (Bikes to their starts)
    output logic round_start      // 1 tick: Start for round_fsm (btn[4] of position_logic)
);

    // States, 3 bits. 0-4 are the G_* codes of contract section 4.
    //   0 G_IDLE   waiting for the first Match (after power-up or CPU_RESETN)
    //   1 G_PLAY   the Round runs
    //   2 G_CRASH  2 s Crash display, timed by round_fsm's Crash timer
    //   3 G_READY  waiting for Start of the next Round
    //   4 G_MATCH  the Match is over; final Points and Lives stay
    //   5 G_NEW    new Match (1 tick): new_match and restart
    //   6 G_GO     round_fsm leaves s_release, Start low (1 tick)
    //   7 G_START  Start pulse for round_fsm (1 tick)
    logic [2:0] state, next_state;
    logic       start_btn_last;   // start_btn one tick earlier
    logic       start_press;      // Start was pressed: start_btn rose this tick

    // A press is a rising edge, so a held button starts nothing. start_btn_last resets to 1: a
    // button held through a reset counts as held and must be released first. start_btn_last also
    // follows start_btn during Pause, so a press made while paused does not count afterwards.
    always_ff @(posedge clk)
    begin
        if (rst)
            start_btn_last <= 1'b1;
        else
            start_btn_last <= start_btn;
    end
    assign start_press = start_btn && !start_btn_last;

    // State register. Pause holds the state.
    always_ff @(posedge clk)
    begin
        if (rst)
            state <= 3'd0;                      // G_IDLE
        else if (!pause)
            state <= next_state;
    end

    // Next state
    always_comb
    begin
        next_state = state;
        case (state)
            3'd0: if (start_press) next_state = 3'd5;   // G_IDLE: a press starts a new Match
            3'd1: if (crash) next_state = 3'd2;         // G_PLAY: a Crash ends the Round
            3'd2: begin                                 // G_CRASH: after the 2 s display
                if (crash_done && match_over)
                    next_state = 3'd4;                  // the Match is over
                else if (crash_done)
                    next_state = 3'd3;                  // or the next Round waits for Start
            end
            3'd3: if (start_press) next_state = 3'd7;   // G_READY: a press starts the Round
            3'd4: if (start_press) next_state = 3'd5;   // G_MATCH: a press starts a new Match
            3'd5: next_state = 3'd6;                    // G_NEW -> G_GO
            3'd6: next_state = 3'd7;                    // G_GO -> G_START
            3'd7: next_state = 3'd1;                    // G_START -> G_PLAY
            default: next_state = 3'd0;
        endcase
    end

    // Outputs. The three 1-tick actions wait while paused, so a state held by Pause does nothing.
    assign waiting     = (state == 3'd0 || state == 3'd4);  // G_IDLE, G_MATCH
    assign new_match   = (state == 3'd5) && !pause;         // G_NEW
    assign restart     = (state == 3'd5) && !pause;         // G_NEW
    assign round_start = (state == 3'd7) && !pause;         // G_START

endmodule
