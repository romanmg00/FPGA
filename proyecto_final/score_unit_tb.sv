// Self-checking bench for score_unit: Points, Lives and the result after each Crash Step,
// written from the agreed specification (Match and scoring; Survival Bonus) and ADR 0011.
// Without Rewards both Players losing their last Life in one Step always have equal Points,
// so the "more Points wins" case is reached by setting the Points with force.
module score_unit_tb;

    logic       clk = 1'b0, rst = 1'b1, new_match = 1'b0, crash1 = 1'b0, crash2 = 1'b0;
    logic [5:0] points_p1, points_p2;
    logic [1:0] lives_p1, lives_p2, result;
    logic       match_over;

    score_unit dut (
        .clk, .rst, .new_match, .crash1, .crash2,
        .points_p1, .points_p2, .lives_p1, .lives_p2, .result, .match_over
    );

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "score_unit_tb failed");
    endfunction

    // One tick with these inputs; returns after the edge, with the new values.
    task automatic tick(logic r, logic n, logic c1, logic c2);
        @(negedge clk);
        rst = r; new_match = n; crash1 = c1; crash2 = c2;
        @(posedge clk);
        #1;
        rst = 1'b0; new_match = 1'b0; crash1 = 1'b0; crash2 = 1'b0;
    endtask

    // Expected values: Points P1, P2, Lives P1, P2, result (0 on, 1 P1, 2 P2, 3 Draw).
    task automatic expect_values(string what, int pt1, int pt2, int lv1, int lv2, int res);
        if (points_p1 !== 6'(pt1) || points_p2 !== 6'(pt2) || lives_p1 !== 2'(lv1)
            || lives_p2 !== 2'(lv2) || result !== 2'(res) || match_over !== (res != 0))
            fail($sformatf("%s: Points %0d-%0d Lives %0d-%0d result %0d over %b; expected %0d-%0d %0d-%0d %0d",
                           what, points_p1, points_p2, lives_p1, lives_p2, result, match_over,
                           pt1, pt2, lv1, lv2, res));
        $display("ok   %s: Points %0d-%0d, Lives %0d-%0d, result %0d", what, pt1, pt2, lv1, lv2, res);
    endtask

    initial begin
        tick(1, 0, 0, 0);
        expect_values("reset: a Match starts with 0 Points and 3 Lives", 0, 0, 3, 3, 0);
        tick(0, 0, 0, 0);
        expect_values("a tick without a Crash changes nothing", 0, 0, 3, 3, 0);

        // Each kind of Crash Step, and the values carry from Round to Round.
        tick(0, 0, 1, 0);
        expect_values("P1 crashes alone: P1 -1 Life, P2 +3", 0, 3, 2, 3, 0);
        tick(0, 0, 0, 1);
        expect_values("P2 crashes alone: P2 -1 Life, P1 +3", 3, 3, 2, 2, 0);
        tick(0, 0, 1, 1);
        expect_values("both crash: both -1 Life, no bonus", 3, 3, 1, 1, 0);
        tick(0, 0, 1, 1);
        expect_values("both lose their last Life with the same Points: Draw", 3, 3, 0, 0, 3);
        tick(0, 0, 1, 0);
        tick(0, 0, 0, 1);
        expect_values("after the result nothing changes", 3, 3, 0, 0, 3);
        tick(0, 1, 0, 0);
        expect_values("new_match: 0 Points, 3 Lives, no result", 0, 0, 3, 3, 0);

        // P1 loses all Lives. The +3 of the last Step counts before the result: P2 ends on 9,
        // the most a Player can score without Rewards.
        tick(0, 0, 1, 0);
        tick(0, 0, 1, 0);
        expect_values("P1 on its last Life", 0, 6, 1, 3, 0);
        tick(0, 0, 1, 0);
        expect_values("P1 out: P2 wins, the last bonus counted", 0, 9, 0, 3, 2);
        tick(0, 1, 0, 0);
        tick(0, 0, 0, 1);
        tick(0, 0, 0, 1);
        tick(0, 0, 0, 1);
        expect_values("P2 out: P1 wins", 9, 0, 3, 0, 1);

        // One Player out while the other also crashes in the same Step: the other still has a
        // Life, so it wins, and neither gets the bonus.
        tick(0, 1, 0, 0);
        tick(0, 0, 1, 0);
        tick(0, 0, 1, 0);
        tick(0, 0, 1, 1);
        expect_values("P1 out in a Head-on Crash, P2 left with 2 Lives: P2 wins", 0, 6, 0, 2, 2);

        // Both out in one Step with different Points (needs Rewards; set with force here).
        tick(0, 1, 0, 0);
        tick(0, 0, 1, 1);
        tick(0, 0, 1, 1);
        force dut.points_p1 = 6'd7;
        force dut.points_p2 = 6'd4;
        tick(0, 0, 1, 1);
        release dut.points_p1;
        release dut.points_p2;
        expect_values("both out, P1 has more Points: P1 wins", 7, 4, 0, 0, 1);
        tick(0, 1, 0, 0);
        tick(0, 0, 1, 1);
        tick(0, 0, 1, 1);
        force dut.points_p1 = 6'd4;
        force dut.points_p2 = 6'd7;
        tick(0, 0, 1, 1);
        release dut.points_p1;
        release dut.points_p2;
        expect_values("both out, P2 has more Points: P2 wins", 4, 7, 0, 0, 2);

        // Reset and new_match win over a Crash on the same tick; reset in the middle of a Match.
        tick(0, 1, 1, 0);
        expect_values("new_match and a Crash on the same tick", 0, 0, 3, 3, 0);
        tick(0, 0, 0, 1);
        tick(1, 0, 1, 1);
        expect_values("reset and a Crash on the same tick", 0, 0, 3, 3, 0);

        $display("PASS score_unit_tb");
        $finish;
    end

endmodule
