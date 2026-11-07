// Builder's own check of game_top, mostly from its pins, with sim_clocks/ in place of
// the pixel Wizard; not the official bench of contract section 7. It checks that the
// counter-generated clk_juego (ADR 0006) runs near 60 Hz; its 16.4-16.9 ms window cannot
// tell nearby N apart, so build_game_top.tcl checks N against the XDC. It does not test
// the Wizard itself, lock behaviour, or a CPU_RESET shorter than one clk_juego period.
// Each scenario starts from power-up, so the build runs them at the same time, each in its
// own simulator: xsim game_top_tb -runall -testplusarg scenario=moves_x
// Without +scenario they all run one after another in one simulation.
`timescale 1ns/1ps
module game_top_tb;
    localparam int H_TOTAL = 1680, V_TOTAL = 828;
    localparam real PIX_NS = 11.982;

    logic clk = 1'b0, cpu_resetn = 1'b1;
    logic [11:0] sw = 12'h000;
    logic [4:0] btn = 5'b0;
    logic [3:0] r, g, b;
    logic hs, vs;
    int rises_in_reset = 0;
    realtime last_rise = 0;
    string scenario = "all";

    game_top dut (.clk, .cpu_resetn, .sw, .btn, .vga_r(r), .vga_g(g), .vga_b(b), .vga_hs(hs), .vga_vs(vs));
    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "game_top_tb failed");
    endfunction

    initial begin
        #6s fail("watchdog: the bench did not finish");
    end

    // clk_juego must never stop, in or out of reset: position_logic needs its edges.
    always @(posedge dut.clk_juego) begin
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

    // What the screen must show, written from the specification, not from drawcon.
    function automatic logic [11:0] expected_colour(int x, int y, int bx, int by, logic [11:0] blk);
        if (y >= 64 && (x < 16 || x >= 1264 || y < 80 || y >= 784)) return 12'hFFF;
        if (y < 64) return 12'h444;
        if (x >= bx && x < bx + 16 && y >= by && y < by + 16) return blk;
        return 12'h000;
    endfunction

    // Rebuilds one whole frame from the pins: sync widths, line and frame length,
    // blanking, and the colour of every pixel. The frame starts where vga_vs rises.
    task automatic check_frame(string what, int bx, int by, logic [11:0] blk);
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
                    want = expected_colour(x, y, bx, by, blk);
                end
                if ({r, g, b} !== want)
                    fail($sformatf("%s: pins show %03h, expected %03h at h=%0d v=%0d", what, {r, g, b}, want, h, v));
                @(negedge dut.clk_pix);
            end
        end
        frame_ns = $realtime - t0;
        if (frame_ns < 0.995 * H_TOTAL * V_TOTAL * PIX_NS || frame_ns > 1.005 * H_TOTAL * V_TOTAL * PIX_NS)
            fail($sformatf("%s: frame took %0.0f ns", what, frame_ns));
        $display("ok   %s: whole frame correct, block at (%0d,%0d), colour %03h", what, bx, by, blk);
    endtask

    // Holds a direction, then checks only that axis moved, in the right direction, by
    // about the right amount. The exact step is checked in position_logic_tb.
    task automatic move(string what, logic [4:0] b, int want_dx, int want_dy, logic [11:0] colour);
        int x0 = dut.blkpos_x, y0 = dut.blkpos_y, dx, dy;
        btn = b;
        #100ms;
        btn = 5'b0;
        #60ms;
        dx = int'(dut.blkpos_x) - x0;
        dy = int'(dut.blkpos_y) - y0;
        // 100 ms is 6 ticks, plus or minus one for where the press falls: 20 to 28 px.
        if (dx * want_dx < 20 * want_dx * want_dx || dx * want_dx > 28 * want_dx * want_dx
            || dy * want_dy < 20 * want_dy * want_dy || dy * want_dy > 28 * want_dy * want_dy
            || (want_dx == 0 && dx != 0) || (want_dy == 0 && dy != 0))
            fail($sformatf("%s: moved by (%0d,%0d)", what, dx, dy));
        check_frame(what, dut.blkpos_x, dut.blkpos_y, colour);
    endtask

    task automatic reset_test(int hold_ms);
        int min_rises = hold_ms / 17 - 1;
        // Start the press away from the block's start so a return is visible.
        btn = 5'b01000; #100ms; btn = 5'b0; #60ms;
        if (dut.blkpos_x == 320) fail("buttons did not move the block before reset");
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
        check_frame($sformatf("after a reset of %0d ms", hold_ms), 320, 432, sw);
    endtask

    task automatic colours();
        sw = 12'hF00; #1ms;
        check_frame("red switches", 320, 432, 12'hF00);
        sw = 12'h0A5; #1ms;
        check_frame("mixed switches", 320, 432, 12'h0A5);
    endtask

    task automatic moves_x();
        sw = 12'hFFF; #1ms;
        move("right", 5'b01000,  1,  0, 12'hFFF);
        move("left",  5'b00100, -1,  0, 12'hFFF);
    endtask

    task automatic moves_y();
        sw = 12'hFFF; #1ms;
        move("down",  5'b00010,  0,  1, 12'hFFF);
        move("up",    5'b00001,  0, -1, 12'hFFF);
    endtask

    task automatic resets_short();
        sw = 12'hFFF; #1ms;
        reset_test(50);
        reset_test(100);
    endtask

    task automatic reset_long();
        sw = 12'hFFF; #1ms;
        reset_test(500);
    endtask

    task automatic btnc();
        sw = 12'hFFF; #1ms;
        btn = 5'b10000; #60ms; btn = 5'b0; #40ms;
        check_frame("BTNC centres the block", 632, 392, 12'hFFF);
    endtask

    initial begin
        void'($value$plusargs("scenario=%s", scenario));
        #1 if (dut.blkpos_x !== 11'd320 || dut.blkpos_y !== 11'd432)
            fail($sformatf("power-up position is (%0d,%0d)", dut.blkpos_x, dut.blkpos_y));
        #1ms;
        check_frame("power-up, all switches down: block black", 320, 432, 12'h000);

        case (scenario)
            "colours":      colours();
            "moves_x":      moves_x();
            "moves_y":      moves_y();
            "resets_short": resets_short();
            "reset_long":   reset_long();
            "btnc":         btnc();
            "all": begin
                colours();
                moves_x();
                moves_y();
                resets_short();
                reset_long();
                btnc();
            end
            default: fail($sformatf("unknown scenario %s", scenario));
        endcase

        $display("PASS game_top_tb %s", scenario);
        $finish;
    end
endmodule
