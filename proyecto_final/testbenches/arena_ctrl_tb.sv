// Author: Alan (AIF31).
// Builder's own check of arena_ctrl with arena_map, on clk_pix only: the bench plays arena_link.
// A golden Arena is built here from the contract rules (clear, Trail and head codes), not
// read from the design, and compared word by word through the draw port, as drawcon would read it.
// Not the official bench of contract section 7.
`timescale 1ns/1ps
module arena_ctrl_tb;
    logic        clk = 1'b0, rst = 1'b1;
    logic        heads_tgl = 1'b0, prepare = 1'b0;
    logic [12:0] old_head_p1 = '0, old_head_p2 = '0, new_head_p1 = '0, new_head_p2 = '0;
    logic        codes_tgl;
    logic [15:0] neighbours_p1, neighbours_p2;
    logic [12:0] ctrl_addr, draw_addr = '0;
    logic        ctrl_write;
    logic [3:0]  ctrl_write_code, ctrl_read_code, draw_code;

    logic [3:0]  gold [0:8191];
    int          checks = 0;

    arena_ctrl dut (.clk, .rst, .heads_tgl, .prepare,
                    .old_head_p1, .old_head_p2, .new_head_p1, .new_head_p2, .codes_tgl, .neighbours_p1, .neighbours_p2,
                    .ctrl_addr, .ctrl_write, .ctrl_write_code, .ctrl_read_code);
    arena_map map (.clk, .ctrl_addr, .ctrl_write, .ctrl_write_code, .ctrl_read_code, .draw_addr, .draw_code);
    always #6 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "arena_ctrl_tb failed");
    endfunction

    function automatic logic [12:0] at(int cx, int cy);
        return {6'(cy), 7'(cx)};
    endfunction

    // Neighbour d (0 up, 1 right, 2 down, 3 left) of head h, each field wrapping on its own
    function automatic logic [12:0] nb(logic [12:0] h, int d);
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

    // Contract: EMPTY on the playable Cells cx 1..78, cy 5..48, WALL on every other word.
    function automatic void gold_clear();
        for (int a = 0; a < 8192; a++)
            gold[a] = ((a % 128) >= 1 && (a % 128) <= 78 && (a / 128) >= 5 && (a / 128) <= 48) ? 4'd0 : 4'd1;
    endfunction

    // Full Arena through the draw port, against the golden copy. An address presented before rising
    // edge n is read at edge n and shows on draw_code after edge n+1 (2 cycles).
    task automatic scan(string what);
        for (int i = 0; i <= 8192; i++) begin
            @(negedge clk);
            if (i < 8192) draw_addr = 13'(i);
            @(posedge clk); #1;
            if (i >= 1 && draw_code !== gold[i - 1])
                fail($sformatf("%s: word %0d (cx %0d, cy %0d) is %0d, expected %0d",
                               what, i - 1, (i - 1) % 128, (i - 1) / 128, draw_code, gold[i - 1]));
        end
        checks += 8192;
    endtask

    // One request as arena_link sends it: bundle and toggle together, then wait for codes_tgl.
    // Returns the clk_pix edges from the toggle to the answer.
    task automatic request(bit prep, logic [12:0] o1, logic [12:0] o2,
                           logic [12:0] n1, logic [12:0] n2, output int cycles);
        @(negedge clk);
        prepare = prep;
        old_head_p1 = o1; old_head_p2 = o2; new_head_p1 = n1; new_head_p2 = n2;
        heads_tgl = ~heads_tgl;
        cycles = 0;
        while (codes_tgl !== heads_tgl) begin
            @(posedge clk); #1;
            cycles++;
            if (cycles > 9000) fail("no answer within 9000 cycles");
        end
    endtask

    task automatic expect_cycles(string what, int got, int want);
        if (got != want) fail($sformatf("%s took %0d cycles, expected %0d", what, got, want));
    endtask

    task automatic expect_nbr(string what, logic [12:0] h1, logic [12:0] h2);
        if (neighbours_p1 !== gold_nbr(h1)) fail($sformatf("%s: neighbours_p1 %h, expected %h", what, neighbours_p1, gold_nbr(h1)));
        if (neighbours_p2 !== gold_nbr(h2)) fail($sformatf("%s: neighbours_p2 %h, expected %h", what, neighbours_p2, gold_nbr(h2)));
        checks += 2;
    endtask

    // Step as the rules give it: Trail at each old head, then the new heads. A Bike that did
    // not move (a Crash) has old = new, and its Cell stays a head.
    task automatic step(string what, logic [12:0] o1, logic [12:0] o2,
                        logic [12:0] n1, logic [12:0] n2);
        int cyc;
        request(1'b0, o1, o2, n1, n2, cyc);
        // 3 edges to see and copy the toggle, 1 to choose, 4 writes, 8 reads, 1 to answer
        expect_cycles(what, cyc, 17);
        gold[o1] = 4'd2;
        gold[o2] = 4'd4;
        gold[n1] = 4'd3;
        gold[n2] = 4'd5;
        expect_nbr(what, n1, n2);
        scan(what);
    endtask

    task automatic prepare_arena(string what, logic [12:0] n1, logic [12:0] n2);
        int cyc;
        request(1'b1, 13'd0, 13'd0, n1, n2, cyc);
        // 3 edges to see and copy the toggle, 1 to choose, 8192 clear writes, 2 heads, 8 reads,
        // 1 to answer
        expect_cycles(what, cyc, 8207);
        gold_clear();
        gold[n1] = 4'd3;
        gold[n2] = 4'd5;
        expect_nbr(what, n1, n2);
        scan(what);
    endtask

    initial begin
        logic [12:0] p1, p2;
        int cyc, empty;
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (3) @(posedge clk);
        if (codes_tgl !== 1'b0) fail("codes_tgl is not 0 after reset");

        // Prepare: the cleared Arena has 3432 EMPTY and 4760 WALL words, then two heads.
        p1 = at(20, 27); p2 = at(59, 27);
        prepare_arena("Prepare at the starts", p1, p2);
        empty = 0;
        gold_clear();
        for (int a = 0; a < 8192; a++) empty += (gold[a] == 4'd0);
        if (empty != 3432) fail($sformatf("golden clear has %0d EMPTY words", empty));
        gold[p1] = 4'd3; gold[p2] = 4'd5;

        // Both Bikes move: P1 right, P2 left; the Trails and heads appear.
        step("both move", p1, p2, at(21, 27), at(58, 27));
        step("P1 up, P2 left", at(21, 27), at(58, 27), at(21, 26), at(57, 27));
        // P2 turns down next to its own Trail: its up neighbour holds code 4 later.
        step("P2 down", at(21, 26), at(57, 27), at(21, 25), at(57, 28));
        step("P2 left", at(21, 25), at(57, 28), at(21, 24), at(56, 28));
        if (neighbours_p2[15:12] !== 4'd0 || gold[nb(at(56, 28), 0)] !== 4'd0) fail("P2 up neighbour should be EMPTY");
        step("P2 up into the row of its Trail", at(21, 24), at(56, 28), at(21, 23), at(56, 27));
        if (neighbours_p2[11:8] !== 4'd4 || neighbours_p2[7:4] !== 4'd4)
            fail($sformatf("P2 at (56,27): right and down should be its Trail (4), got neighbours_p2 %h", neighbours_p2));

        // P1 Crashes (it does not move) while P2 moves: P1's Cell stays a head, no code 6.
        step("P1 Crash", at(21, 23), at(56, 27), at(21, 23), at(55, 27));
        if (gold[at(21, 23)] !== 4'd3) fail("golden P1 head is not 3");

        // A new Round from the starts: everything is cleared again.
        prepare_arena("second Prepare", p1, p2);
        step("P2 Crash", p1, p2, at(20, 26), p2);
        step("both Crash", at(20, 26), p2, at(20, 26), p2);

        // Heads next to the Walls: (1, 5) and (78, 48). Their up/left and right/down are Walls.
        prepare_arena("Prepare in the corners", at(1, 5), at(78, 48));
        if (neighbours_p1 !== 16'h1001 || neighbours_p2 !== 16'h0110)
            fail($sformatf("corner neighbours: neighbours_p1 %h neighbours_p2 %h, expected 1001 and 0110", neighbours_p1, neighbours_p2));
        // A head at cx = 0 (never reached in play): its left neighbour stays in its row
        // (cx 127, same cy), not the row above. A marked word in the row above tells them apart.
        prepare_arena("Prepare at the padding", at(0, 30), at(10, 63));
        map.cells[at(127, 29)] = 4'd7; gold[at(127, 29)] = 4'd7;
        step("left neighbour at cx = 0", at(0, 30), at(10, 63), at(0, 30), at(10, 63));
        if (neighbours_p1[3:0] !== 4'd1) fail($sformatf("left of (0,30) read %0d, expected WALL", neighbours_p1[3:0]));

        // Reward codes (written by hand into the memory here) come back like any other code.
        prepare_arena("Prepare for Rewards", p1, p2);
        map.cells[at(21, 26)] = 4'd8;  gold[at(21, 26)] = 4'd8;
        map.cells[at(22, 27)] = 4'd10; gold[at(22, 27)] = 4'd10;
        step("Rewards as neighbours", p1, p2, at(21, 27), at(58, 27));
        if (neighbours_p1[15:12] !== 4'd8 || neighbours_p1[11:8] !== 4'd10)
            fail($sformatf("Reward neighbours: neighbours_p1 %h", neighbours_p1));

        // A reset while idle changes nothing: no write, no answer.
        @(negedge clk) rst = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (20) begin
            @(posedge clk); #1;
            if (ctrl_write) fail("wrote after a reset while idle");
            if (codes_tgl !== heads_tgl) fail("answer changed after a reset while idle");
        end

        // Bundle changes without a toggle are ignored: no write, no answer.
        @(negedge clk);
        prepare = 1'b1; new_head_p1 = at(40, 40); old_head_p1 = at(41, 41);
        repeat (40) begin
            @(posedge clk); #1;
            if (ctrl_write) fail("wrote without a request");
            if (codes_tgl !== heads_tgl) fail("answered without a request");
        end
        scan("after bundle changes without a toggle");

        // Reset in the middle of a clear: codes_tgl is not touched, so the held Prepare is still
        // open and is served again from the start. The old Trails must not survive.
        @(negedge clk);
        prepare = 1'b1;
        new_head_p1 = p1; new_head_p2 = p2;
        heads_tgl = ~heads_tgl;
        repeat (3000) @(posedge clk);
        #1 if (codes_tgl === heads_tgl) fail("answered before the clear finished");
        @(negedge clk) rst = 1'b1;
        repeat (2) @(posedge clk);
        #1 if (codes_tgl === heads_tgl) fail("the reset answered the cut Prepare");
        @(negedge clk) rst = 1'b0;
        cyc = 0;
        while (codes_tgl !== heads_tgl) begin
            @(posedge clk); #1;
            if (++cyc > 9000) fail("Prepare not served again after the reset");
        end
        gold_clear(); gold[p1] = 4'd3; gold[p2] = 4'd5;
        expect_nbr("Prepare after a reset mid-clear", p1, p2);
        scan("Prepare after a reset mid-clear");

        // Reset in the middle of a Step: served again, the same writes, the same image.
        @(negedge clk);
        prepare = 1'b0; old_head_p1 = p1; old_head_p2 = p2; new_head_p1 = at(21, 27); new_head_p2 = at(58, 27);
        heads_tgl = ~heads_tgl;
        repeat (7) @(posedge clk);
        @(negedge clk) rst = 1'b1;
        @(negedge clk) rst = 1'b0;
        cyc = 0;
        while (codes_tgl !== heads_tgl) begin
            @(posedge clk); #1;
            if (++cyc > 100) fail("Step not served again after the reset");
        end
        gold[p1] = 4'd2; gold[p2] = 4'd4; gold[at(21, 27)] = 4'd3; gold[at(58, 27)] = 4'd5;
        expect_nbr("Step after a reset mid-Step", at(21, 27), at(58, 27));
        scan("Step after a reset mid-Step");

        // drawcon reads the draw port during a whole Prepare: the result is the same.
        fork
            request(1'b1, 13'd0, 13'd0, p1, p2, cyc);
            repeat (8300) @(negedge clk) draw_addr = 13'($urandom_range(0, 8191));
        join
        expect_cycles("Prepare with the draw port busy", cyc, 8207);
        gold_clear(); gold[p1] = 4'd3; gold[p2] = 4'd5;
        expect_nbr("Prepare with the draw port busy", p1, p2);
        scan("Prepare with the draw port busy");

        $display("PASS arena_ctrl_tb (%0d checks)", checks);
        $finish;
    end
endmodule
