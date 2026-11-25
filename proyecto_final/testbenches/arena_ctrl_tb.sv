// Author: Alan (AIF31).
// Builder's own check of arena_ctrl with arena_map, on clk_pix only: the bench plays arena_link.
// A golden Arena is built here from the contract rules (clear, Trail and head codes) and from
// ADR 0012's Reward search (LFSR, 64 draws, then a wrapping scan), not read from the design,
// and compared word by word through the draw port, as drawcon would read it. Each request's
// length in clk_pix cycles is checked against the same search.
// A second controller, dut_f (FIXED_SEED = 1), checks that the first two Prepares place the
// Rewards on the Cells prototipos/tron_fpga/model computes for the same seed.
// Not the official bench of contract section 7.
`timescale 1ns/1ps
module arena_ctrl_tb;
    localparam logic [31:0] SEED = 32'h1D2C_3B4A;       // the model's LFSR_SEED
    logic        clk = 1'b0, rst = 1'b1, rst_f = 1'b1;
    logic        heads_tgl = 1'b0, prepare = 1'b0, reseed = 1'b0;
    logic [2:0]  collected = 3'b000;
    logic [12:0] old_head_p1 = '0, old_head_p2 = '0, new_head_p1 = '0, new_head_p2 = '0;
    logic        codes_tgl, codes_tgl_f;
    logic [15:0] neighbours_p1, neighbours_p2;
    logic [12:0] ctrl_addr, draw_addr = '0;
    logic        ctrl_write;
    logic [3:0]  ctrl_write_code, ctrl_read_code, draw_code;
    logic [12:0] f_addr;
    logic        f_write;
    logic [3:0]  f_write_code, f_read_code;

    logic [3:0]  gold [0:8191];
    logic [31:0] glfsr = SEED;          // golden LFSR, reset and stepped as the design's
    int          idle_draws = 0;        // dut's idle draws not yet applied to glfsr
    int          checks = 0;
    bit          use_f = 1'b1;          // wait for dut_f's answers too

    arena_ctrl #(.FIXED_SEED(1'b0), .SEED(SEED)) dut (
        .clk, .rst, .heads_tgl, .prepare, .reseed, .collected,
        .old_head_p1, .old_head_p2, .new_head_p1, .new_head_p2, .codes_tgl, .neighbours_p1, .neighbours_p2,
        .ctrl_addr, .ctrl_write, .ctrl_write_code, .ctrl_read_code);
    arena_map map (.clk, .ctrl_addr, .ctrl_write, .ctrl_write_code, .ctrl_read_code, .draw_addr, .draw_code);

    arena_ctrl #(.FIXED_SEED(1'b1), .SEED(SEED)) dut_f (
        .clk, .rst(rst_f), .heads_tgl, .prepare, .reseed, .collected,
        .old_head_p1, .old_head_p2, .new_head_p1, .new_head_p2, .codes_tgl(codes_tgl_f),
        .neighbours_p1(), .neighbours_p2(),
        .ctrl_addr(f_addr), .ctrl_write(f_write), .ctrl_write_code(f_write_code), .ctrl_read_code(f_read_code));
    arena_map map_f (.clk, .ctrl_addr(f_addr), .ctrl_write(f_write), .ctrl_write_code(f_write_code),
                     .ctrl_read_code(f_read_code), .draw_addr(13'd0), .draw_code());
    always #6 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "arena_ctrl_tb failed");
    endfunction

    function automatic logic [12:0] at(int cx, int cy);
        return {6'(cy), 7'(cx)};
    endfunction

    // ADR 0012: one draw is 32 shifts left, the new bit is bit 31 ^ 21 ^ 1 ^ 0.
    function automatic logic [31:0] draw(logic [31:0] s);
        for (int i = 0; i < 32; i++) s = {s[30:0], s[31] ^ s[21] ^ s[1] ^ s[0]};
        return s;
    endfunction

    // The golden LFSR follows dut's (FIXED_SEED = 0): back to SEED on a reset, and one draw on
    // each edge in s_idle (state 0), applied when the next request passes s_start (state 1),
    // so that gold_place, called after the answer, draws from the request's own start.
    always @(posedge clk) begin
        if (rst) begin
            glfsr = SEED;
            idle_draws = 0;
        end else if (dut.state == 4'd0)
            idle_draws++;
        else if (dut.state == 4'd1) begin
            repeat (idle_draws) glfsr = draw(glfsr);
            idle_draws = 0;
        end
    end

    // Golden placement of one slot: up to 64 draws (cx = bits 6-0, cy = bits 12-7), then the
    // words after the last draw, wrapping, 8192 of them. Returns its clk_pix cycles: 1 to pick
    // the slot, 3 per draw, 2 per scanned word, 1 to write it.
    task automatic gold_place(int slot, output int cyc);
        logic [12:0] c;
        bit found;
        found = 1'b0;
        cyc = 1;
        c = 13'd0;
        for (int n = 1; n <= 64 && !found; n++) begin
            glfsr = draw(glfsr);
            c = glfsr[12:0];
            cyc += 3;
            found = (gold[c] == 4'd0);
        end
        for (int k = 1; k <= 8192 && !found; k++) begin
            c = c + 13'd1;
            cyc += 2;
            found = (gold[c] == 4'd0);
        end
        if (found) begin
            gold[c] = 4'd8 + 4'(slot);
            cyc += 1;
        end
    endtask

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

    // Where Reward slot s is in the golden Arena, or -1
    function automatic int gold_slot(int s);
        int where = -1;
        for (int a = 0; a < 8192; a++) if (gold[a] == 4'd8 + 4'(s)) where = a;
        return where;
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

    // One request as arena_link sends it: bundle and toggle together, then wait for codes_tgl
    // (and dut_f's). Returns dut's clk_pix edges from the toggle to the answer.
    task automatic request(bit prep, bit rs, logic [2:0] col, logic [12:0] o1, logic [12:0] o2,
                           logic [12:0] n1, logic [12:0] n2, output int cycles);
        @(negedge clk);
        prepare = prep; reseed = rs; collected = col;
        old_head_p1 = o1; old_head_p2 = o2; new_head_p1 = n1; new_head_p2 = n2;
        heads_tgl = ~heads_tgl;
        cycles = 0;
        while (codes_tgl !== heads_tgl) begin
            @(posedge clk); #1;
            cycles++;
            if (cycles > 60000) fail("no answer within 60000 cycles");
        end
        while (use_f && codes_tgl_f !== heads_tgl) begin
            @(posedge clk); #1;
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

    // Step as the rules give it: Trail at each old head, then the new heads, then a new Cell for
    // each Reward slot taken, lowest first. A Bike that did not move (a Crash) has old = new, and
    // its Cell stays a head. 18 cycles: 3 edges to see and copy the toggle, 1 to choose, 4
    // writes, 1 to find no slot left, 8 reads, 1 to answer; plus each placement.
    task automatic step(string what, logic [12:0] o1, logic [12:0] o2,
                        logic [12:0] n1, logic [12:0] n2, logic [2:0] col = 3'b000);
        int cyc, want, c;
        request(1'b0, 1'b0, col, o1, o2, n1, n2, cyc);
        gold[o1] = 4'd2;
        gold[o2] = 4'd4;
        gold[n1] = 4'd3;
        gold[n2] = 4'd5;
        want = 18;
        for (int s = 0; s < 3; s++)
            if (col[s]) begin
                gold_place(s, c);
                want += c;
            end
        expect_cycles(what, cyc, want);
        expect_nbr(what, n1, n2);
        scan(what);
    endtask

    // 8208 cycles: 3 to see and copy the toggle, 1 to choose, 8192 clear writes, 2 heads, 1 to
    // find no slot left, 8 reads, 1 to answer; plus the three placements.
    task automatic prepare_arena(string what, logic [12:0] n1, logic [12:0] n2, bit rs = 1'b0);
        int cyc, want, c;
        request(1'b1, rs, 3'b000, 13'd0, 13'd0, n1, n2, cyc);
        gold_clear();
        gold[n1] = 4'd3;
        gold[n2] = 4'd5;
        want = 8208;
        for (int s = 0; s < 3; s++) begin
            gold_place(s, c);
            want += c;
        end
        expect_cycles(what, cyc, want);
        expect_nbr(what, n1, n2);
        scan(what);
    endtask

    // dut_f's Reward slots, against the Cells the shared model gives (prototipos/tron_fpga/model,
    // LFSR_SEED, heads at the starts).
    task automatic expect_f_slots(string what, int x0, int y0, int x1, int y1, int x2, int y2);
        int want [3];
        int found [3];
        want[0] = at(x0, y0); want[1] = at(x1, y1); want[2] = at(x2, y2);
        found = '{-1, -1, -1};
        for (int a = 0; a < 8192; a++)
            if (map_f.cells[a] >= 4'd8 && map_f.cells[a] <= 4'd10) begin
                if (found[map_f.cells[a] - 8] != -1) fail($sformatf("%s: slot %0d twice", what, map_f.cells[a] - 8));
                found[map_f.cells[a] - 8] = a;
            end
        for (int s = 0; s < 3; s++)
            if (found[s] != want[s])
                fail($sformatf("%s: slot %0d at (%0d,%0d), the model places it at (%0d,%0d)",
                               what, s, found[s] % 128, found[s] / 128, want[s] % 128, want[s] / 128));
        $display("ok   %s: FIXED_SEED slots at (%0d,%0d) (%0d,%0d) (%0d,%0d), as the model", what, x0, y0, x1, y1, x2, y2);
    endtask

    initial begin
        logic [12:0] p1, p2, r0, r1, r2, keep;
        int cyc, empty, want, c;
        repeat (3) @(posedge clk);
        @(negedge clk) begin rst = 1'b0; rst_f = 1'b0; end
        repeat (3) @(posedge clk);
        if (codes_tgl !== 1'b0) fail("codes_tgl is not 0 after reset");

        // Prepare of a new Match: the cleared Arena has 3432 EMPTY and 4760 WALL words, then two
        // heads and three Rewards. dut's LFSR has run since the reset; dut_f starts at SEED.
        p1 = at(20, 27); p2 = at(59, 27);
        prepare_arena("Prepare of a new Match", p1, p2, 1'b1);
        expect_f_slots("first Prepare", 39, 32, 10, 9, 1, 12);
        if (map.cells[at(39, 32)] == 4'd8 && map.cells[at(10, 9)] == 4'd9 && map.cells[at(1, 12)] == 4'd10)
            fail("dut's LFSR did not run while idle: it placed as from SEED");
        empty = 0;
        gold_clear();
        for (int a = 0; a < 8192; a++) empty += (gold[a] == 4'd0);
        if (empty != 3432) fail($sformatf("golden clear has %0d EMPTY words", empty));

        // The next Round's Prepare keeps the LFSR going: new Cells, and the model's again.
        prepare_arena("Prepare of the next Round", p1, p2);
        expect_f_slots("next Round", 5, 23, 61, 39, 30, 28);
        // A new Match's Prepare with FIXED_SEED starts again from SEED: the same Cells.
        prepare_arena("Prepare of a second Match", p1, p2, 1'b1);
        expect_f_slots("second Match", 39, 32, 10, 9, 1, 12);
        use_f = 1'b0;
        @(negedge clk) rst_f = 1'b1;           // dut_f is done

        // Both Bikes move: P1 right, P2 left; the Trails and heads appear.
        step("both move", p1, p2, at(21, 27), at(58, 27));
        step("P1 up, P2 left", at(21, 27), at(58, 27), at(21, 26), at(57, 27));
        // P2 turns down next to its own Trail: its up neighbour holds code 4 later.
        step("P2 down", at(21, 26), at(57, 27), at(21, 25), at(57, 28));
        step("P2 left", at(21, 25), at(57, 28), at(21, 24), at(56, 28));
        step("P2 up into the row of its Trail", at(21, 24), at(56, 28), at(21, 23), at(56, 27));
        if (neighbours_p2[11:8] !== 4'd4 || neighbours_p2[7:4] !== 4'd4)
            fail($sformatf("P2 at (56,27): right and down should be its Trail (4), got neighbours_p2 %h", neighbours_p2));

        // P1 Crashes (it does not move) while P2 moves: P1's Cell stays a head, no code 6.
        step("P1 Crash", at(21, 23), at(56, 27), at(21, 23), at(55, 27));
        if (gold[at(21, 23)] !== 4'd3) fail("golden P1 head is not 3");

        // Rewards taken: each Bike's new head is a Reward Cell, and that slot gets a new Cell.
        // The codes already show it, so a Reward placed next to a head is seen before the Step.
        prepare_arena("Prepare for collections", p1, p2);
        r0 = gold_slot(0);
        step("P1 takes slot 0 (+1)", p1, p2, r0, at(58, 27), 3'b001);
        if (gold_slot(0) == r0 || gold_slot(0) < 0) fail("slot 0 has no new Cell");
        r1 = gold_slot(1); r2 = gold_slot(2);
        step("P1 takes slot 2, P2 slot 1, in one Step", r0, at(58, 27), r2, r1, 3'b110);
        if (gold_slot(1) < 0 || gold_slot(2) < 0 || gold_slot(1) == r1 || gold_slot(2) == r2)
            fail("slots 1 and 2 did not both get new Cells");
        $display("ok   collections: each slot taken gets one new EMPTY Cell, lowest slot first");

        // The 64 draws all miss: only one EMPTY Cell is left, and the scan finds it. Filled by
        // hand in both copies; the slot taken is then placed there.
        prepare_arena("Prepare before filling", p1, p2);
        r0 = gold_slot(0);
        keep = at(70, 40);
        while (gold[keep] != 4'd0) keep++;
        for (int a = 0; a < 8192; a++)
            if (gold[a] == 4'd0 && a != keep) begin
                gold[a] = 4'd2;
                map.cells[a] = 4'd2;
            end
        step("one EMPTY Cell left: found by the scan", p1, p2, r0, at(58, 27), 3'b001);
        if (gold_slot(0) != keep) fail("slot 0 did not land on the last EMPTY Cell");
        // No EMPTY Cell at all: a slot taken stays absent. 64 draws and 8192 words: 16577 cycles.
        step("slot 0 taken with no EMPTY Cell", r0, at(58, 27), keep, at(57, 27), 3'b001);
        r1 = gold_slot(1);
        step("slot 1 taken with no EMPTY Cell", keep, at(57, 27), keep, r1, 3'b010);
        if (gold_slot(0) != -1 || gold_slot(1) != -1) fail("a slot was placed with no EMPTY Cell");
        $display("ok   a full Arena leaves the slot absent; the request still answers");
        // The next Prepare places all three again.
        prepare_arena("Prepare after a full Arena", p1, p2);
        if (gold_slot(0) < 0 || gold_slot(1) < 0 || gold_slot(2) < 0) fail("a slot is missing after the Prepare");

        // Heads next to the Walls: (1, 5) and (78, 48). Their up/left and right/down are Walls.
        prepare_arena("Prepare in the corners", at(1, 5), at(78, 48));
        if (neighbours_p1[15:12] !== 4'd1 || neighbours_p1[3:0] !== 4'd1 ||
            neighbours_p2[11:8] !== 4'd1 || neighbours_p2[7:4] !== 4'd1)
            fail($sformatf("corner neighbours: neighbours_p1 %h neighbours_p2 %h", neighbours_p1, neighbours_p2));
        // A head at cx = 0 (never reached in play): its left neighbour stays in its row
        // (cx 127, same cy), not the row above. A marked word in the row above tells them apart.
        prepare_arena("Prepare at the padding", at(0, 30), at(10, 63));
        map.cells[at(127, 29)] = 4'd7; gold[at(127, 29)] = 4'd7;
        step("left neighbour at cx = 0", at(0, 30), at(10, 63), at(0, 30), at(10, 63));
        if (neighbours_p1[3:0] !== 4'd1) fail($sformatf("left of (0,30) read %0d, expected WALL", neighbours_p1[3:0]));

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
        prepare = 1'b1; reseed = 1'b1; collected = 3'b111; new_head_p1 = at(40, 40); old_head_p1 = at(41, 41);
        repeat (40) begin
            @(posedge clk); #1;
            if (ctrl_write) fail("wrote without a request");
            if (codes_tgl !== heads_tgl) fail("answered without a request");
        end
        scan("after bundle changes without a toggle");

        // Reset in the middle of a clear: codes_tgl is not touched, so the held Prepare is still
        // open and is served again from the start. The old Trails must not survive, and the
        // LFSR starts again from SEED, where the reset put it.
        @(negedge clk);
        prepare = 1'b1; reseed = 1'b0; collected = 3'b000;
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
        for (int s = 0; s < 3; s++) gold_place(s, c);
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

        // A reset after each of the first 40 edges of a Step that takes slot 0, also on and after
        // its answer: the answer never changes during the reset, then exactly one answer comes.
        // A cut after the Reward write places slot 0 again, so it is on one or two Cells, each
        // EMPTY before; every other word is the golden one. The Prepare that follows a reset
        // then leaves every slot on exactly one Cell.
        begin
            int singles = 0, doubles = 0;
            for (int k = 1; k <= 40; k++) begin
                logic answer_before;
                logic [12:0] h1, h2;
                int count0, n, old_r0;
                h1 = at(21, 27);                // P1 takes slot 0 at (22,27); P2 stays
                h2 = at(58, 27);
                // Put slot 0 right of P1's head, by hand, so that P1 can take it.
                if (gold[nb(h1, 1)] !== 4'd0) fail($sformatf("edge %0d: (22,27) is not EMPTY", k));
                old_r0 = gold_slot(0);
                if (old_r0 >= 0) begin gold[old_r0] = 4'd0; map.cells[old_r0] = 4'd0; end
                gold[nb(h1, 1)] = 4'd8; map.cells[nb(h1, 1)] = 4'd8;
                @(negedge clk);
                prepare = 1'b0; collected = 3'b001;
                old_head_p1 = h1; old_head_p2 = h2; new_head_p1 = nb(h1, 1); new_head_p2 = h2;
                heads_tgl = ~heads_tgl;
                repeat (k) @(posedge clk);
                @(negedge clk) rst = 1'b1;
                answer_before = codes_tgl;
                @(posedge clk); #1;
                if (codes_tgl !== answer_before) fail($sformatf("reset after edge %0d changed the answer", k));
                @(negedge clk) rst = 1'b0;
                cyc = 0;
                while (codes_tgl !== heads_tgl) begin
                    @(posedge clk); #1;
                    if (++cyc > 1000) fail($sformatf("Step not answered after a reset after edge %0d", k));
                end
                repeat (30) begin
                    @(posedge clk); #1;
                    if (codes_tgl !== heads_tgl) fail($sformatf("a second answer after a reset after edge %0d", k));
                end
                gold[h1] = 4'd2; gold[nb(h1, 1)] = 4'd3; gold[h2] = 4'd5;
                count0 = 0;
                for (int a = 0; a < 8192; a++)
                    if (map.cells[a] == 4'd8) begin
                        count0++;
                        if (gold[a] !== 4'd0) fail($sformatf("reset after edge %0d: slot 0 on a Cell holding %0d", k, gold[a]));
                        gold[a] = 4'd8;
                    end
                if (count0 < 1 || count0 > 2) fail($sformatf("reset after edge %0d: slot 0 on %0d Cells", k, count0));
                if (count0 == 2) doubles++; else singles++;
                glfsr = dut.lfsr;               // the cut draws are not modelled; go on from here
                idle_draws = 0;
                expect_nbr($sformatf("Step with a reset after edge %0d", k), nb(h1, 1), h2);
                scan($sformatf("Step with a reset after edge %0d", k));
                // The Prepare arena_link sends after a reset, with the Bikes at h1 and h2.
                prepare_arena($sformatf("Prepare after the reset after edge %0d", k), h1, h2, 1'b1);
                for (int s = 0; s < 3; s++) begin
                    n = 0;
                    for (int a = 0; a < 8192; a++) n += (map.cells[a] == 4'd8 + 4'(s));
                    if (n != 1) fail($sformatf("Prepare after the reset after edge %0d: slot %0d on %0d Cells", k, s, n));
                end
            end
            if (singles == 0 || doubles == 0)
                fail($sformatf("the sweep cut %0d Steps before the Reward write and %0d after; expected both", singles, doubles));
            $display("ok   reset sweep: slot 0 on one Cell after %0d cuts, on two after %0d, one after each Prepare", singles, doubles);
        end

        // Steps back to back: each one is sent on the edge after the previous answer.
        gold_clear();
        prepare_arena("Prepare before back-to-back Steps", at(22, 27), at(57, 27));
        for (int i = 0; i < 3; i++) begin
            request(1'b0, 1'b0, 3'b000, at(22 + i, 27), at(57 - i, 27), at(23 + i, 27), at(56 - i, 27), cyc);
            expect_cycles($sformatf("back-to-back Step %0d", i), cyc, 18);
            gold[at(22 + i, 27)] = 4'd2; gold[at(57 - i, 27)] = 4'd4;
            gold[at(23 + i, 27)] = 4'd3; gold[at(56 - i, 27)] = 4'd5;
            expect_nbr($sformatf("back-to-back Step %0d", i), at(23 + i, 27), at(56 - i, 27));
        end
        scan("after back-to-back Steps");

        // drawcon reads the draw port during a whole Prepare: the result is the same.
        fork
            request(1'b1, 1'b0, 3'b000, 13'd0, 13'd0, p1, p2, cyc);
            repeat (8300) @(negedge clk) draw_addr = 13'($urandom_range(0, 8191));
        join
        gold_clear(); gold[p1] = 4'd3; gold[p2] = 4'd5;
        want = 8208;
        for (int s = 0; s < 3; s++) begin gold_place(s, c); want += c; end
        expect_cycles("Prepare with the draw port busy", cyc, want);
        expect_nbr("Prepare with the draw port busy", p1, p2);
        scan("Prepare with the draw port busy");

        $display("PASS arena_ctrl_tb (%0d checks)", checks);
        $finish;
    end
endmodule
