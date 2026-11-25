// Author: Alan (AIF31).
// Self-checking bench for score_unit: Points, Lives and result after each Crash or Reward Step,
// from the agreed specification and ADR 0011: Rewards +1, +1, +3, the Survival Bonus, the Points
// Goal taken at a new Match, and who wins when both reach it or both lose their last Life.
// Some cases set the Points with force to reach a total quickly.
module score_unit_tb;

    logic       clk = 1'b0, rst = 1'b1, new_match = 1'b0, crash1 = 1'b0, crash2 = 1'b0;
    logic [1:0] goal_sel = 2'd0, reward1 = 2'd0, reward2 = 2'd0;
    logic       waiting = 1'b0;     // high on new_match ticks here: the Goal follows the switches
    logic [5:0] points_p1, points_p2;
    logic [1:0] lives_p1, lives_p2, result;
    logic       match_over;

    score_unit dut (
        .clk, .rst, .new_match, .waiting, .goal_sel, .crash1, .crash2, .reward1, .reward2,
        .points_p1, .points_p2, .lives_p1, .lives_p2, .result, .match_over
    );

    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "score_unit_tb failed");
    endfunction

    // One tick with these inputs; returns after the edge, with the new values. w1 and w2 are
    // the Rewards taken: 0 none, 1 slot 0, 2 slot 1 (both +1), 3 slot 2 (+3).
    task automatic tick(logic r, logic n, logic c1, logic c2, logic [1:0] w1 = 2'd0, logic [1:0] w2 = 2'd0);
        @(negedge clk);
        rst = r; new_match = n; waiting = n; crash1 = c1; crash2 = c2; reward1 = w1; reward2 = w2;
        @(posedge clk);
        #1;
        rst = 1'b0; new_match = 1'b0; waiting = 1'b0; crash1 = 1'b0; crash2 = 1'b0; reward1 = 2'd0; reward2 = 2'd0;
    endtask

    // Sets both Points with force between edges (a quick way to a total near the Goal); the
    // registers keep the values after the release, until the next Step changes them.
    logic [5:0] set_p1, set_p2;
    task automatic set_points(int pt1, int pt2);
        set_p1 = 6'(pt1);
        set_p2 = 6'(pt2);
        force dut.points_p1 = set_p1;
        force dut.points_p2 = set_p2;
        #1;
        release dut.points_p1;
        release dut.points_p2;
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
        tick(0, 0, 0, 0);
        tick(0, 0, 0, 0);
        expect_values("ticks without a Crash keep the earned values", 3, 3, 1, 1, 0);
        tick(0, 0, 1, 1);
        expect_values("both lose their last Life with the same Points: Draw", 3, 3, 0, 0, 3);
        tick(0, 0, 1, 0);
        tick(0, 0, 0, 1);
        expect_values("after the result nothing changes", 3, 3, 0, 0, 3);
        tick(0, 0, 0, 0);
        expect_values("ticks without a Crash keep the final values", 3, 3, 0, 0, 3);
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

        // ---- Rewards (G4). Slots 0 and 1 give +1, slot 2 gives +3, to whoever takes them.
        tick(0, 1, 0, 0);
        tick(0, 0, 0, 0, 2'd1, 2'd0);
        expect_values("P1 takes slot 0: +1", 1, 0, 3, 3, 0);
        tick(0, 0, 0, 0, 2'd2, 2'd3);
        expect_values("P1 slot 1 (+1), P2 slot 2 (+3) in one Step", 2, 3, 3, 3, 0);
        tick(0, 0, 0, 0, 2'd0, 2'd1);
        expect_values("P2 takes slot 0: +1", 2, 4, 3, 3, 0);
        tick(0, 0, 1, 0);
        expect_values("then a Crash: the Survival Bonus adds to the Rewards", 2, 7, 2, 3, 0);

        // ---- Points Goal 10 (both switches down), reached with Rewards and no Crash.
        tick(0, 0, 0, 0, 2'd3, 2'd0);
        tick(0, 0, 0, 0, 2'd3, 2'd0);
        expect_values("P1 on 8, P2 on 7: under the Goal", 8, 7, 2, 3, 0);
        tick(0, 0, 0, 0, 2'd3, 2'd0);
        expect_values("P1 8 + 3 = 11: exceeds Goal 10, wins, total kept", 11, 7, 2, 3, 1);
        tick(0, 0, 0, 0, 2'd3, 2'd3);
        tick(0, 0, 1, 1);
        expect_values("after the Goal nothing changes", 11, 7, 2, 3, 1);

        // Exactly the Goal is enough; the Survival Bonus can reach it too.
        tick(0, 1, 0, 0);
        set_points(9, 7);
        tick(0, 0, 0, 0, 2'd2, 2'd0);
        expect_values("P1 9 + 1 = 10: reaches the Goal", 10, 7, 3, 3, 1);
        tick(0, 1, 0, 0);
        set_points(4, 8);
        tick(0, 0, 1, 0);
        expect_values("P1 crashes, P2 8 + 3 = 11 with the Bonus: P2 wins", 4, 11, 2, 3, 2);

        // Both reach the Goal in one Step: more Points wins, equal is a Draw.
        tick(0, 1, 0, 0);
        set_points(9, 9);
        tick(0, 0, 0, 0, 2'd1, 2'd3);
        expect_values("both reach 10: P1 10, P2 12, P2 wins", 10, 12, 3, 3, 2);
        tick(0, 1, 0, 0);
        set_points(9, 9);
        tick(0, 0, 0, 0, 2'd3, 2'd2);
        expect_values("both reach 10: P1 12, P2 10, P1 wins", 12, 10, 3, 3, 1);
        tick(0, 1, 0, 0);
        set_points(9, 7);
        tick(0, 0, 0, 0, 2'd2, 2'd3);
        expect_values("both reach 10 with 10 each: Draw", 10, 10, 3, 3, 3);

        // The Goal comes before Lives: P1 reaches it in the Step its last Life goes.
        tick(0, 1, 0, 0);
        tick(0, 0, 1, 0);
        tick(0, 0, 1, 0);
        set_points(9, 6);
        tick(0, 0, 1, 1, 2'd1, 2'd0);
        expect_values("P1 out of Lives but on the Goal: the Goal wins", 10, 6, 0, 2, 1);

        // ---- The Goal is taken only at a new Match: {SW15, SW14} = 01 is 20, 10 is 30, 11 is 40.
        goal_sel = 2'd1;
        tick(0, 1, 0, 0);
        goal_sel = 2'd3;                    // moved during the Match: no effect until the next one
        set_points(17, 0);
        tick(0, 0, 0, 0, 2'd3, 2'd0);
        expect_values("Goal 20: 17 + 3 = 20 wins", 20, 0, 3, 3, 1);
        goal_sel = 2'd2;
        tick(0, 1, 0, 0);
        set_points(27, 0);
        tick(0, 0, 0, 0, 2'd3, 2'd0);
        expect_values("Goal 30: 27 + 3 = 30 wins", 30, 0, 3, 3, 1);
        goal_sel = 2'd3;
        tick(0, 1, 0, 0);
        set_points(36, 36);
        tick(0, 0, 0, 0, 2'd3, 2'd1);
        expect_values("Goal 40: 39 and 37 go on", 39, 37, 3, 3, 0);
        // The widest Step: 39 + 3 + 3 = 45 needs 6 bits and does not wrap. (A Crash Step takes
        // no Reward in the game, ADR 0011, so 42 is the real top; this only checks the width.)
        tick(0, 0, 0, 1, 2'd3, 2'd0);
        expect_values("Goal 40: 39 + 3 (Reward) + 3 (Bonus) = 45, kept", 45, 37, 3, 2, 1);
        // Start accepted with 20 (the last waiting tick); the switches move to 40 during the new
        // Match's first ticks (Pause can hold them): the Goal stays 20.
        @(negedge clk);
        goal_sel = 2'd1; waiting = 1'b1;
        @(posedge clk);
        #1;
        waiting = 1'b0; goal_sel = 2'd3;
        tick(0, 0, 0, 0);
        @(negedge clk);
        new_match = 1'b1;
        @(posedge clk);
        #1;
        new_match = 1'b0;
        set_points(17, 0);
        tick(0, 0, 0, 0, 2'd3, 2'd0);
        expect_values("Goal taken at the Start tick (20), switches moved after it", 20, 0, 3, 3, 1);
        goal_sel = 2'd0;
        tick(1, 0, 0, 0);
        set_points(9, 0);
        tick(0, 0, 0, 0, 2'd1, 2'd0);
        expect_values("reset sets Goal 10 until the next Match", 10, 0, 3, 3, 1);

        $display("PASS score_unit_tb");
        $finish;
    end

endmodule
