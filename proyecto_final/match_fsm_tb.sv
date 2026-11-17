// Self-checking bench for match_fsm: one expected state trace (state code after each tick) per
// rule, driving s, c, t, m and p directly. The outputs are checked against the state on every
// tick and after every input change, and the 1-tick actions are counted.
module match_fsm_tb;

    logic clk = 1'b0, rst = 1'b1;
    logic s = 1'b0, c = 1'b0, t = 1'b0, m = 1'b0, p = 1'b0;
    logic waiting, new_match, restart, start_go;
    int   new_count = 0, go_count = 0;     // ticks with new_match / start_go high at the edge

    match_fsm dut (
        .clk, .rst, .s, .c, .t, .m, .p,
        .waiting, .new_match, .restart, .start_go
    );

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "match_fsm_tb failed");
    endfunction

    // Outputs the plan gives each state (section 4.1), written here from that table.
    task automatic check_outputs(string when);
        logic w, n, g;
        w = (dut.st == 3'd0 || dut.st == 3'd4);
        n = (dut.st == 3'd5) && !p;
        g = (dut.st == 3'd7) && !p;
        if (waiting !== w || new_match !== n || restart !== n || start_go !== g)
            fail($sformatf("%s: state %0d p=%b gives waiting=%b new_match=%b restart=%b start_go=%b",
                           when, dut.st, p, waiting, new_match, restart, start_go));
    endtask

    // The state after every edge, as one digit per tick. Actions are counted at the edge.
    string log = "";
    always @(posedge clk) begin
        if (new_match === 1'b1) new_count++;
        if (start_go === 1'b1) go_count++;
        #1;
        log = $sformatf("%s%0d", log, dut.st);
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
        s = s_in; c = 1'b0; t = 1'b0; m = 1'b0; p = 1'b0;
        @(posedge clk);
        #2;
        log = "";
        new_count = 0;
        go_count = 0;
        log = $sformatf("%0d", dut.st);
        @(negedge clk);
        rst = 1'b0;
    endtask

    task automatic check(string rule, string expected, int news = -1, int gos = -1);
        if (log != expected)
            fail($sformatf("%s: states %s, expected %s", rule, log, expected));
        if (news >= 0 && new_count != news)
            fail($sformatf("%s: new_match high on %0d ticks, expected %0d", rule, new_count, news));
        if (gos >= 0 && go_count != gos)
            fail($sformatf("%s: start_go high on %0d ticks, expected %0d", rule, go_count, gos));
        $display("ok   %s: %s", rule, log);
    endtask

    // A 1-tick pulse on one input.
    task automatic pulse_c();
        c = 1'b1; ticks(1); c = 1'b0;
    endtask
    task automatic pulse_t();
        t = 1'b1; ticks(1); t = 1'b0;
    endtask
    // A press: Start goes high for one tick, then low.
    task automatic press();
        s = 1'b1; ticks(1); s = 1'b0;
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
        pulse_c();                                  // -> 2
        if (target == 2) return;
        m = (target == 4);
        pulse_t();                                  // -> 3 or 4
    endtask

    initial begin
        // Power-up waits; one press starts the Match (5 6 7 1) with one new_match and one
        // start_go, and a held button does not start it again. A Crash, 2 s, the next Round.
        start(1'b0);
        ticks(2);
        s = 1'b1;
        ticks(5);
        check("first Match, Start held", "00056711", 1, 1);
        s = 1'b0;
        pulse_c();
        ticks(3);
        pulse_t();
        ticks(2);
        press();
        ticks(2);
        check("Crash, display, next Round", "000567112222333711", 1, 2);

        // A button held through a reset is not a press: release, then press.
        start(1'b1);
        ticks(3);
        s = 1'b0;
        ticks(2);
        press();
        ticks(1);
        check("Start held through reset", "00000056", 1, 0);

        // Start during the Crash display is ignored, also if still held when it ends.
        go_to(1);
        log = ""; new_count = 0; go_count = 0;
        pulse_c();
        s = 1'b1;
        ticks(3);
        pulse_t();
        ticks(3);
        s = 1'b0;
        ticks(1);
        press();
        ticks(1);
        check("Start during the Crash display", "22223333371", 0, 1);

        // A Match-ending Crash still shows the display, then waits for a new Match; Start in
        // the display does not count; afterwards one press starts a new Match from 5.
        go_to(1);
        log = ""; new_count = 0; go_count = 0;
        pulse_c();
        m = 1'b1;
        press();
        ticks(2);
        s = 1'b1;
        pulse_t();
        ticks(2);
        s = 1'b0;
        m = 1'b0;                                   // score_unit clears it with new_match
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
        p = 1'b1;
        press();
        s = 1'b1;
        ticks(2);
        p = 1'b0;
        ticks(2);
        s = 1'b0;
        ticks(1);
        press();
        check("Pause in G_IDLE", "0000005");

        go_to(5);
        log = ""; new_count = 0;
        p = 1'b1;
        ticks(3);
        if (new_count != 0) fail("Pause in G_NEW: new_match while paused");
        p = 1'b0;
        ticks(2);
        check("Pause in G_NEW", "55567", 1);

        go_to(6);
        log = "";
        p = 1'b1;
        ticks(3);
        p = 1'b0;
        ticks(2);
        check("Pause in G_GO", "66671");

        go_to(7);
        log = ""; go_count = 0;
        p = 1'b1;
        ticks(3);
        if (go_count != 0) fail("Pause in G_START: start_go while paused");
        p = 1'b0;
        ticks(2);
        check("Pause in G_START", "77711", -1, 1);

        go_to(1);
        log = "";
        p = 1'b1;
        pulse_c();
        ticks(2);
        p = 1'b0;
        ticks(2);
        check("Pause in G_PLAY", "11111");

        go_to(2);
        log = "";
        p = 1'b1;
        pulse_t();
        ticks(2);
        p = 1'b0;
        ticks(1);
        pulse_t();
        ticks(1);
        check("Pause in G_CRASH", "222233");

        go_to(3);
        log = ""; go_count = 0;
        p = 1'b1;
        press();
        s = 1'b1;
        ticks(2);
        p = 1'b0;
        ticks(2);
        s = 1'b0;
        ticks(1);
        press();
        ticks(1);
        check("Pause in G_READY", "33333371", -1, 1);

        go_to(4);
        log = ""; new_count = 0;
        p = 1'b1;
        press();
        s = 1'b1;
        ticks(2);
        p = 1'b0;
        m = 1'b0;
        ticks(2);
        s = 1'b0;
        ticks(1);
        press();
        check("Pause in G_MATCH", "4444445", 0);

        // A reset from every state returns to G_IDLE and clears the actions.
        for (int target = 0; target < 8; target++) begin
            go_to(target);
            if (dut.st !== 3'(target)) fail($sformatf("go_to(%0d) reached state %0d", target, dut.st));
            @(negedge clk);
            rst = 1'b1;
            @(posedge clk);
            #1;
            if (dut.st !== 3'd0) fail($sformatf("reset in state %0d gave state %0d", target, dut.st));
            rst = 1'b0;
            m = 1'b0;
        end
        $display("ok   reset from each of the 8 states returns to G_IDLE");

        $display("PASS match_fsm_tb");
        $finish;
    end

endmodule
