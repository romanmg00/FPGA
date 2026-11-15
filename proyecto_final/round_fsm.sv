// Round control (Moore FSM). Inputs: s = Start button, c = crash, t = crash pause over.
// Outputs: load = keep the bikes at their start cells, run = the bikes move.
// s_release waits for Start to be released, so a held button cannot start a new round.
module round_fsm (
    input  logic       clk, rst, s, c, t,
    output logic       load, run
);

    typedef enum logic [1:0] {s_wait, s_run, s_crash, s_release} state_t; // state names
    state_t nst, st;

    always_ff @(posedge clk) begin
        if(rst)
            st <= s_release;
        else
            st <= nst;
    end

    always_comb begin
        nst = st;
        case(st)
            s_wait: nst = (s)? s_run: s_wait;
            s_run:  nst = (c)? s_crash: s_run;
            s_crash: nst = (t)? s_release: s_crash;
            s_release: nst = (!s)? s_wait: s_release;
            default: nst = s_release;
        endcase
    end

    assign run = (st == s_run);
    assign load = (st == s_wait || st == s_release);

endmodule
