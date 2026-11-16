// Self-checking bench for seg7_view: one expected view trace (P, L, G per tick) for each
// Scoreboard rule, with VIEW_TICKS = 4 and the default 180.
module seg7_view_tb;
    localparam int FAST_TICKS = 4;

    logic       clk = 1'b0, rst = 1'b1, new_match = 1'b0, waiting = 1'b1;
    logic [1:0] goal_sel = 2'b00;
    logic [1:0] fast_view, real_view;

    seg7_view #(.VIEW_TICKS(FAST_TICKS)) dut_fast (
        .clk, .rst, .new_match, .waiting, .goal_sel, .view(fast_view)
    );
    seg7_view dut_real (
        .clk, .rst, .new_match, .waiting, .goal_sel, .view(real_view)
    );

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "seg7_view_tb failed");
    endfunction

    function automatic byte letter(logic [1:0] view);
        case (view)
            2'd0:    return "P";
            2'd1:    return "L";
            2'd2:    return "G";
            default: return "?";
        endcase
    endfunction

    function automatic string rep(byte c, int n);
        string s = "";
        for (int i = 0; i < n; i++) s = $sformatf("%s%c", s, c);
        return s;
    endfunction

    // The view after every clock edge (one clk_juego tick). Inputs change between edges.
    string fast_log = "", real_log = "";
    always begin
        @(posedge clk);
        #1;
        fast_log = $sformatf("%s%c", fast_log, letter(fast_view));
        real_log = $sformatf("%s%c", real_log, letter(real_view));
    end

    // n more edges; returns between edges, so inputs can change right after.
    task automatic ticks(int n);
        repeat (n) @(posedge clk);
        #2;
    endtask

    // A reset edge with these inputs, then release. The logs restart with that edge's "P",
    // the first tick of a full Points view.
    task automatic start(bit wait_in, logic [1:0] sel);
        @(negedge clk);
        rst = 1'b1;
        new_match = 1'b0;
        waiting = wait_in;
        goal_sel = sel;
        fast_log = "";
        real_log = "";
        @(negedge clk);
        rst = 1'b0;
    endtask

    task automatic check(string rule, string expected);
        if (fast_log != expected)
            fail($sformatf("%s: views %s, expected %s", rule, fast_log, expected));
    endtask

    task automatic check_real(string rule, string expected);
        if (real_log != expected)
            fail($sformatf("%s: %0d views logged, not the expected sequence (first difference near tick %0d)",
                           rule, real_log.len(), first_difference(real_log, expected)));
    endtask

    function automatic int first_difference(string a, string b);
        for (int i = 0; i < a.len() && i < b.len(); i++)
            if (a[i] != b[i]) return i;
        return (a.len() < b.len()) ? a.len() : b.len();
    endfunction

    initial begin
        // While waiting for a new Match, Points -> Lives -> Goal -> Points, a full view each.
        start(1'b1, 2'b00);
        ticks(15);
        check("waiting", "PPPPLLLLGGGGPPPP");

        // During a Match only Points and Lives alternate, and the switches do nothing.
        start(1'b0, 2'b00);
        ticks(5);
        goal_sel = 2'b10;
        ticks(5);
        goal_sel = 2'b01;
        ticks(5);
        check("during a Match", "PPPPLLLLPPPPLLLL");

        // A switch change while waiting jumps to Goal and restarts its time: from Points,
        // from Lives, during Goal, and on two ticks in a row.
        start(1'b1, 2'b00);
        ticks(1);
        goal_sel = 2'b01;
        ticks(5);
        check("jump from Points", "PPGGGGP");

        start(1'b1, 2'b00);
        ticks(5);
        goal_sel = 2'b10;
        ticks(5);
        check("jump from Lives", "PPPPLLGGGGP");

        start(1'b1, 2'b00);
        ticks(9);
        goal_sel = 2'b11;
        ticks(5);
        check("jump during Goal", "PPPPLLLLGGGGGGP");

        start(1'b1, 2'b00);
        ticks(1);
        goal_sel = 2'b01;
        ticks(1);
        goal_sel = 2'b10;
        ticks(5);
        check("two changes in a row", "PPGGGGGP");

        // A new Match starts on Points with a full view, even from Goal and even if the
        // switches change on the same tick. Then the Match runs: no Goal view.
        start(1'b1, 2'b00);
        ticks(9);
        new_match = 1'b1;
        goal_sel = 2'b01;
        ticks(1);
        new_match = 1'b0;
        waiting = 1'b0;
        ticks(8);
        check("new Match", "PPPPLLLLGGPPPPLLLLP");

        // Match-over: once waiting, Lives finishes its time and the Goal view follows.
        start(1'b0, 2'b00);
        ticks(5);
        waiting = 1'b1;
        ticks(10);
        check("Match-over", "PPPPLLLLGGGGPPPP");

        // Reset with the switches away from 00: their synchronized value leaves the reset
        // value 00, which shows the Goal view, as in the model. Held still, they jump no more.
        start(1'b1, 2'b11);
        ticks(12);
        check("reset with goal 40", "PGGGGPPPPLLLL");

        // Reset in the middle of a view returns to a full Points view.
        start(1'b1, 2'b00);
        ticks(10);
        start(1'b1, 2'b00);
        ticks(4);
        check("reset mid-view", "PPPPL");

        // The default VIEW_TICKS: 180 ticks per view, about 3 s at 59.99997 Hz.
        start(1'b1, 2'b00);
        ticks(4 * 180 - 1);
        check_real("180 ticks, waiting", {rep("P", 180), rep("L", 180), rep("G", 180), rep("P", 180)});
        start(1'b0, 2'b00);
        ticks(3 * 180 - 1);
        check_real("180 ticks, in a Match", {rep("P", 180), rep("L", 180), rep("P", 180)});

        $display("PASS seg7_view_tb");
        $finish;
    end

    initial begin
        #1ms;
        fail("timeout");
    end

endmodule
