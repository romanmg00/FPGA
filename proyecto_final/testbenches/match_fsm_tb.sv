// Author: Alan (AIF31).
// Self-checking bench for match_fsm: one expected state trace (state code after each tick) per
// rule, driving start_btn, start_p2, crash, crash_done, match_over and pause directly. The outputs are checked against the state on every
// tick and after every input change, and the 1-tick actions are counted.
module match_fsm_tb;

    logic clk = 1'b0, rst = 1'b1;
    logic start_btn = 1'b0, start_p2 = 1'b0, crash = 1'b0, crash_done = 1'b0, match_over = 1'b0, pause = 1'b0;
    logic waiting, new_match, restart, round_start;
    int   new_count = 0, round_start_count = 0;     // ticks with new_match / round_start high at the edge

    match_fsm dut (
        .clk, .rst, .start_btn, .start_p2, .crash, .crash_done, .match_over, .pause,
        .waiting, .new_match, .restart, .round_start
    );

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "match_fsm_tb failed");
    endfunction

    // Outputs the plan gives each state (section 4.1), written here from that table.
    task automatic check_outputs(string when);
        logic w, n, g;
        w = (dut.state == 3'd0 || dut.state == 3'd4);
        n = (dut.state == 3'd5) && !pause;
        g = (dut.state == 3'd7) && !pause;
        if (waiting !== w || new_match !== n || restart !== n || round_start !== g)
            fail($sformatf("%s: state %0d pause=%b gives waiting=%b new_match=%b restart=%b round_start=%b",
                           when, dut.state, pause, waiting, new_match, restart, round_start));
    endtask

    // The state after every edge, as one digit per tick. Actions are counted at the edge.
    string log = "";
    always @(posedge clk) begin
        if (new_match === 1'b1) new_count++;
        if (round_start === 1'b1) round_start_count++;
        #1;
        log = $sformatf("%s%0d", log, dut.state);
        check_outputs("after an edge");
    end
    always @(negedge clk) begin
        #1;
        check_outputs("after an input change");
    end

    // n more edges; returns 2 ns after the last one, so inputs can change right after.
    task automatic ticks(int n);
        repeat (n) @(posedge clk);
        #2;
    endtask

    // One reset edge with Start at s_in, then release. The log restarts with that edge's state.
    task automatic start(logic s_in);
        @(negedge clk);
        rst = 1'b1;
        start_btn = s_in; start_p2 = 1'b0; crash = 1'b0; crash_done = 1'b0; match_over = 1'b0; pause = 1'b0;
        @(posedge clk);
        #2;
        log = "";
        new_count = 0;
        round_start_count = 0;
        log = $sformatf("%0d", dut.state);
        @(negedge clk);
        rst = 1'b0;
    endtask

    task automatic check(string rule, string expected, int news = -1, int round_starts = -1);
        if (log != expected)
            fail($sformatf("%s: states %s, expected %s", rule, log, expected));
        if (news >= 0 && new_count != news)
            fail($sformatf("%s: new_match high on %0d ticks, expected %0d", rule, new_count, news));
        if (round_starts >= 0 && round_start_count != round_starts)
            fail($sformatf("%s: round_start high on %0d ticks, expected %0d", rule, round_start_count, round_starts));
        $display("ok   %s: %s", rule, log);
    endtask

    // A 1-tick pulse on one input.
    task automatic pulse_crash();
        crash = 1'b1; ticks(1); crash = 1'b0;
    endtask
    task automatic pulse_crash_done();
        crash_done = 1'b1; ticks(1); crash_done = 1'b0;
    endtask
    // A press: Start goes high for one tick, then low.
    task automatic press();
        start_btn = 1'b1; ticks(1); start_btn = 1'b0;
    endtask

    // From reset, drives the inputs until the state is target (0-7). Ends between edges.
    task automatic go_to(int target);
        start(1'b0);
        ticks(1);
        if (target == 0) return;
        press();                                    // -> 5
        if (target == 5) return;
        ticks(1);                                   // -> 6
        if (target == 6) return;
        ticks(1);                                   // -> 7
        if (target == 7) return;
        ticks(1);                                   // -> 1
        if (target == 1) return;
        pulse_crash();                                  // -> 2
        if (target == 2) return;
        match_over = (target == 4);
        pulse_crash_done();                                  // -> 3 or 4
    endtask

    initial begin
        // Power-up waits; one press starts the Match (5 6 7 1) with one new_match and one
        // round_start, and a held button does not start it again. A Crash, 2 s, the next Round.
        start(1'b0);
        ticks(2);
        start_btn = 1'b1;
        ticks(5);
        check("first Match, Start held", "00056711", 1, 1);
        start_btn = 1'b0;
        pulse_crash();
        ticks(3);
        pulse_crash_done();
        ticks(2);
        press();
        ticks(2);
        check("Crash, display, next Round", "000567112222333711", 1, 2);

        // A button held through a reset is not a press: release, then press.
        start(1'b1);
        ticks(3);
        start_btn = 1'b0;
        ticks(2);
        press();
        ticks(1);
        check("Start held through reset", "00000056", 1, 0);

        // Start during the Crash display is ignored, also if still held when it ends.
        go_to(1);
        log = ""; new_count = 0; round_start_count = 0;
        pulse_crash();
        start_btn = 1'b1;
        ticks(3);
        pulse_crash_done();
        ticks(3);
        start_btn = 1'b0;
        ticks(1);
        press();
        ticks(1);
        check("Start during the Crash display", "22223333371", 0, 1);

        // A Match-ending Crash still shows the display, then waits for a new Match; Start in
        // the display does not count; afterwards one press starts a new Match from 5.
        go_to(1);
        log = ""; new_count = 0; round_start_count = 0;
        pulse_crash();
        match_over = 1'b1;
        press();
        ticks(2);
        start_btn = 1'b1;
        pulse_crash_done();
        ticks(2);
        start_btn = 1'b0;
        match_over = 1'b0;                                   // score_unit clears it with new_match
        ticks(1);
        press();
        ticks(4);
        check("Match over, then a new Match", "2222444456711", 1, 1);

        // No timeout ends a Round.
        go_to(1);
        log = "";
        ticks(1000);
        for (int i = 0; i < 1000; i++)
            if (log[i] != "1") fail("no timeout: the Round left G_PLAY without a Crash");
        $display("ok   no timeout: 1000 ticks in G_PLAY");

        // Pause in each state: the state holds, the 1-tick actions wait, a press made during
        // Pause does not count afterwards.
        go_to(0);
        log = "";
        pause = 1'b1;
        press();
        start_btn = 1'b1;
        ticks(2);
        pause = 1'b0;
        ticks(2);
        start_btn = 1'b0;
        ticks(1);
        press();
        check("Pause in G_IDLE", "0000005");

        go_to(5);
        log = ""; new_count = 0;
        pause = 1'b1;
        ticks(3);
        if (new_count != 0) fail("Pause in G_NEW: new_match while paused");
        pause = 1'b0;
        ticks(2);
        check("Pause in G_NEW", "55567", 1);

        go_to(6);
        log = "";
        pause = 1'b1;
        ticks(3);
        pause = 1'b0;
        ticks(2);
        check("Pause in G_GO", "66671");

        go_to(7);
        log = ""; round_start_count = 0;
        pause = 1'b1;
        ticks(3);
        if (round_start_count != 0) fail("Pause in G_START: round_start while paused");
        pause = 1'b0;
        ticks(2);
        check("Pause in G_START", "77711", -1, 1);

        go_to(1);
        log = "";
        pause = 1'b1;
        pulse_crash();
        ticks(2);
        pause = 1'b0;
        ticks(2);
        check("Pause in G_PLAY", "11111");

        go_to(2);
        log = "";
        pause = 1'b1;
        pulse_crash_done();
        ticks(2);
        pause = 1'b0;
        ticks(1);
        pulse_crash_done();
        ticks(1);
        check("Pause in G_CRASH", "222233");

        go_to(3);
        log = ""; round_start_count = 0;
        pause = 1'b1;
        press();
        start_btn = 1'b1;
        ticks(2);
        pause = 1'b0;
        ticks(2);
        start_btn = 1'b0;
        ticks(1);
        press();
        ticks(1);
        check("Pause in G_READY", "33333371", -1, 1);

        go_to(4);
        log = ""; new_count = 0;
        pause = 1'b1;
        press();
        start_btn = 1'b1;
        ticks(2);
        pause = 1'b0;
        match_over = 1'b0;
        ticks(2);
        start_btn = 1'b0;
        ticks(1);
        press();
        check("Pause in G_MATCH", "4444445", 0);

        // A Start from the web page (start_p2, 2 ticks from uart_link) has its own edge: with BTNC
        // held through a reset it still starts the Match, once; during the Round it does nothing.
        start(1'b1);
        ticks(2);
        start_p2 = 1'b1;
        ticks(2);
        start_p2 = 1'b0;
        ticks(3);
        start_p2 = 1'b1;
        ticks(2);
        start_p2 = 1'b0;
        ticks(1);
        check("page Start with BTNC held", "00056711111", 1, 1);

        // A reset from every state returns to G_IDLE and clears the actions.
        for (int target = 0; target < 8; target++) begin
            go_to(target);
            if (dut.state !== 3'(target)) fail($sformatf("go_to(%0d) reached state %0d", target, dut.state));
            @(negedge clk);
            rst = 1'b1;
            @(posedge clk);
            #1;
            if (dut.state !== 3'd0) fail($sformatf("reset in state %0d gave state %0d", target, dut.state));
            rst = 1'b0;
            match_over = 1'b0;
        end
        $display("ok   reset from each of the 8 states returns to G_IDLE");

        $display("PASS match_fsm_tb");
        $finish;
    end

endmodule
