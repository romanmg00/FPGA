// Builder's own check of arena_link + arena_ctrl + arena_map with two free-running clocks: clk_pix
// at 12 ns and clk_juego scaled down to ~12,000 clk_pix cycles per tick, with a fractional period
// so the phase between them drifts. The driver plays position_logic: load, step and the heads
// change just after a clk_juego edge, and a Step waits while codes_valid = 0 (the proposed
// policy). A golden Arena is kept from the rules and read back through port B, as drawcon would.
// STEP_TICKS comes from +step_ticks=N (default 8). Not the official bench of contract section 7.
`timescale 1ns/1ps
module arena_tb;
    logic        clk_pix = 1'b0, clk_juego = 1'b0;
    logic        rst_pix = 1'b1, rst_juego = 1'b1;
    // position_logic side
    logic        load = 1'b1, step = 1'b0;
    logic [6:0]  cx1 = 7'd20, cx2 = 7'd59;
    logic [5:0]  cy1 = 6'd27, cy2 = 6'd27;
    logic [10:0] blkpos1_x, blkpos1_y, blkpos2_x, blkpos2_y;
    logic [3:0]  code1_u, code1_r, code1_d, code1_l, code2_u, code2_r, code2_d, code2_l;
    logic        codes_valid;
    // the crossing
    logic        req_tgl, req_prepare, ack_tgl;
    logic [12:0] req_old1, req_old2, req_new1, req_new2;
    logic [15:0] nbr1, nbr2;
    // arena_map
    logic [12:0] a_addr, b_addr = '0;
    logic        a_we;
    logic [3:0]  a_wdata, a_rdata, b_rdata;

    logic [3:0]  gold [0:8191];
    int          ST = 8;              // ticks per Step
    int          tk = 0;              // clk_juego rising edges so far
    int          last_step = 0;       // tick of the last Step edge or of the Start
    int          want_reqs = 0;       // Steps and Prepares the driver has caused
    int          reqs = 0;            // toggles of req_tgl seen
    int          checks = 0;
    logic        req_last = 1'b0;

    assign blkpos1_x = {cx1, 4'b0000};
    assign blkpos1_y = {1'b0, cy1, 4'b0000};
    assign blkpos2_x = {cx2, 4'b0000};
    assign blkpos2_y = {1'b0, cy2, 4'b0000};

    arena_link u_link (
        .clk(clk_juego), .rst(rst_juego), .load, .step,
        .blkpos1_x, .blkpos1_y, .blkpos2_x, .blkpos2_y,
        .code1_u, .code1_r, .code1_d, .code1_l, .code2_u, .code2_r, .code2_d, .code2_l, .codes_valid,
        .req_tgl, .req_prepare, .req_old1, .req_old2, .req_new1, .req_new2,
        .ack_tgl, .nbr1, .nbr2);
    arena_ctrl u_ctrl (
        .clk(clk_pix), .rst(rst_pix), .req_tgl, .req_prepare,
        .req_old1, .req_old2, .req_new1, .req_new2, .ack_tgl, .nbr1, .nbr2,
        .a_addr, .a_we, .a_wdata, .a_rdata);
    arena_map u_map (.clk(clk_pix), .a_addr, .a_we, .a_wdata, .a_rdata, .b_addr, .b_rdata);

    always #6 clk_pix = ~clk_pix;
    always #72003.7 clk_juego = ~clk_juego;
    always @(posedge clk_juego) tk++;

    function automatic void fail(string msg);
        $display("FAIL [STEP_TICKS=%0d, tick %0d] %s", ST, tk, msg);
        $fatal(1, "arena_tb failed");
    endfunction

    function automatic logic [12:0] at(int cx, int cy);
        return {6'(cy), 7'(cx)};
    endfunction

    function automatic logic [12:0] nb(logic [12:0] h, int d);   // 0 up, 1 right, 2 down, 3 left
        logic [5:0] cy = h[12:7];
        logic [6:0] cx = h[6:0];
        case (d)
            0: cy = cy - 6'd1;
            1: cx = cx + 7'd1;
            2: cy = cy + 6'd1;
            default: cx = cx - 7'd1;
        endcase
        return {cy, cx};
    endfunction

    function automatic logic [15:0] gold_nbr(logic [12:0] h);
        return {gold[nb(h, 0)], gold[nb(h, 1)], gold[nb(h, 2)], gold[nb(h, 3)]};
    endfunction

    function automatic logic [12:0] head1();
        return at(cx1, cy1);
    endfunction

    function automatic logic [12:0] head2();
        return at(cx2, cy2);
    endfunction

    // Golden Prepare: EMPTY on cx 1..78, cy 5..48, WALL elsewhere, then both heads.
    function automatic void gold_prepare();
        for (int a = 0; a < 8192; a++)
            gold[a] = ((a % 128) >= 1 && (a % 128) <= 78 && (a / 128) >= 5 && (a / 128) <= 48) ? 4'd0 : 4'd1;
        gold[head1()] = 4'd3;
        gold[head2()] = 4'd5;
    endfunction

    // Monitors. Whenever codes_valid = 1 the codes are those of the current heads; the bundle
    // never changes while a request is open; every req_tgl toggle is counted.
    logic [52:0] bundle, bundle_prev;
    logic        open_prev = 1'b0;
    assign bundle = {req_prepare, req_old1, req_old2, req_new1, req_new2};
    always @(posedge clk_pix) begin
        if (bundle !== bundle_prev && open_prev)
            fail("the request changed while it was open");
        bundle_prev = bundle;
        open_prev   = (req_tgl !== ack_tgl);
    end
    always @(posedge clk_juego) begin
        #2;
        if (req_tgl !== req_last) begin
            reqs++;
            req_last = req_tgl;
        end
        if (codes_valid) begin
            if ({code1_u, code1_r, code1_d, code1_l} !== gold_nbr(head1()))
                fail($sformatf("codes_valid with P1 codes %h, expected %h", {code1_u, code1_r, code1_d, code1_l}, gold_nbr(head1())));
            if ({code2_u, code2_r, code2_d, code2_l} !== gold_nbr(head2()))
                fail($sformatf("codes_valid with P2 codes %h, expected %h", {code2_u, code2_r, code2_d, code2_l}, gold_nbr(head2())));
            checks += 2;
        end
    end

    task automatic tick();
        @(posedge clk_juego);
        #1;
    endtask

    // The full Arena through port B (latency 2), against the golden copy. ~0.7 tick.
    task automatic scan(string what);
        for (int i = 0; i <= 8192; i++) begin
            @(negedge clk_pix);
            if (i < 8192) b_addr = 13'(i);
            @(posedge clk_pix); #1;
            if (i >= 1 && b_rdata !== gold[i - 1])
                fail($sformatf("%s: word %0d (cx %0d, cy %0d) is %0d, expected %0d",
                               what, i - 1, (i - 1) % 128, (i - 1) / 128, b_rdata, gold[i - 1]));
        end
        checks += 8192;
    endtask

    // Right after an event edge E (Step or load rise): codes_valid is 0 at E+0..E+3 and 1 from
    // E+4, with the codes of the current heads (the monitor compares them). Then a full scan.
    task automatic expect_k4(string what);
        for (int t = 0; t <= 4; t++) begin
            if (t > 0) tick();
            if (codes_valid !== (t == 4))
                fail($sformatf("%s: codes_valid = %b at event + %0d", what, codes_valid, t));
        end
        if (reqs != want_reqs) fail($sformatf("%s: %0d requests sent, expected %0d", what, reqs, want_reqs));
        scan(what);
    endtask

    task automatic move(int bike, int d);
        if (bike == 1) begin
            case (d) 0: cy1--; 1: cx1++; 2: cy1++; default: cx1--; endcase
        end else begin
            case (d) 0: cy2--; 1: cx2++; 2: cy2++; default: cx2--; endcase
        end
    endtask

    // A Step: step = 1 for the tick before edge k, STEP_TICKS ticks after the last one, but
    // only once codes_valid = 1. At edge k each Bike moves one Cell in d, unless either Bike
    // crashes: then neither moves (ADR 0011, proposed), and a survivor's old and new head are
    // the same Cell, which stays a head.
    task automatic do_step(int d1, int d2, bit c1, bit c2, output int waited);
        logic [12:0] o1, o2;
        waited = 0;
        while (tk < last_step + ST - 1) tick();
        while (!codes_valid) begin
            tick();
            if (++waited > 40) fail("codes_valid never came back");
        end
        step = 1'b1;                                    // c1/c2 only decide whether the Bikes move
        tick();                                         // edge k
        o1 = head1(); o2 = head2();
        if (!c1 && !c2) begin
            move(1, d1);
            move(2, d2);
        end
        step = 1'b0;
        last_step = tk;
        want_reqs++;
        gold[o1] = 4'd2;                                // a Bike that did not move: o = head,
        gold[o2] = 4'd4;                                // and the head write comes last
        gold[head1()] = 4'd3;
        gold[head2()] = 4'd5;
    endtask

    task automatic step_on_time(string what, int d1, int d2, bit c1 = 0, bit c2 = 0);
        int waited;
        do_step(d1, d2, c1, c2, waited);
        if (waited) fail($sformatf("%s: codes_valid was 0 at the Step tick", what));
        expect_k4(what);
    endtask

    // load rises after an edge; bike_move loads the starts at the next edge (the event edge).
    task automatic load_rise();
        load = 1'b1;
        tick();
        cx1 = 7'd20; cy1 = 6'd27; cx2 = 7'd59; cy2 = 6'd27;
        want_reqs++;
        gold_prepare();
    endtask

    task automatic start(int load_ticks);
        repeat (load_ticks) tick();
        load = 1'b0;
        last_step = tk;
    endtask

    initial begin
        int waited, guard;
        void'($value$plusargs("step_ticks=%d", ST));

        // ---- Power-up: both resets, then the Prepare from round_fsm's s_release (load = 1).
        repeat (3) @(posedge clk_pix);
        rst_pix = 1'b0;
        tick(); tick();
        rst_juego = 1'b0;
        tick();                                         // event edge: load rises out of reset
        want_reqs++;
        gold_prepare();
        expect_k4("Prepare after power-up");
        if (gold_nbr(head1()) !== 16'h0000 || gold_nbr(head2()) !== 16'h0000) fail("start neighbours are not EMPTY");

        // ---- Round 1, Start 2 ticks after the Prepare event: P1 right then up to the top Wall,
        // then left along it; P2 left until it sits next to P1's Trail.
        start(2);
        step_on_time("first Step", 1, 3);
        for (int i = 0; i < 22; i++) step_on_time($sformatf("P1 up %0d", i), 0, 3);
        if (cy1 != 5 || code1_u !== 4'd1) fail($sformatf("P1 at (%0d,%0d): up should be WALL, got %0d", cx1, cy1, code1_u));
        step_on_time("P1 left on the top row", 3, 3);
        if (code1_r !== 4'd2) fail($sformatf("P1 right should be its Trail, got %0d", code1_r));
        while (cx2 > 22) step_on_time($sformatf("P2 left to %0d", cx2 - 1), 3, 3);
        if (code2_l !== 4'd2) fail($sformatf("P2 at (22,27): left should be P1's Trail, got %0d", code2_l));
        if (code1_l !== 4'd0 || code1_u !== 4'd1) fail("P1 on the top row: left EMPTY, up WALL");

        // ---- P2 Crashes into P1's Trail; neither Bike moves, and both Cells stay heads.
        step_on_time("P2 Crash", 3, 3, 0, 1);
        if (gold[at(22, 27)] !== 4'd5 || gold[at(23, 27)] !== 4'd4 || gold[head1()] !== 4'd3)
            fail("golden Crash image");

        // ---- Crash pause, then a new Round: the Arena is prepared from the starts again.
        repeat (5) tick();
        load_rise();
        expect_k4("Prepare after a Crash");

        // ---- Round 2: the answer to a Step is held back (arena_ctrl in reset for STEP_TICKS
        // ticks). The next Step waits for codes_valid, and no request is lost or repeated.
        start(3);
        step_on_time("Round 2 first Step", 1, 3);
        do_step(0, 3, 0, 0, waited);
        tick();                                         // k+1: the request is out
        rst_pix = 1'b1;
        fork
            begin repeat (ST) @(posedge clk_juego); #3 rst_pix = 1'b0; end
        join_none
        do_step(0, 3, 0, 0, waited);
        if (waited == 0) fail("the held answer did not delay the next Step");
        expect_k4("Step after a held answer");
        step_on_time("Round 2 back on time", 0, 3);

        // ---- A Crash Step whose answer is held while load rises: the Prepare waits behind the
        // open request, and codes_valid stays 0 until the Prepare's own answer.
        do_step(0, 3, 1, 1, waited);
        tick();
        rst_pix = 1'b1;
        repeat (3) tick();
        load_rise();                                    // the Prepare waits
        repeat (2) tick();
        if (codes_valid) fail("codes_valid during the held Crash Step");
        rst_pix = 1'b0;
        guard = 0;
        while (!codes_valid) begin
            tick();
            if (++guard > 12) fail("no codes after the waiting Prepare");
            if (codes_valid && reqs != want_reqs) fail("codes_valid before the Prepare was sent");
        end
        if (reqs != want_reqs) fail($sformatf("%0d requests, expected %0d", reqs, want_reqs));
        scan("Prepare that waited behind a held Step");

        // ---- Round 3: a CPU reset short enough to reach only clk_pix, in the middle of the
        // clear. The cut Prepare is served again and still answers at event + 4.
        start(2);
        step_on_time("Round 3 first Step", 1, 3);
        step_on_time("Round 3 second Step", 0, 3, 1, 0);
        repeat (4) tick();
        load_rise();
        if (codes_valid !== 1'b0) fail("codes_valid at the load rise");
        tick();                                         // event + 1: the Prepare is out
        repeat (2000) @(posedge clk_pix);
        rst_pix = 1'b1;
        repeat (3) @(posedge clk_pix);
        rst_pix = 1'b0;
        repeat (2) begin tick(); if (codes_valid) fail("codes_valid early after the cut clear"); end
        tick();
        if (!codes_valid) fail("codes_valid not 1 at event + 4 after the cut clear");
        scan("Prepare cut by a clk_pix reset");

        // ---- Round 4: a full CPU reset one tick after a Step's request went out. The answer to
        // that request is not taken as valid, and the Prepare out of reset clears the Arena.
        start(2);
        step_on_time("Round 4 first Step", 1, 3);
        do_step(2, 3, 0, 0, waited);
        tick();                                         // k+1: the request is out
        rst_pix = 1'b1; rst_juego = 1'b1;
        tick();                                         // bike_move and round_fsm reset here
        cx1 = 7'd20; cy1 = 6'd27; cx2 = 7'd59; cy2 = 6'd27;
        load = 1'b1;
        if (codes_valid) fail("codes_valid during reset");
        rst_pix = 1'b0;
        tick(); tick();
        rst_juego = 1'b0;
        tick();                                         // event edge: load rises out of reset
        want_reqs++;
        gold_prepare();
        expect_k4("Prepare after a full reset");

        // ---- Round 5: normal Steps again, both Bikes Crash on the same Step.
        start(2);
        step_on_time("Round 5 first Step", 1, 3);
        step_on_time("Round 5 second Step", 2, 0);
        step_on_time("both Crash", 2, 0, 1, 1);
        if (gold[head1()] !== 4'd3 || gold[head2()] !== 4'd5) fail("golden double Crash");

        repeat (4) tick();
        if (ack_tgl !== req_tgl) fail("a request is still open at the end");
        if (reqs != want_reqs) fail($sformatf("%0d requests, expected %0d", reqs, want_reqs));
        $display("PASS arena_tb STEP_TICKS=%0d (%0d requests, %0d checks)", ST, reqs, checks);
        $finish;
    end

    initial begin
        #2s;
        fail("timeout");
    end
endmodule
