// Builder's own check of game_top, mostly from its pins, with sim_clocks/ in place of
// the pixel Wizard and sim_models/ in place of bike_rom; not the official bench of contract
// section 7. It checks that the
// counter-generated clk_juego (ADR 0006) runs near 60 Hz; its 16.4-16.9 ms window cannot
// tell nearby N apart, so build_game_top.tcl checks N against the XDC. It does not test
// the Wizard itself, lock behaviour, or a CPU_RESET shorter than one clk_juego period.
//
// The design is two bikes moving on their own in Rounds (PRs #21, #25, #26): BTNC starts a
// Round, P1 turns with the buttons, P2 goes straight because game_top ties turn_req2 to 0,
// a step every STEP_TICKS ticks of clk_juego, a crash ends the Round, and after the 2 s
// pause both bikes go back to their starts. The crash rules themselves are checked in
// position_logic_tb; this bench checks that game_top wires them to the pins.
//
// Bike Cells are read from dut.blkpos1_x/y and dut.blkpos2_x/y; the Round state from
// dut.u_position_logic.run; the step length from u_step_counter's STEP_TICKS. Each bike is a
// 32 x 32 sprite from sprites/bike_synth.coe (PR #35), boxed at its drawn position minus 8 px
// and turned with its heading. The drawn positions, dut.glide1_x/y and dut.glide2_x/y, slide
// toward the Cell over one step (ADR 0010): frames taken while the bikes move use those and
// dut.heading1/2, and glide_check compares the slide with the offsets the ADR gives.
// Known deviation, SPRITE_SHIFT: drawcon reads bike_rom (2 cycles) without reading ahead, so
// each sprite is drawn SPRITE_SHIFT px to the right, its right-hand columns wrapped to the
// left edge of its box (PR #35, note 3). The bench expects that image; set SPRITE_SHIFT to 0
// once drawcon reads ahead. The sprite data is the .mem build_game_top.tcl makes from the
// .coe, given with -testplusarg bike_mem=<file>, as for sim_models/bike_rom.sv.
// Each scenario starts from power-up, so the build runs them at the same time, each in its
// own simulator: xsim game_top_tb -runall -testplusarg scenario=steps
// Without +scenario they all run one after another in one simulation.
`timescale 1ns/1ps
module game_top_tb;
    localparam int H_TOTAL = 1680, V_TOTAL = 828;
    localparam real PIX_NS = 11.982;
    // Board buttons: [0] U, [1] D, [2] L, [3] R, [4] centre (Start)
    localparam logic [4:0] B_NONE = 5'b00000, B_U = 5'b00001, B_D = 5'b00010,
                           B_L = 5'b00100, B_R = 5'b01000, B_C = 5'b10000;
    // Start cells (20,27) and (59,27), as top-left pixels (x16), and start headings: P1 right,
    // P2 left (0 up, 1 right, 2 down, 3 left, as heading1/2)
    localparam int P1_X0 = 320, P1_Y0 = 432, P2_X0 = 944, P2_Y0 = 432;
    localparam int P1_H0 = 1, P2_H0 = 3;
    // Colours from the specification and the Python prototype, not read from drawcon. C_KEY is
    // the sprite colour drawn in the Player's colour (PR #35).
    localparam logic [11:0] C_WALL = 12'hFFF, C_HUD = 12'h444, C_P1 = 12'h0DF,
                            C_P2 = 12'hF80, C_EMPTY = 12'h000, C_KEY = 12'h0F0;
    // Known deviation (see above): how many pixels late drawcon looks up each sprite.
    localparam int SPRITE_SHIFT = 2;

    logic clk = 1'b0, cpu_resetn = 1'b1;
    logic [11:0] sw = 12'h000;
    logic [4:0] btn = B_NONE;
    logic [3:0] r, g, b;
    logic hs, vs;
    int rises_in_reset = 0;
    realtime last_rise = 0;
    string scenario = "all";
    int STEP;                 // ticks per step, read from the design
    int ticks = 0;            // clk_juego rises since power-up
    int last_step_tick = -1;  // tick of the last step seen; -1 before the first of a Round
    string bike_file;
    logic [11:0] bike_mem [0:1023];  // the sprite pointing up, word {row, column}
    // Drawn positions and headings as drawcon sees them, one entry per clk_pix cycle. After a
    // clk_pix edge, entry 0 holds the cycle whose colour vga_out just put on the pins, and
    // entry n the cycle n earlier: boxes use entry 0, sprite lookups entry SPRITE_SHIFT.
    logic [10:0] e1x [0:SPRITE_SHIFT], e1y [0:SPRITE_SHIFT], e2x [0:SPRITE_SHIFT], e2y [0:SPRITE_SHIFT];
    logic [1:0]  e1h [0:SPRITE_SHIFT], e2h [0:SPRITE_SHIFT];
    always @(posedge dut.clk_pix) begin
        for (int i = SPRITE_SHIFT; i > 0; i--) begin
            e1x[i] <= e1x[i-1]; e1y[i] <= e1y[i-1]; e1h[i] <= e1h[i-1];
            e2x[i] <= e2x[i-1]; e2y[i] <= e2y[i-1]; e2h[i] <= e2h[i-1];
        end
        e1x[0] <= dut.glide1_x; e1y[0] <= dut.glide1_y; e1h[0] <= dut.heading1;
        e2x[0] <= dut.glide2_x; e2y[0] <= dut.glide2_y; e2h[0] <= dut.heading2;
    end

    game_top dut (.clk, .cpu_resetn, .sw, .btn, .vga_r(r), .vga_g(g), .vga_b(b), .vga_hs(hs), .vga_vs(vs));
    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "game_top_tb failed");
    endfunction

    // The longest scenario (head_on) takes about 5.5 s of simulated time; all of them, 15 s.
    initial begin
        #20s fail("watchdog: the bench did not finish");
    end

    // clk_juego must never stop, in or out of reset: position_logic needs its edges.
    always @(posedge dut.clk_juego) begin
        ticks++;
        if (!cpu_resetn) rises_in_reset++;
        if (last_rise != 0 && ($realtime - last_rise < 16.4e6 || $realtime - last_rise > 16.9e6))
            fail($sformatf("clk_juego period is %0.0f ns, expected about 16.67 ms", $realtime - last_rise));
        last_rise = $realtime;
    end
    initial begin
        #20ms;
        forever begin
            #1ms;
            if ($realtime - last_rise > 17e6) fail("clk_juego stopped");
        end
    end

    // Sprite word at screen pixel (x, y) for a box placed by drawn position (px, py), with
    // heading h. Offsets in the box wrap at 32; right, down and left turn the sprite 90, 180
    // and 270 degrees clockwise, as PR #35 describes.
    function automatic logic [11:0] sprite_word(int x, int y, int px, int py, int h);
        int ox = (x + 8 - px) & 31;
        int oy = (y + 8 - py) & 31;
        case (h)
            0:       return bike_mem[32 * oy + ox];
            1:       return bike_mem[32 * (31 - ox) + oy];
            2:       return bike_mem[32 * (31 - oy) + 31 - ox];
            default: return bike_mem[32 * ox + 31 - oy];
        endcase
    endfunction

    // What the screen must show, written from the specification and PR #35's sprite format,
    // not from drawcon. Walls cover the HUD's lower edge; P1 is drawn over P2 if they ever
    // overlap, black sprite pixels included (no transparency yet). (bNx, bNy) place each
    // 32 x 32 box; its word is looked up SPRITE_SHIFT pixels earlier on the same line, with
    // the drawn position (sNx, sNy) and heading sNh of that pixel.
    function automatic logic [11:0] expected_colour(int x, int y,
            int b1x, int b1y, int s1x, int s1y, int s1h,
            int b2x, int b2y, int s2x, int s2y, int s2h);
        logic [11:0] w;
        if (y >= 64 && (x < 16 || x >= 1264 || y < 80 || y >= 784)) return C_WALL;
        if (y < 64) return C_HUD;
        if (x >= b1x - 8 && x < b1x + 24 && y >= b1y - 8 && y < b1y + 24) begin
            w = sprite_word(x - SPRITE_SHIFT, y, s1x, s1y, s1h);
            return w == C_KEY ? C_P1 : w;
        end
        if (x >= b2x - 8 && x < b2x + 24 && y >= b2y - 8 && y < b2y + 24) begin
            w = sprite_word(x - SPRITE_SHIFT, y, s2x, s2y, s2h);
            return w == C_KEY ? C_P2 : w;
        end
        return C_EMPTY;
    endfunction

    // Rebuilds one whole frame from the pins: sync widths, line and frame length,
    // blanking, and the colour of every pixel. The frame starts where vga_vs rises.
    // With live = 1 the expected sprites follow the drawn positions and headings pixel by
    // pixel, so the check also holds while the bikes slide or turn. Static frames are all at
    // the starts, so they use the start headings.
    task automatic check_frame(string what, int p1x, int p1y, int p2x, int p2y, bit live = 1'b0);
        realtime t0, frame_ns;
        logic [11:0] want;
        int x, y;
        // A dead raster fails here, not at the bench's overall watchdog.
        fork
            @(posedge vs);
            begin
                #20ms;
                fail($sformatf("%s: vga_vs did not rise within one frame", what));
            end
        join_any
        disable fork;
        @(negedge dut.clk_pix);
        t0 = $realtime;
        for (int v = 0; v < V_TOTAL; v++) begin
            for (int h = 0; h < H_TOTAL; h++) begin
                if (hs !== (h >= 136)) fail($sformatf("%s: vga_hs=%b at h=%0d v=%0d", what, hs, h, v));
                if (vs !== (v < 3)) fail($sformatf("%s: vga_vs=%b at h=%0d v=%0d", what, vs, h, v));
                want = 12'h000;
                if (h >= 336 && h < 1616 && v >= 27 && v < 827) begin
                    x = h - 336;
                    y = v - 27;
                    if (live)
                        want = expected_colour(x, y,
                            e1x[0], e1y[0], e1x[SPRITE_SHIFT], e1y[SPRITE_SHIFT], e1h[SPRITE_SHIFT],
                            e2x[0], e2y[0], e2x[SPRITE_SHIFT], e2y[SPRITE_SHIFT], e2h[SPRITE_SHIFT]);
                    else
                        want = expected_colour(x, y, p1x, p1y, p1x, p1y, P1_H0,
                                               p2x, p2y, p2x, p2y, P2_H0);
                end
                if ({r, g, b} !== want)
                    fail($sformatf("%s: pins show %03h, expected %03h at h=%0d v=%0d", what, {r, g, b}, want, h, v));
                @(negedge dut.clk_pix);
            end
        end
        frame_ns = $realtime - t0;
        if (frame_ns < 0.995 * H_TOTAL * V_TOTAL * PIX_NS || frame_ns > 1.005 * H_TOTAL * V_TOTAL * PIX_NS)
            fail($sformatf("%s: frame took %0.0f ns", what, frame_ns));
        if (live) $display("ok   %s: whole frame correct at the drawn positions", what);
        else $display("ok   %s: whole frame correct, P1 at (%0d,%0d), P2 at (%0d,%0d)", what, p1x, p1y, p2x, p2y);
    endtask

    // Checks the frame at the bikes' drawn positions, which may be sliding.
    task automatic check_frame_here(string what);
        check_frame(what, 0, 0, 0, 0, 1'b1);
    endtask

    // ADR 0010: after a one-Cell step the drawn position has covered round(16 t / STEP) px t ticks later.
    function automatic int glide_offset(int t);
        return (16 * t + STEP / 2) / STEP;
    endfunction

    // Called right after next_step saw a step of (dx1,dy1) for P1 and (dx2,dy2) for P2: the
    // drawn positions stay on the old Cells until the next tick, then slide one offset per tick
    // and reach the new Cells exactly STEP ticks after the step.
    task automatic glide_check(string what, int dx1, int dy1, int dx2, int dy2);
        int o1x, o1y, o2x, o2y, g1x, g1y, g2x, g2y;
        o1x = dut.blkpos1_x; o1y = dut.blkpos1_y; o2x = dut.blkpos2_x; o2y = dut.blkpos2_y;
        o1x -= 16 * dx1; o1y -= 16 * dy1; o2x -= 16 * dx2; o2y -= 16 * dy2;
        for (int t = 0; t <= STEP; t++) begin
            if (t > 0) begin
                @(posedge dut.clk_juego);
                #1;
            end
            g1x = dut.glide1_x; g1y = dut.glide1_y; g2x = dut.glide2_x; g2y = dut.glide2_y;
            if (g1x != o1x + dx1 * glide_offset(t) || g1y != o1y + dy1 * glide_offset(t)
                || g2x != o2x + dx2 * glide_offset(t) || g2y != o2y + dy2 * glide_offset(t))
                fail($sformatf("%s, tick %0d: drawn P1 (%0d,%0d) P2 (%0d,%0d); expected P1 (%0d,%0d) P2 (%0d,%0d)",
                               what, t, g1x, g1y, g2x, g2y, o1x + dx1 * glide_offset(t),
                               o1y + dy1 * glide_offset(t), o2x + dx2 * glide_offset(t), o2y + dy2 * glide_offset(t)));
        end
        $display("ok   %s: both bikes slid one Cell in %0d ticks", what, STEP);
    endtask

    task automatic expect_at(string what, int p1x, int p1y, int p2x, int p2y);
        if (dut.blkpos1_x !== 11'(p1x) || dut.blkpos1_y !== 11'(p1y)
            || dut.blkpos2_x !== 11'(p2x) || dut.blkpos2_y !== 11'(p2y))
            fail($sformatf("%s: P1 at (%0d,%0d), P2 at (%0d,%0d); expected P1 (%0d,%0d), P2 (%0d,%0d)",
                           what, dut.blkpos1_x, dut.blkpos1_y, dut.blkpos2_x, dut.blkpos2_y,
                           p1x, p1y, p2x, p2y));
    endtask

    // Presses BTNC long enough to pass the 2-flip-flop synchroniser, then releases it.
    task automatic press_start();
        btn = B_C;
        #60ms;
        btn = B_NONE;
        if (dut.u_position_logic.run !== 1'b1) fail("BTNC did not start the Round");
        last_step_tick = -1;
    endtask

    // Waits for the next clk_juego edge where a bike moves or the Round stops, and checks
    // how far each bike moved (in cells) and, after the first step of a Round, that the
    // step came exactly STEP ticks after the previous one. Returns 1 if the Round stopped.
    task automatic next_step(string what, int dx1, int dy1, int dx2, int dy2, output logic crashed);
        int x1 = dut.blkpos1_x, y1 = dut.blkpos1_y, x2 = dut.blkpos2_x, y2 = dut.blkpos2_y;
        int nx1, ny1, nx2, ny2;
        int waited = 0;
        do begin
            @(posedge dut.clk_juego);
            #1;
            if (++waited > 3 * STEP) fail($sformatf("%s: no step within %0d ticks", what, 3 * STEP));
        end while (dut.blkpos1_x == x1 && dut.blkpos1_y == y1 && dut.blkpos2_x == x2
                   && dut.blkpos2_y == y2 && dut.u_position_logic.run === 1'b1);
        crashed = (dut.u_position_logic.run !== 1'b1);
        if (last_step_tick >= 0 && ticks - last_step_tick != STEP)
            fail($sformatf("%s: step came %0d ticks after the previous one, expected %0d",
                           what, ticks - last_step_tick, STEP));
        last_step_tick = ticks;
        // Copied to ints first: XSim 2025.2 evaluated int'(dut.blkpos1_x) - x1 here as 0 - x1.
        nx1 = dut.blkpos1_x; ny1 = dut.blkpos1_y; nx2 = dut.blkpos2_x; ny2 = dut.blkpos2_y;
        if (nx1 - x1 != 16 * dx1 || ny1 - y1 != 16 * dy1 || nx2 - x2 != 16 * dx2 || ny2 - y2 != 16 * dy2)
            fail($sformatf("%s: P1 moved (%0d,%0d) px and P2 (%0d,%0d) px; expected (%0d,%0d) and (%0d,%0d) cells",
                           what, nx1 - x1, ny1 - y1, nx2 - x2, ny2 - y2, dx1, dy1, dx2, dy2));
    endtask

    // A step in which neither bike may crash.
    task automatic step_ok(string what, int dx1, int dy1, int dx2, int dy2);
        logic crashed;
        next_step(what, dx1, dy1, dx2, dy2, crashed);
        if (crashed) fail($sformatf("%s: the Round stopped", what));
    endtask

    task automatic reset_test(int hold_ms);
        int min_rises = hold_ms / 17 - 1;
        // Move the bikes away from their starts so a return is visible.
        press_start();
        step_ok("before reset", 1, 0, -1, 0);
        step_ok("before reset", 1, 0, -1, 0);
        cpu_resetn = 1'b0;
        rises_in_reset = 0;
        // Watch a whole frame's worth of pixels, so this cannot land only on black pixels.
        #10ms;
        repeat (H_TOTAL * V_TOTAL) begin
            @(negedge dut.clk_pix);
            if ({r, g, b} !== 12'h000) fail("colour pins are not black during reset");
            if (hs !== 1'b0 || vs !== 1'b1) fail("the raster keeps running during reset");
        end
        #((hold_ms - 27) * 1ms);
        cpu_resetn = 1'b1;
        if (rises_in_reset < min_rises)
            fail($sformatf("reset of %0d ms: only %0d clk_juego rises, expected at least %0d", hold_ms, rises_in_reset, min_rises));
        #60ms;
        expect_at($sformatf("after a reset of %0d ms", hold_ms), P1_X0, P1_Y0, P2_X0, P2_Y0);
        if (dut.u_position_logic.run !== 1'b0) fail("the Round runs after reset without Start");
        check_frame($sformatf("after a reset of %0d ms", hold_ms), P1_X0, P1_Y0, P2_X0, P2_Y0);
    endtask

    // Without Start the bikes wait at their starts, and the switches change nothing.
    task automatic idle();
        #300ms;
        expect_at("no Start for 300 ms", P1_X0, P1_Y0, P2_X0, P2_Y0);
        sw = 12'hFFF; #1ms;
        check_frame("switches up: same colours", P1_X0, P1_Y0, P2_X0, P2_Y0);
    endtask

    // BTNC starts the Round; both bikes move one cell on the same edge, every STEP ticks, and
    // their sprites slide between Cells.
    task automatic steps();
        press_start();
        for (int i = 1; i <= 5; i++) step_ok($sformatf("step %0d", i), 1, 0, -1, 0);
        expect_at("after 5 steps", P1_X0 + 5 * 16, P1_Y0, P2_X0 - 5 * 16, P2_Y0);
        check_frame_here("moving, between steps 5 and 6");
        step_ok("step 6", 1, 0, -1, 0);
        glide_check("step 6", 1, 0, -1, 0);
    endtask

    // P1 turns with the buttons; a reversal is ignored; P2 keeps going straight. Frames show
    // P1 heading right and then down (up is in wall_crash, left is P2).
    task automatic turns();
        press_start();
        btn = B_L;                                   // reverse of RIGHT: ignored
        step_ok("L held while heading right", 1, 0, -1, 0);
        step_ok("L held while heading right", 1, 0, -1, 0);
        btn = B_U;
        step_ok("U: turn up", 0, -1, -1, 0);
        btn = B_D;                                   // reverse of UP: ignored
        step_ok("D held while heading up", 0, -1, -1, 0);
        btn = B_NONE;
        step_ok("released: keeps going up", 0, -1, -1, 0);
        btn = B_R;
        step_ok("R: turn right", 1, 0, -1, 0);
        btn = B_NONE;
        check_frame_here("after the turns");
        btn = B_D;
        step_ok("D: turn down", 0, 1, -1, 0);
        btn = B_NONE;
        check_frame_here("heading down");
    endtask

    // The bikes meet head-on: on step 20 each aims at the other's head, both stop, and the
    // Round ends. They stay put for the 2 s pause, then both go back to their starts and a
    // new Start runs a new Round.
    task automatic head_on();
        logic crashed;
        press_start();
        for (int i = 1; i <= 19; i++) step_ok($sformatf("step %0d", i), 1, 0, -1, 0);
        next_step("step 20: head-on", 0, 0, 0, 0, crashed);
        if (!crashed) fail("step 20: the bikes did not crash head-on");
        expect_at("head-on crash", 39 * 16, P1_Y0, 40 * 16, P2_Y0);
        check_frame_here("head-on crash");
        #1s;
        expect_at("1 s into the crash pause", 39 * 16, P1_Y0, 40 * 16, P2_Y0);
        #1.2s;
        expect_at("after the crash pause", P1_X0, P1_Y0, P2_X0, P2_Y0);
        if (dut.u_position_logic.run !== 1'b0) fail("a new Round started without Start");
        check_frame("back at the starts", P1_X0, P1_Y0, P2_X0, P2_Y0);
        press_start();
        step_ok("new Round, step 1", 1, 0, -1, 0);
    endtask

    // P1 drives up into the top Wall: on the crash step it stays at row 5 (y = 80) while P2
    // completes its step, and the Round ends.
    task automatic wall_crash();
        logic crashed;
        int rows;
        press_start();
        btn = B_U;
        step_ok("U: turn up", 0, -1, -1, 0);
        btn = B_NONE;
        rows = (P1_Y0 - 80) / 16 - 1;                // steps left until row 5
        for (int i = 1; i <= rows; i++) step_ok($sformatf("up %0d", i), 0, -1, -1, 0);
        if (dut.blkpos1_y !== 11'd80) fail($sformatf("P1 at y=%0d, expected 80", dut.blkpos1_y));
        next_step("into the Wall", 0, 0, -1, 0, crashed);
        if (!crashed) fail("P1 did not crash into the top Wall");
        check_frame_here("P1 crashed into the top Wall");
    endtask

    task automatic resets_short();
        reset_test(50);
        reset_test(100);
    endtask

    task automatic reset_long();
        reset_test(500);
    endtask

    initial begin
        void'($value$plusargs("scenario=%s", scenario));
        STEP = dut.u_position_logic.u_step_counter.STEP_TICKS;
        $display("STEP_TICKS = %0d", STEP);
        $display("SPRITE_SHIFT = %0d (known deviation: sprites drawn %0d px to the right)", SPRITE_SHIFT, SPRITE_SHIFT);
        if (!$value$plusargs("bike_mem=%s", bike_file))
            fail("no sprite data: run xsim with -testplusarg bike_mem=<file>.mem");
        $readmemh(bike_file, bike_mem);
        foreach (bike_mem[i])
            if ($isunknown(bike_mem[i])) fail($sformatf("%s does not fill sprite word %0d", bike_file, i));
        // board_reset_sync starts asserted, so the first clk_juego edge (about 8 ms) puts the
        // bikes at their starts; the Round waits for Start.
        #20ms;
        expect_at("power-up", P1_X0, P1_Y0, P2_X0, P2_Y0);
        if (dut.u_position_logic.run !== 1'b0) fail("the Round runs at power-up without Start");
        check_frame("power-up", P1_X0, P1_Y0, P2_X0, P2_Y0);

        case (scenario)
            "idle":         idle();
            "steps":        steps();
            "turns":        turns();
            "head_on":      head_on();
            "wall_crash":   wall_crash();
            "resets_short": resets_short();
            "reset_long":   reset_long();
            "all": begin
                idle();
                steps();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                turns();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                head_on();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                wall_crash();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                resets_short();
                reset_long();
            end
            default: fail($sformatf("unknown scenario %s", scenario));
        endcase

        $display("PASS game_top_tb %s", scenario);
        $finish;
    end
endmodule
