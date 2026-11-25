// Author: Alan (AIF31).
// The Match, a Moore FSM on clk_juego: starts each Round and each new Match, and ends the Match.
module match_fsm (
    input  logic clk,             // clk_juego
    input  logic rst,
    input  logic start_btn,       // BTNC
    input  logic start_p2,        // Space or Enter from P2's page
    input  logic crash,
    input  logic crash_done,      // Crash pause is over
    input  logic match_over,      // Goal reached or no Lives left
    input  logic pause,           // SW0
    input  logic codes_valid,     // the Prepare is answered
    output logic waiting,
    output logic new_match,
    output logic restart,
    output logic round_start
);

    // s_new and s_go last 1 tick; s_start waits until the Prepare has placed the Rewards.
    typedef enum logic [2:0] {s_idle, s_play, s_crash, s_ready, s_match, s_new, s_go, s_start} state_t;
    state_t state, next_state;
    logic   start_btn_last, start_p2_last, start_press;

    // One rising edge per Start source.
    always_ff @(posedge clk) begin
        if (rst) begin
            start_btn_last <= 1'b1;
            start_p2_last  <= 1'b1;
        end else begin
            start_btn_last <= start_btn;
            start_p2_last  <= start_p2;
        end
    end
    assign start_press = (start_btn && !start_btn_last) || (start_p2 && !start_p2_last);

    always_ff @(posedge clk) begin
        if (rst)         state <= s_idle;
        else if (!pause) state <= next_state;      // Pause holds the state
    end

    always_comb begin
        next_state = state;
        case (state)
            s_idle:  next_state = start_press ? s_new : s_idle;        // first Match 
            s_play:  next_state = crash ? s_crash : (match_over ? s_match : s_play);  // a Crash ends the Round; the Goal, the Match
            s_crash: next_state = !crash_done ? s_crash : (match_over ? s_match : s_ready);  // Match over or next Round
            s_ready: next_state = start_press ? s_start : s_ready;     // next Round 
            s_match: next_state = start_press ? s_new : s_match;       // new Match 
            s_new:   next_state = s_go;                                // new_match, restart
            s_go:    next_state = s_start;                             // Start low, so round_fsm leaves s_release
            s_start: next_state = codes_valid ? s_play : s_start;      // round_start once prepared
            default: next_state = s_idle;                              // not reached: all 8 codes are states
        endcase
    end

    // The 1-tick actions wait during Pause.
    assign waiting     = (state == s_idle || state == s_match);   // seg7_view adds the Goal view
    assign new_match   = (state == s_new) && !pause;              // score_unit: 0 Points, 3 Lives
    assign restart     = (state == s_new) && !pause;              // position_logic: Bikes to their starts
    assign round_start = (state == s_start) && !pause && codes_valid;   // Start for round

endmodule
