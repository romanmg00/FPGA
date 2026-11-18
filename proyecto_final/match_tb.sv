// Author: Alan (AIF31).
// Self-checking bench for the Match: match_fsm, score_unit and position_logic (with Roman's
// round_fsm inside) wired as in game_top, on clk_juego alone, one tick per edge, so whole
// Matches take microseconds. The Arena is empty here (codes 0): Bikes crash into the Walls and
// into each other. Every tick checks that match_fsm and round_fsm agree (plan section 4.1) and
// that no Step is taken while codes_valid = 0.
`timescale 1ns/1ps
module match_tb;

    localparam int STEP = 8;                       // STEP_TICKS, as in game_top
    localparam int P1_X0 = 320, P1_Y0 = 432, P2_X0 = 944, P2_Y0 = 432;   // start Cells x16
    localparam logic [3:0] D_NONE = 4'b0000, D_U = 4'b0001;               // board U, D, L, R

    logic        clk = 1'b0, rst = 1'b1;
    logic        start = 1'b0, pause = 1'b0, codes_valid = 1'b1;
    logic [3:0]  dir = D_NONE;                    // P1's direction buttons
    logic        crash1, crash2, crash_done, match_over;
    logic        waiting, new_match, restart, start_go;
    logic [5:0]  points_p1, points_p2;
    logic [1:0]  lives_p1, lives_p2, result;
    logic [10:0] p1x, p1y, p2x, p2y;
    logic [1:0]  h1, h2;
    logic        load, step;

    match_fsm u_match_fsm (
        .clk, .rst, .s(start), .c(crash1 || crash2), .t(crash_done), .m(match_over), .p(pause),
        .waiting, .new_match, .restart, .start_go
    );
    score_unit u_score_unit (
        .clk, .rst, .new_match, .crash1, .crash2,
        .points_p1, .points_p2, .lives_p1, .lives_p2, .result, .match_over
    );
    position_logic #(.STEP_TICKS(STEP)) u_position_logic (
        .clk, .rst(rst || restart), .btn({start_go, dir}), .turn_req2(4'b0000),
        .pause, .match_over,
        .blkpos1_x(p1x), .blkpos1_y(p1y), .blkpos2_x(p2x), .blkpos2_y(p2y),
        .heading1(h1), .heading2(h2), .crash1, .crash2, .crash_done,
        .load, .step,
        .code1_u(4'd0), .code1_r(4'd0), .code1_d(4'd0), .code1_l(4'd0),
        .code2_u(4'd0), .code2_r(4'd0), .code2_d(4'd0), .code2_l(4'd0),
        .codes_valid
    );

    always #5 clk = ~clk;

    int ticks = 0;            // edges since time 0
    int crashes = 0;          // Crash Steps seen
    logic last_c1, last_c2;   // who crashed in the last Crash Step
    int crash_tick;           // edge of the last Crash Step
    int step_tick = -1;       // edge of the last Step

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "match_tb failed");
    endfunction

    // round_fsm's state as a number: s_wait 0, s_run 1, s_crash 2, s_release 3 (its enum order).
    function automatic int round_st();
        return int'(u_position_logic.u_round_fsm.st);
    endfunction

    // match_fsm and round_fsm states that may be seen together on one tick (plan section 4.1).
    function automatic bit aligned(int m, int r);
        case (m)
            0: return r == 0 || r == 3;     // G_IDLE: s_release after a reset, then s_wait
            1: return r == 1;               // G_PLAY: s_run
            2: return r == 2;               // G_CRASH: s_crash
            3: return r == 3 || r == 0;     // G_READY: s_release for one tick, then s_wait
            4: return r == 2;               // G_MATCH: s_crash, held by match_over
            5: return r == 0 || r == 2;     // G_NEW: from G_IDLE or from G_MATCH
            6: return r == 3 || r == 0;     // G_GO: s_release (s_wait if Pause held G_GO)
            7: return r == 0;               // G_START: s_wait
            default: return 0;
        endcase
    endfunction

    // Before each edge: Crash and Step events. After it: the checks of every tick.
    always @(posedge clk) begin
        ticks++;
        if (step === 1'b1) begin
            step_tick = ticks;
            if (codes_valid !== 1'b1) fail("a Step was taken with codes_valid = 0");
        end
        if (crash1 === 1'b1 || crash2 === 1'b1) begin
            crashes++;
            last_c1 = crash1;
            last_c2 = crash2;
            crash_tick = ticks;
        end
        #1;
        if (!rst && !aligned(u_match_fsm.st, round_st()))
            fail($sformatf("tick %0d: match_fsm in %0d with round_fsm in %0d", ticks, u_match_fsm.st, round_st()));
    end

    task automatic tick(int n = 1);
        repeat (n) @(posedge clk);
        #2;
    endtask

    task automatic expect_score(string what, int pt1, int pt2, int lv1, int lv2, int res);
        if (points_p1 !== 6'(pt1) || points_p2 !== 6'(pt2) || lives_p1 !== 2'(lv1)
            || lives_p2 !== 2'(lv2) || result !== 2'(res))
            fail($sformatf("%s: Points %0d-%0d Lives %0d-%0d result %0d; expected %0d-%0d %0d-%0d %0d",
                           what, points_p1, points_p2, lives_p1, lives_p2, result, pt1, pt2, lv1, lv2, res));
        $display("ok   %s: Points %0d-%0d, Lives %0d-%0d, result %0d", what, pt1, pt2, lv1, lv2, res);
    endtask

    task automatic expect_starts(string what);
        if (p1x !== 11'(P1_X0) || p1y !== 11'(P1_Y0) || p2x !== 11'(P2_X0) || p2y !== 11'(P2_Y0))
            fail($sformatf("%s: Bikes at (%0d,%0d) (%0d,%0d), not at their starts", what, p1x, p1y, p2x, p2y));
    endtask

    // A press of Start (one tick high) and the wait for the Round: 4 ticks from G_IDLE or
    // G_MATCH (G_NEW, G_GO, G_START), 2 from G_READY.
    task automatic press_start(string what);
        int waited = 0;
        start = 1'b1;
        tick();
        start = 1'b0;
        while (u_position_logic.run !== 1'b1) begin
            tick();
            if (++waited > 6) fail($sformatf("%s: Start did not start the Round", what));
        end
    endtask

    task automatic reset();
        rst = 1'b1;
        start = 1'b0; pause = 1'b0; dir = D_NONE; codes_valid = 1'b1;
        tick(2);
        rst = 1'b0;
        tick();
    endtask

    // Plays until the next Crash Step. With turn_up, P1 turns up on the first Step and drives
    // into the top Wall (23 Steps); otherwise both go straight and meet head-on (20 Steps).
    task automatic play_to_crash(string what, bit turn_up);
        int seen = crashes;
        int waited = 0;
        if (turn_up) dir = D_U;
        while (crashes == seen) begin
            tick();
            if (h1 == 2'd0) dir = D_NONE;
            if (++waited > 30 * STEP) fail($sformatf("%s: no Crash", what));
        end
    endtask

    // Waits for the end of the 2 s Crash display; returns how many edges it lasted.
    task automatic crash_display(string what, output int lasted);
        int waited = 0;
        while (u_match_fsm.st == 3'd2) begin
            tick();
            if (++waited > 200) fail($sformatf("%s: the Crash display did not end", what));
        end
        lasted = ticks - crash_tick;
    endtask

    int base_display, lasted, gap, held;

    initial begin
        reset();
        expect_score("reset", 0, 0, 3, 3, 0);
        expect_starts("reset");
        tick(20);
        if (u_position_logic.run !== 1'b0) fail("a Round runs without Start");

        // P1 drives into the top Wall three times: P2 gets 3 each time and wins 9-0. Between
        // Rounds the Bikes go back to their starts; after the last Crash they stay.
        for (int r = 1; r <= 3; r++) begin
            press_start($sformatf("Round %0d", r));
            play_to_crash($sformatf("Round %0d", r), 1'b1);
            if (!last_c1 || last_c2) fail($sformatf("Round %0d: expected P1 alone to crash", r));
            tick();
            expect_score($sformatf("P1 into the Wall, Round %0d", r), 0, 3 * r, 3 - r, 3, r == 3 ? 2 : 0);
            crash_display($sformatf("Round %0d", r), lasted);
            if (r == 1) base_display = lasted;
            if (lasted != base_display) fail($sformatf("Round %0d: Crash display of %0d ticks, the first was %0d", r, lasted, base_display));
            if (u_match_fsm.st !== (r == 3 ? 3'd4 : 3'd3))
                fail($sformatf("Round %0d: after the display match_fsm is in %0d", r, u_match_fsm.st));
            if (r < 3) begin
                tick(2);
                expect_starts($sformatf("after Round %0d", r));
            end
        end
        $display("ok   P1 out after three Crashes; Crash display of %0d ticks each", base_display);

        // Match over: the Bikes stay where they crashed and Start does not run a Round...
        tick(3 * 120);
        if (p1y !== 11'd80 || u_position_logic.run !== 1'b0 || u_match_fsm.st !== 3'd4)
            fail("the Match over did not hold the Bikes and the state");
        // ...also with a press made during Pause, which is not counted later.
        pause = 1'b1;
        start = 1'b1; tick(); start = 1'b0;
        tick(5);
        pause = 1'b0;
        tick(5);
        if (u_match_fsm.st !== 3'd4) fail("a Start pressed during Pause began a new Match");
        expect_score("Match over, held", 0, 9, 0, 3, 2);
        $display("ok   Match over holds the Bikes; Start in Pause is ignored");

        // One press starts a new Match: 0-0, 3 Lives, Bikes at their starts.
        press_start("new Match");
        expect_score("new Match", 0, 0, 3, 3, 0);
        expect_starts("new Match");

        // Three Head-on Crashes: both lose a Life each time, no bonus; both out at once with
        // the same Points is a Draw.
        for (int r = 1; r <= 3; r++) begin
            if (r > 1) press_start($sformatf("Head-on Round %0d", r));
            play_to_crash($sformatf("Head-on Round %0d", r), 1'b0);
            if (!last_c1 || !last_c2) fail($sformatf("Head-on Round %0d: expected both to crash", r));
            tick();
            expect_score($sformatf("Head-on, Round %0d", r), 0, 0, 3 - r, 3 - r, r == 3 ? 3 : 0);
            crash_display($sformatf("Head-on Round %0d", r), lasted);
        end
        if (u_match_fsm.st !== 3'd4) fail("the Draw did not end the Match");

        // Pause at the last tick of a Step period holds the Step: it comes exactly that many
        // ticks later, and no turn is kept.
        press_start("Pause in a Step");
        tick(2 * STEP);
        while (u_position_logic.u_step_counter.counter != STEP - 1) tick();
        gap = step_tick;
        pause = 1'b1;
        dir = D_U;
        tick(10);
        dir = D_NONE;
        pause = 1'b0;
        held = step_tick;
        tick();
        if (held != gap) fail("a Step was taken during Pause");
        if (step_tick - gap != STEP + 10)
            fail($sformatf("Step after Pause came %0d ticks after the previous, expected %0d", step_tick - gap, STEP + 10));
        if (h1 != 2'd1) fail("a turn pressed during Pause was kept");
        $display("ok   Pause at the end of a Step period: the Step came 10 ticks later, no turn");

        // Codes not valid on a Step tick: the Step waits.
        while (u_position_logic.u_step_counter.counter != STEP - 1) tick();
        codes_valid = 1'b0;
        tick();
        codes_valid = 1'b1;
        $display("ok   no Step with codes_valid = 0");

        // Pause during the Crash display lengthens it by exactly the paused ticks.
        play_to_crash("Pause in the display", 1'b0);
        tick(30);
        pause = 1'b1;
        tick(25);
        pause = 1'b0;
        crash_display("Pause in the display", lasted);
        if (lasted != base_display + 25)
            fail($sformatf("Crash display with 25 paused ticks lasted %0d, expected %0d", lasted, base_display + 25));
        $display("ok   Pause in the Crash display: %0d ticks instead of %0d", lasted, base_display);

        // A reset in each state of match_fsm returns everything to power-up.
        for (int target = 0; target < 8; target++) begin
            reset();
            if (target != 0) begin
                start = 1'b1; tick(); start = 1'b0;          // G_IDLE -> G_NEW
                if (target >= 6 && target != 4) tick();
                if (target >= 7 && target != 4) tick();
                if (target == 1 || target == 2 || target == 3 || target == 4) tick(3);
                if (target == 4) force u_score_unit.lives_p1 = 2'd1;
                if (target == 2 || target == 3 || target == 4) begin
                    tick();
                    release u_score_unit.lives_p1;
                    play_to_crash("reset test", 1'b1);
                    tick();
                end
                if (target == 3 || target == 4) crash_display("reset test", lasted);
            end
            if (u_match_fsm.st !== 3'(target)) fail($sformatf("reset test reached state %0d, not %0d", u_match_fsm.st, target));
            rst = 1'b1;
            tick();
            rst = 1'b0;
            if (u_match_fsm.st !== 3'd0 || round_st() != 3 || u_position_logic.run !== 1'b0)
                fail($sformatf("reset in state %0d: match_fsm %0d, round_fsm %0d", target, u_match_fsm.st, round_st()));
            expect_score($sformatf("reset in state %0d", target), 0, 0, 3, 3, 0);
            expect_starts($sformatf("reset in state %0d", target));
        end
        $display("ok   a reset in each of the 8 states returns to power-up");

        $display("PASS match_tb");
        $finish;
    end

endmodule
