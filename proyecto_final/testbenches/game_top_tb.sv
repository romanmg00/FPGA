// Author: Alan (AIF31). Changes by Roman (romanmg00): frames checked through pos_link, no tearing (X1, #48).
// Rewards (G4, ADR 0012): game_top runs with FIXED_SEED = 1, so every new Match places the
// Rewards from SEED on the Cells prototipos/tron_fpga/model gives: slot 0 (39,32), slot 1 (10,9),
// slot 2 (1,12), clear of the paths the older scenarios drive. The Arena model learns where the
// Rewards are once the codes are valid and checks that they only sit on EMPTY Cells and do not
// move. position_logic does not report a Reward taken yet and drawcon does not draw them (both
// Roman's, proposed in an issue), so a Reward Cell is drawn as empty Arena, and a Bike that
// drives onto one writes its head over it: no Points, and the slot stays empty until the next
// Prepare. rewards drives P1 over slot 0 and checks exactly that.
// Builder's own check of game_top, mostly from its pins, with sim_clocks/ in place of
// the pixel Wizard and sim_models/ in place of bike_rom; not the official bench of contract
// section 7. It checks that the
// counter-generated clk_juego (ADR 0006) runs near 60 Hz; its 16.4-16.9 ms window cannot
// tell nearby N apart, so build_game_top.tcl checks N against the XDC. It does not test
// the Wizard itself, lock behaviour, or a CPU_RESET shorter than one clk_juego period.
//
// The design is two bikes moving on their own in Rounds (PRs #21, #25, #26): BTNC starts a
// Round, P1 turns with the buttons, P2 goes straight unless the uart scenario sends it bytes
// on the uart_rx pin (ADR 0013), a step every STEP_TICKS ticks of clk_juego, a crash ends the Round, and after the 2 s
// pause both bikes go back to their starts. The crash rules themselves are checked in
// position_logic_tb; this bench checks that game_top wires them to the pins.
//
// Bike Cells are read from dut.blkpos1_x/y and dut.blkpos2_x/y; the Round state from
// dut.u_position_logic.run; the step length from u_step_counter's STEP_TICKS. Each bike is a
// 32 x 32 sprite from sprites/bike_synth.coe (PR #35), boxed at its drawn position minus 8 px
// and turned with its heading. The drawn positions, dut.glide1_x/y and dut.glide2_x/y, slide
// toward the Cell over one step (ADR 0010), and glide_check compares the slide with the offsets
// the ADR gives. drawcon gets them through pos_link (X1, issue #30), copied once per frame at
// curr_y = 800: frames taken while the bikes move use dut.draw1_x/y, dut.draw2_x/y and
// dut.draw_heading1/2, and check that they do not change inside the visible area (no tearing).
// SPRITE_SHIFT: how many px to the right drawcon draws each sprite. drawcon reads bike_rom
// (2 cycles) 2 px ahead (issue #30 step 3), so it is 0; before that it was 2, each sprite's
// right-hand columns wrapped to the left edge of its box (PR #35, note 3). The sprite data is
// the .mem build_game_top.tcl makes from the .coe, given with -testplusarg bike_mem=<file>,
// as for sim_models/bike_rom.sv.
// Arena (contract section 3): every visible pixel's Trail colour must match the code drawcon
// received, and that code must come from the pixel's own Cell (dut.arena_addr two cycles
// earlier, port B's latency); Trail pixels with (x + y - 2 frame_cnt) mod 64 < 6 are stripes.
// arena_check compares the whole of arena_map with a Trail model
// kept here from the bike moves: the Cells a bike left are its Trail, its head is a head.
// Match and Scoreboard (G3/G5, ADR 0008): Start reaches round_fsm through match_fsm, so
// press_start waits up to 16 ticks for the Round. The Scoreboard is read from seg and an.
// match plays one Match to its end (P1's Lives set to 1 with force; match_tb plays whole
// Matches on clk_juego alone) and pause checks SW0 and a Start held through CPU_RESETN.
// uart sends P2's keys as 8N1 frames on the uart_rx pin at 115200 baud: Enter starts the
// Round, W and D turn P2, a reversal is ignored, and bytes that are not commands do nothing.
// Each scenario starts from power-up, so the build runs them at the same time, each in its
// own simulator: xsim game_top_tb -runall -testplusarg scenario=steps
// Without +scenario they all run one after another in one simulation.
`timescale 1ns/1ps
module game_top_tb;
    localparam int H_TOTAL = 1680, V_TOTAL = 828;
    localparam real PIX_NS = 11.982;
    localparam real UART_BIT_NS = 1.0e9 / 115200;   // one bit on the uart_rx pin
    // Board buttons: [0] U, [1] D, [2] L, [3] R, [4] centre (Start)
    localparam logic [4:0] B_NONE = 5'b00000, B_U = 5'b00001, B_D = 5'b00010,
                           B_L = 5'b00100, B_R = 5'b01000, B_C = 5'b10000;
    // Start cells (20,27) and (59,27), as top-left pixels (x16), and start headings: P1 right,
    // P2 left (0 up, 1 right, 2 down, 3 left, as heading1/2)
    localparam int P1_X0 = 320, P1_Y0 = 432, P2_X0 = 944, P2_Y0 = 432;
    localparam int P1_H0 = 1, P2_H0 = 3;
    // Colours from the specification and the Python prototype, not read from drawcon. In the
    // sprites (tools/png2coe.py), C_KEY is drawn in the Player's colour and C_CLEAR is transparent.
    localparam logic [11:0] C_WALL = 12'hFFF, C_HUD = 12'h444, C_P1 = 12'h0DF,
                            C_P2 = 12'hF80, C_KEY = 12'h0F0, C_CLEAR = 12'h000;
    // The sun's rows (build_game_top.tcl copies sprites/sun_rows.mem into each bench folder).
    logic [20:0] sun_rows [0:320];
    initial $readmemh("sun_rows.mem", sun_rows);
    // Trail colours: each Player's colour, with pulse stripes in shine(colour)
    localparam logic [11:0] C_T1 = 12'h0DF, C_T2 = 12'hF80;
    // How many pixels late drawcon looks up each sprite (see above); 0 since it reads ahead.
    localparam int SPRITE_SHIFT = 0;

    logic clk = 1'b0, cpu_resetn = 1'b1;
    logic [15:0] sw = 16'h0000;
    logic [4:0] btn = B_NONE;
    logic uart_rx = 1'b1;     // P2's web page; high when idle
    logic [3:0] r, g, b;
    logic hs, vs;
    logic [6:0] seg;
    logic dp;
    logic [7:0] an;
    int prepares = 0;         // Prepares arena_link sent since power-up
    int rises_in_reset = 0;
    realtime last_rise = 0;
    string scenario = "all";
    int STEP;                 // ticks per step, read from the design
    int ticks = 0;            // clk_juego rises since power-up
    int last_step_tick = -1;  // tick of the last step seen; -1 before the first of a Round
    string bike_file;
    logic [11:0] bike_mem [0:1023];  // the sprite pointing up, word {row, column}
    int          rw_cell [0:2];      // where the model knows each Reward slot is; -1 not known,
                                     // -2 a Bike drove over it: absent until the next Prepare
    int          trail_px = 0, stripe_px = 0;  // Trail pixels checked off and on a stripe
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
        e1x[0] <= dut.draw1_x; e1y[0] <= dut.draw1_y; e1h[0] <= dut.draw_heading1;
        e2x[0] <= dut.draw2_x; e2y[0] <= dut.draw2_y; e2h[0] <= dut.draw_heading2;
    end
    // Arena code and port B address, sampled the same way: e_code is the code drawcon used
    // for the pins' pixel, and e_addr[2] the address it was read with, two cycles earlier.
    logic [3:0]  e_code;
    logic [12:0] e_addr [0:2];
    always @(posedge dut.clk_pix) begin
        e_code    <= dut.arena_code;
        e_addr[2] <= e_addr[1];
        e_addr[1] <= e_addr[0];
        e_addr[0] <= dut.arena_addr;
    end
    // Arena model: what arena_map must hold after the last step's writes.
    logic [3:0] arena_want [0:8191];

    game_top #(.FIXED_SEED(1'b1)) dut (.clk, .cpu_resetn, .sw, .btn, .uart_rx, .vga_r(r), .vga_g(g), .vga_b(b), .vga_hs(hs), .vga_vs(vs),
                  .seg, .dp, .an);
    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "game_top_tb failed");
    endfunction

    // The longest scenario (head_on) takes about 5.5 s of simulated time; all of them, 20 s.
    initial begin
        #30s fail("watchdog: the bench did not finish");
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

    always @(posedge dut.clk_juego)
        if (dut.u_arena_link.send_prepare === 1'b1) prepares++;

    // What drawcon receives from pos_link is never unknown once rst_pix is low, in every scenario
    // and from power-up: the 70 ms wait below would otherwise hide it. rst_pix starts high
    // (board_reset_sync), so this starts with the first clk_pix edges.
    always @(dut.rst_pix, dut.draw1_x, dut.draw1_y, dut.draw2_x, dut.draw2_y, dut.draw_heading1, dut.draw_heading2)
        if (dut.rst_pix === 1'b0 && $isunknown({dut.draw1_x, dut.draw1_y, dut.draw2_x, dut.draw2_y,
                                                dut.draw_heading1, dut.draw_heading2}))
            fail($sformatf("at %0.3f ms with rst_pix low, pos_link gives drawcon unknown values: P1 (%0d,%0d) P2 (%0d,%0d)",
                           $realtime / 1e6, dut.draw1_x, dut.draw1_y, dut.draw2_x, dut.draw2_y));

    // frame_cnt advances by one per frame; the first frame after a pixel reset is not compared.
    int prev_frame_cnt = -1;
    always @(posedge vs or posedge dut.rst_pix)
        if (dut.rst_pix !== 1'b0) prev_frame_cnt = -1;
        else begin
            if (prev_frame_cnt >= 0 && dut.u_drawcon.frame_cnt !== 5'(prev_frame_cnt + 1))
                fail($sformatf("at %0.3f ms frame_cnt went from %0d to %0d in one frame",
                               $realtime / 1e6, prev_frame_cnt, dut.u_drawcon.frame_cnt));
            prev_frame_cnt = dut.u_drawcon.frame_cnt;
        end

    task automatic wait_ticks(int n);
        repeat (n) @(posedge dut.clk_juego);
        #1;
    endtask

    // Active-low pins {a, ..., g} to the character they show, from sevenseg's glyphs (as
    // seg7_driver_tb); "?" if none matches.
    function automatic byte glyph(logic [6:0] pins);
        case (~pins)       // abcdefg, 1 = lit
            7'b1111110: return "0";   7'b0110000: return "1";   7'b1101101: return "2";
            7'b1111001: return "3";   7'b0110011: return "4";   7'b1011011: return "5";
            7'b1011111: return "6";   7'b1110000: return "7";   7'b1111111: return "8";
            7'b1111011: return "9";   7'b1100111: return "P";   7'b0001110: return "L";
            7'b1011110: return "G";   7'b1110111: return "A";   7'b0000000: return " ";
            default:    return "?";
        endcase
    endfunction

    // Reads the eight digits from the pins, an[7] (left) first: each is sampled in the middle
    // of its turn in the scan, while its anode alone is low. The decimal point stays off.
    task automatic expect_scoreboard(string what, string expected);
        string got = "????????";
        logic [7:0] lit;
        realtime t0;
        for (int k = 0; k < 8; k++) begin
            lit = ~(8'b00000001 << k);                // digit k alone
            t0 = $realtime;
            while (an !== lit) begin
                @(an);
                if ($realtime - t0 > 30ms) fail($sformatf("%s: digit %0d never lit alone (an = %b)", what, k, an));
            end
            #20us;
            if (an !== lit) fail($sformatf("%s: digit %0d lit for less than 20 us", what, k));
            if (dp !== 1'b1) fail($sformatf("%s: the decimal point is on", what));
            got[7 - k] = glyph({seg[0], seg[1], seg[2], seg[3], seg[4], seg[5], seg[6]});
        end
        if (got != expected) fail($sformatf("%s: the Scoreboard shows \"%s\", expected \"%s\"", what, got, expected));
        $display("ok   %s: the Scoreboard shows \"%s\"", what, got);
    endtask

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

    // Pulse stripe colour (juego/fx.py shine): c/4 + CCC per channel.
    function automatic logic [11:0] shine(logic [11:0] c);
        return ((c >> 2) & 12'h333) + 12'hCCC;
    endfunction

    // What the screen must show, written from the specification and PR #35's sprite format,
    // not from drawcon. Walls cover the HUD's lower edge; P1 is drawn over P2 if they ever
    // overlap. Sprite words 000 are transparent (tools/png2coe.py): the pixel shows P2, then
    // the empty Arena. (bNx, bNy) place each 32 x 32 box; its word is looked up SPRITE_SHIFT
    // pixels earlier on the same line, with the drawn position (sNx, sNy) and heading sNh.
    // stripe_phase is the frame's (2 frame_cnt) mod 64.
    function automatic logic [11:0] expected_colour(int x, int y,
            int b1x, int b1y, int s1x, int s1y, int s1h,
            int b2x, int b2y, int s2x, int s2y, int s2h, logic [3:0] code, logic [11:0] line_col, int stripe_phase);
        logic [11:0] w;
        logic [20:0] w21;
        if (y >= 64 && (x < 16 || x >= 1264 || y < 80 || y >= 784)) return C_WALL;
        if (y < 64) return C_HUD;
        if (x >= b1x - 8 && x < b1x + 24 && y >= b1y - 8 && y < b1y + 24) begin
            w = sprite_word(x - SPRITE_SHIFT, y, s1x, s1y, s1h);
            if (w != C_CLEAR) return w == C_KEY ? C_P1 : w;
        end
        if (x >= b2x - 8 && x < b2x + 24 && y >= b2y - 8 && y < b2y + 24) begin
            w = sprite_word(x - SPRITE_SHIFT, y, s2x, s2y, s2h);
            if (w != C_CLEAR) return w == C_KEY ? C_P2 : w;
        end
        // Rewards (codes 8-10) are not drawn yet: empty Arena.
        // Trails only; heads are not painted. Stripes: (x + y - 2 frame) mod 64 < 6.
        if (code == 4'd2) return (x + y + 64 - stripe_phase) % 64 < 6 ? shine(C_T1) : C_T1;
        if (code == 4'd4) return (x + y + 64 - stripe_phase) % 64 < 6 ? shine(C_T2) : C_T2;
        if (x % 32 == 0 || y % 32 == 0) return line_col; // violet grid every 32 px (prototype's look)
        // Sky gradient (prototype's sunset sky, 001 at the top to 506 at the bottom): six
        // 128 px bands counted from y = 64, so each band edge lies under a grid line; blue is
        // always red + 1. The 1 px glow on each side of a line is the sky 3 steps brighter.
        if (x % 32 == 1 || x % 32 == 31 || y % 32 == 1 || y % 32 == 31)
            return {4'((y - 64) / 128 + 3), 4'h0, 4'((y - 64) / 128 + 4)};
        // Striped sun under the grid: radius 160 centred at (640, 432), one word per row of
        // sprites/sun_rows.mem from y = 272, {lit, half width, colour}; lit = 0 is a stripe.
        if (y >= 272 && y <= 592) begin
            w21 = sun_rows[y - 272];
            if (w21[20] && x >= 640 - int'(w21[19:12]) && x < 640 + int'(w21[19:12])) return w21[11:0];
        end
        return {4'((y - 64) / 128), 4'h0, 4'((y - 64) / 128 + 1)};
    endfunction

    // Rebuilds one whole frame from the pins: sync widths, line and frame length,
    // blanking, and the colour of every pixel. The frame starts where vga_vs rises.
    // With live = 1 the expected sprites follow the drawn positions and headings pixel by
    // pixel, so the check also holds while the bikes slide or turn. Static frames are all at
    // the starts, so they use the start headings.
    task automatic check_frame(string what, int p1x, int p1y, int p2x, int p2y, bit live = 1'b0);
        realtime t0, frame_ns;
        logic [11:0] want, want_alt;
        logic [11:0] line_col;     // this frame's grid line colour, taken from its first line pixel
        bit          line_seen;    // line_col holds this frame's colour
        int x, y;
        logic [47:0] first_draw;   // drawn positions and headings at the first visible pixel
        int          stripe_phase; // this frame's (2 frame_cnt) mod 64
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
        line_seen = 1'b0;
        for (int v = 0; v < V_TOTAL; v++) begin
            for (int h = 0; h < H_TOTAL; h++) begin
                if (hs !== (h >= 136)) fail($sformatf("%s: vga_hs=%b at h=%0d v=%0d", what, hs, h, v));
                if (vs !== (v < 3)) fail($sformatf("%s: vga_vs=%b at h=%0d v=%0d", what, vs, h, v));
                want = 12'h000;
                if (h >= 336 && h < 1616 && v >= 27 && v < 827) begin
                    x = h - 336;
                    y = v - 27;
                    if (e_addr[2] !== {6'(y >> 4), 7'(x >> 4)})
                        fail($sformatf("%s: Arena read for pixel (%0d,%0d) used address %h, expected Cell (%0d,%0d)",
                                       what, x, y, e_addr[2], x >> 4, y >> 4));
                    if (x == 0 && y == 0) begin
                        first_draw = {e1x[0], e1y[0], e2x[0], e2y[0], e1h[0], e2h[0]};
                        stripe_phase = (2 * dut.u_drawcon.frame_cnt) % 64;
                    end else if ({e1x[0], e1y[0], e2x[0], e2y[0], e1h[0], e2h[0]} !== first_draw)
                        fail($sformatf("%s: drawn positions changed inside the frame at (%0d,%0d) (tearing)", what, x, y));
                    // The grid line pulses (818, A2C, D2E, A2C, 8 frames each), so its colour is not
                    // known ahead: a pixel is on a line when the expected colour depends on line_col.
                    // The first line pixel of the frame must be one of the pulse colours, and every
                    // other line pixel of the same frame must match it (no change mid-frame).
                    for (int k = 0; k < 2; k++) begin
                        if (live)
                            want = expected_colour(x, y,
                                e1x[0], e1y[0], e1x[SPRITE_SHIFT], e1y[SPRITE_SHIFT], e1h[SPRITE_SHIFT],
                                e2x[0], e2y[0], e2x[SPRITE_SHIFT], e2y[SPRITE_SHIFT], e2h[SPRITE_SHIFT], e_code,
                                k ? 12'hFFF : 12'h000, stripe_phase);
                        else
                            want = expected_colour(x, y, p1x, p1y, p1x, p1y, P1_H0,
                                                   p2x, p2y, p2x, p2y, P2_H0, e_code, k ? 12'hFFF : 12'h000, stripe_phase);
                        if (k == 0) want_alt = want;
                    end
                    if (want != want_alt) begin
                        if (!line_seen) begin
                            if (!({r, g, b} inside {12'h818, 12'hA2C, 12'hD2E}))
                                fail($sformatf("%s: grid line shows %03h, not a pulse colour, at h=%0d v=%0d", what, {r, g, b}, h, v));
                            line_col = {r, g, b};
                            line_seen = 1'b1;
                        end
                        want = line_col;
                    end
                    if (want == C_T1 || want == C_T2) trail_px++;
                    if (want == shine(C_T1) || want == shine(C_T2)) stripe_px++;
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

    // Where the Rewards are, read from arena_map once the codes are valid (the Arena is not
    // being written then). Each slot is on at most one Cell, which the model holds EMPTY; a slot
    // the model knows has not moved; a slot just prepared is on a Cell, and one a Bike drove
    // over stays absent (nobody reports it taken, so arena_ctrl does not place it again).
    task automatic learn_rewards(string what);
        int found [0:2];
        found = '{-1, -1, -1};
        for (int a = 0; a < 8192; a++)
            if (dut.u_arena_map.cells[a] >= 4'd8 && dut.u_arena_map.cells[a] <= 4'd10) begin
                int sl = dut.u_arena_map.cells[a] - 4'd8;
                if (found[sl] != -1) fail($sformatf("%s: Reward slot %0d on two Cells", what, sl));
                if (arena_want[a] !== 4'd0)
                    fail($sformatf("%s: Reward slot %0d on Cell (%0d,%0d), which holds %0d",
                                   what, sl, a % 128, a / 128, arena_want[a]));
                found[sl] = a;
            end
        for (int sl = 0; sl < 3; sl++) begin
            if (rw_cell[sl] == -2) begin
                if (found[sl] != -1)
                    fail($sformatf("%s: Reward slot %0d is back at (%0d,%0d), but nobody reported it taken",
                                   what, sl, found[sl] % 128, found[sl] / 128));
                continue;
            end
            if (found[sl] == -1) fail($sformatf("%s: Reward slot %0d is missing", what, sl));
            if (rw_cell[sl] != -1 && found[sl] != rw_cell[sl])
                fail($sformatf("%s: Reward slot %0d moved from (%0d,%0d) to (%0d,%0d) without being taken", what, sl,
                               rw_cell[sl] % 128, rw_cell[sl] / 128, found[sl] % 128, found[sl] / 128));
            rw_cell[sl] = found[sl];
        end
    endtask

    // Arena after a Prepare: EMPTY on cx 1..78, cy 5..48, WALL elsewhere, heads at the bikes.
    // The three Rewards are learnt when the Prepare's codes are valid.
    task automatic arena_model_prepare();
        rw_cell = '{-1, -1, -1};
        for (int a = 0; a < 8192; a++)
            arena_want[a] = ((a % 128) >= 1 && (a % 128) <= 78 && (a / 128) >= 5 && (a / 128) <= 48) ? 4'd0 : 4'd1;
        arena_want[(dut.blkpos1_y / 16) * 128 + dut.blkpos1_x / 16] = 4'd3;
        arena_want[(dut.blkpos2_y / 16) * 128 + dut.blkpos2_x / 16] = 4'd5;
    endtask

    // Once codes_valid says the last step's request was answered, the whole Arena must match.
    task automatic arena_check(string what);
        int waited = 0;
        while (dut.codes_valid !== 1'b1) begin
            @(posedge dut.clk_juego);
            #1;
            if (++waited > 6) fail($sformatf("%s: codes_valid did not come back", what));
        end
        learn_rewards(what);
        for (int a = 0; a < 8192; a++)
            if (a != rw_cell[0] && a != rw_cell[1] && a != rw_cell[2] && dut.u_arena_map.cells[a] !== arena_want[a])
                fail($sformatf("%s: Arena Cell (%0d,%0d) holds %0d, expected %0d",
                               what, a % 128, a / 128, dut.u_arena_map.cells[a], arena_want[a]));
        $display("ok   %s: the whole Arena matches the Trail model; Rewards at (%0d,%0d) (%0d,%0d) (%0d,%0d)", what,
                 rw_cell[0] % 128, rw_cell[0] / 128, rw_cell[1] % 128, rw_cell[1] / 128, rw_cell[2] % 128, rw_cell[2] / 128);
    endtask

    // Holds BTNC until the Round runs, then releases it: the synchroniser, match_fsm and
    // round_fsm take up to 10 ticks (new Match: match_fsm waits for its Prepare's codes) or 4
    // (next Round). A new Match's Arena is prepared after Start; a next Round's was prepared
    // when the bikes went back to their starts.
    task automatic press_start();
        int waited = 0;
        btn = B_C;
        while (dut.u_position_logic.run !== 1'b1) begin
            @(posedge dut.clk_juego);
            #1;
            if (++waited > 16) fail("BTNC did not start the Round within 16 ticks");
        end
        btn = B_NONE;
        arena_model_prepare();
        last_step_tick = -1;
    endtask

    // Waits for the next clk_juego edge where a bike moves or the Round stops, and checks
    // how far each bike moved (in cells) and, after the first step of a Round, that the
    // step came exactly STEP ticks after the previous one. Returns 1 if the Round stopped.
    // While it waits, the Rewards are learnt once the codes are valid; a bike that moves onto
    // one writes its head over it, and the slot stays absent (run_over counts them).
    int run_over = 0;
    task automatic next_step(string what, int dx1, int dy1, int dx2, int dy2, output logic crashed);
        int x1 = dut.blkpos1_x, y1 = dut.blkpos1_y, x2 = dut.blkpos2_x, y2 = dut.blkpos2_y;
        int nx1, ny1, nx2, ny2;
        int waited = 0;
        bit learned = 1'b0;
        do begin
            if (!learned && dut.codes_valid === 1'b1) begin
                learn_rewards(what);
                learned = 1'b1;
            end
            @(posedge dut.clk_juego);
            #1;
            if (++waited > 3 * STEP) fail($sformatf("%s: no step within %0d ticks", what, 3 * STEP));
        end while (dut.blkpos1_x == x1 && dut.blkpos1_y == y1 && dut.blkpos2_x == x2
                   && dut.blkpos2_y == y2 && dut.u_position_logic.run === 1'b1);
        if (!learned) fail($sformatf("%s: the step came without valid codes", what));
        crashed = (dut.u_position_logic.run !== 1'b1);
        if (last_step_tick >= 0 && ticks - last_step_tick != STEP)
            fail($sformatf("%s: step came %0d ticks after the previous one, expected %0d",
                           what, ticks - last_step_tick, STEP));
        last_step_tick = ticks;
        // Copied to ints first: XSim 2025.2 evaluated int'(dut.blkpos1_x) - x1 here as 0 - x1.
        nx1 = dut.blkpos1_x; ny1 = dut.blkpos1_y; nx2 = dut.blkpos2_x; ny2 = dut.blkpos2_y;
        // A bike that moved onto a Reward writes its head over it; nobody reports it taken yet.
        for (int sl = 0; sl < 3; sl++) begin
            if ((nx1 != x1 || ny1 != y1) && rw_cell[sl] == (ny1 / 16) * 128 + nx1 / 16) begin
                run_over++;
                rw_cell[sl] = -2;
                $display("ok   %s: P1 drives over Reward slot %0d", what, sl);
            end
            if ((nx2 != x2 || ny2 != y2) && rw_cell[sl] == (ny2 / 16) * 128 + nx2 / 16) begin
                run_over++;
                rw_cell[sl] = -2;
                $display("ok   %s: P2 drives over Reward slot %0d", what, sl);
            end
        end
        // Arena model: a bike that moved leaves its Trail; its new Cell is its head.
        if (nx1 != x1 || ny1 != y1) begin
            arena_want[(y1 / 16) * 128 + x1 / 16] = 4'd2;
            arena_want[(ny1 / 16) * 128 + nx1 / 16] = 4'd3;
        end
        if (nx2 != x2 || ny2 != y2) begin
            arena_want[(y2 / 16) * 128 + x2 / 16] = 4'd4;
            arena_want[(ny2 / 16) * 128 + nx2 / 16] = 4'd5;
        end
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
        sw = 16'h0FFF; #1ms;
        check_frame("switches up: same colours", P1_X0, P1_Y0, P2_X0, P2_Y0);
    endtask

    // BTNC starts the Round; both bikes move one cell on the same edge, every STEP ticks, and
    // their sprites slide between Cells.
    task automatic steps();
        press_start();
        for (int i = 1; i <= 5; i++) step_ok($sformatf("step %0d", i), 1, 0, -1, 0);
        expect_at("after 5 steps", P1_X0 + 5 * 16, P1_Y0, P2_X0 - 5 * 16, P2_Y0);
        check_frame_here("moving, between steps 5 and 6");
        arena_check("after 5 steps");
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
        arena_check("after the turns");
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
        arena_check("head-on crash");
        #1s;
        expect_at("1 s into the crash pause", 39 * 16, P1_Y0, 40 * 16, P2_Y0);
        #1.2s;
        expect_at("after the crash pause", P1_X0, P1_Y0, P2_X0, P2_Y0);
        if (dut.u_position_logic.run !== 1'b0) fail("a new Round started without Start");
        check_frame("back at the starts", P1_X0, P1_Y0, P2_X0, P2_Y0);
        press_start();
        step_ok("new Round, step 1", 1, 0, -1, 0);
        arena_check("new Round: the old Trails are gone");
    endtask

    // P1 drives up into the top Wall: on the crash step it stays at row 5 (y = 80), P2 stays
    // too because a Crash stops both Bikes (ADR 0011), and the Round ends.
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
        next_step("into the Wall", 0, 0, 0, 0, crashed);
        if (!crashed) fail("P1 did not crash into the top Wall");
        check_frame_here("P1 crashed into the top Wall");
        arena_check("P1 crashed into the top Wall");
    endtask

    // One Match to its end, read from the Scoreboard pins. P1's Lives are set to 1, so its
    // first Crash ends the Match: P1 turns up, left, down and right into its own Trail.
    task automatic match_scenario();
        logic crashed;
        int prep;
        expect_scoreboard("power-up", "P200P100");
        sw[14] = 1'b1;                               // Goal 20: while waiting, the Goal view
        wait_ticks(5);
        expect_scoreboard("waiting, SW14 up", "G0AL  20");   // the O is the 0 glyph
        sw[14] = 1'b0;
        press_start();
        expect_scoreboard("new Match", "P200P100");
        @(negedge dut.clk_juego);
        force dut.u_score_unit.lives_p1 = 2'd1;
        @(posedge dut.clk_juego);
        #1;
        release dut.u_score_unit.lives_p1;
        btn = B_U;
        step_ok("U", 0, -1, -1, 0);
        btn = B_L;
        step_ok("L", -1, 0, -1, 0);
        btn = B_D;
        step_ok("D", 0, 1, -1, 0);
        btn = B_R;
        next_step("R: into its own Trail", 0, 0, 0, 0, crashed);
        btn = B_NONE;
        if (!crashed) fail("P1 did not crash into its own Trail");
        if (dut.u_score_unit.match_over !== 1'b1) fail("P1's last Life did not end the Match");
        arena_check("P1 out");
        wait_ticks(2);
        expect_scoreboard("P1 out, P2 +3", "P203P100");
        prep = prepares;
        #2.2s;
        expect_at("after the Crash display, Match over", 19 * 16, P1_Y0, P2_X0 - 3 * 16, P2_Y0);
        if (dut.u_position_logic.run !== 1'b0) fail("a Round runs after the Match ended");
        if (dut.u_match_fsm.state !== 3'd4) fail($sformatf("match_fsm in state %0d, expected 4 (G_MATCH)", dut.u_match_fsm.state));
        if (prepares != prep) fail("a Prepare at the end of the Match");
        arena_check("Match over: the Arena is kept");
        force dut.u_seg7_view.view = 2'd1;           // Lives, without waiting 3 s for the view
        wait_ticks(2);
        expect_scoreboard("Match over, Lives view", "L203L100");
        release dut.u_seg7_view.view;
        press_start();
        if (prepares != prep + 1) fail($sformatf("%0d Prepares for the new Match, expected 1", prepares - prep));
        expect_at("new Match", P1_X0, P1_Y0, P2_X0, P2_Y0);
        expect_scoreboard("new Match", "P200P100");
        step_ok("new Match, step 1", 1, 0, -1, 0);
        arena_check("new Match: the old Trails are gone");
    endtask

    // SW0 holds the Round: no Step and no turn while paused, and the Scoreboard keeps showing.
    // Then a Start held through CPU_RESETN starts nothing until released and pressed again.
    task automatic pause_scenario();
        press_start();
        step_ok("before Pause", 1, 0, -1, 0);
        sw[0] = 1'b1;
        btn = B_U;                                   // a turn pressed while paused is not kept
        wait_ticks(5 * STEP);
        expect_at("paused for 5 Steps", P1_X0 + 16, P1_Y0, P2_X0 - 16, P2_Y0);
        if (dut.u_position_logic.run !== 1'b1) fail("Pause ended the Round");
        expect_scoreboard("paused", "P200P100");
        btn = B_NONE;
        wait_ticks(3);
        sw[0] = 1'b0;
        last_step_tick = -1;
        step_ok("after Pause: straight on", 1, 0, -1, 0);
        step_ok("after Pause", 1, 0, -1, 0);

        cpu_resetn = 1'b0;
        btn = B_C;
        #60ms;
        cpu_resetn = 1'b1;
        wait_ticks(10);
        if (dut.u_position_logic.run !== 1'b0 || dut.u_match_fsm.state !== 3'd0)
            fail("a Start held through CPU_RESETN started a Match");
        $display("ok   a Start held through CPU_RESETN starts nothing");
        btn = B_NONE;
        wait_ticks(3);
        press_start();
        step_ok("released and pressed again", 1, 0, -1, 0);
    endtask

    // P1 drives down 5 Cells and right 19 onto Reward slot 0 at (39,32) while P2 goes left along
    // row 27. Until position_logic reports Rewards taken, the Bike's head replaces the Reward:
    // no Points, slot 0 stays absent, and slots 1 and 2 stay where they are.
    task automatic rewards_scenario();
        int r0 = 32 * 128 + 39;
        press_start();
        arena_check("new Match");                    // learns where the Prepare put them
        if (rw_cell[0] != r0 || rw_cell[1] != 9 * 128 + 10 || rw_cell[2] != 12 * 128 + 1)
            fail($sformatf("Rewards at (%0d,%0d) (%0d,%0d) (%0d,%0d); the model puts them at (39,32) (10,9) (1,12)",
                           rw_cell[0] % 128, rw_cell[0] / 128, rw_cell[1] % 128, rw_cell[1] / 128,
                           rw_cell[2] % 128, rw_cell[2] / 128));
        $display("ok   Rewards at (39,32) (10,9) (1,12), as the model");
        btn = B_D;
        for (int i = 1; i <= 5; i++) step_ok($sformatf("down %0d", i), 0, 1, -1, 0);
        btn = B_R;
        for (int i = 1; i <= 18; i++) step_ok($sformatf("right %0d", i), 1, 0, -1, 0);
        btn = B_NONE;
        step_ok("right 19: over slot 0", 1, 0, -1, 0);
        // SW0 holds the game while the checks below run: they take longer than one Step.
        sw[0] = 1'b1;
        if (run_over != 1 || rw_cell[0] != -2) fail($sformatf("%0d Rewards driven over, expected slot 0 only", run_over));
        wait_ticks(1);
        if (dut.points_p1 !== 6'd0 || dut.points_p2 !== 6'd0)
            fail($sformatf("Points %0d-%0d after driving over slot 0, expected 0-0", dut.points_p1, dut.points_p2));
        arena_check("slot 0 driven over");
        if (dut.u_arena_map.cells[r0] !== 4'd3) fail("P1's head is not on (39,32)");
        $display("ok   slot 0 under P1's head, no Points, not placed again; slots 1 and 2 stay");
        check_frame_here("P1 on slot 0's Cell");
        expect_at("paused on slot 0", 39 * 16, 32 * 16, 35 * 16, P2_Y0);
        sw[0] = 1'b0;
        last_step_tick = -1;
        step_ok("one more Step", 1, 0, -1, 0);
        arena_check("after one more Step");
    endtask

    task automatic resets_short();
        reset_test(50);
        reset_test(100);
    endtask

    task automatic reset_long();
        reset_test(500);
    endtask

    // One byte from P2's web page on the uart_rx pin: start bit, 8 data bits LSB first, stop
    // bit, at 115200 baud (87 us).
    task automatic uart_send(logic [7:0] data);
        uart_rx = 1'b0;
        #(UART_BIT_NS);
        for (int i = 0; i < 8; i++) begin
            uart_rx = data[i];
            #(UART_BIT_NS);
        end
        uart_rx = 1'b1;
        #(UART_BIT_NS);
    endtask

    // P2 turns back under its own Trail from the web page, as on the board on 23 November:
    // left 4 Cells, s (down one), d (right), then right 3 Cells along the row just below its
    // Trail. The Cell ahead is always empty, so none of those Steps may Crash; then w turns it
    // up into its Trail, which must.
    task automatic uart_uturn();
        int waited = 0;
        uart_send(8'h0D);                            // Enter: Start
        while (dut.u_position_logic.run !== 1'b1) begin
            @(posedge dut.clk_juego);
            #1;
            if (++waited > 16) fail("Enter did not start the Round within 16 ticks");
        end
        arena_model_prepare();
        last_step_tick = -1;
        for (int i = 1; i <= 4; i++) step_ok($sformatf("P2 left %0d", i), 1, 0, -1, 0);
        uart_send("s");
        step_ok("s: P2 down one", 1, 0, 0, 1);
        uart_send("d");
        step_ok("d: P2 right, under its Trail", 1, 0, 1, 0);
        for (int i = 2; i <= 4; i++) step_ok($sformatf("P2 right %0d under its Trail", i), 1, 0, 1, 0);
        // P2 is now under the first Cell of its Trail, (59, 27). w turns it up into that Trail:
        // a Crash. In a Crash Step no Bike moves (ADR 0011), so P2's Heading, and its sprite,
        // still face right.
        uart_send("w");
        begin
            logic crashed;
            next_step("w: P2 up into its Trail", 0, 0, 0, 0, crashed);
            if (!crashed) fail("w into P2's own Trail did not Crash");
        end
        if (dut.lives_p2 !== 2'd2 || dut.lives_p1 !== 2'd3)
            fail($sformatf("after P2's Crash Lives are P1 %0d, P2 %0d; expected 3 and 2", dut.lives_p1, dut.lives_p2));
        if (dut.heading2 !== 2'd1) fail($sformatf("after the Crash P2's Heading is %0d, expected 1 (right)", dut.heading2));
        check_frame_here("P2 crashed under its own Trail");
        arena_check("after the Crash");
        $display("ok   w under its own Trail: P2 Crashes, and its sprite still faces right");
    endtask

    // P2 plays from the web page (ADR 0013). Bytes that are not commands start nothing; Enter
    // (CR) starts the Round; W turns P2 up, an uppercase S (its reverse) is ignored, D turns
    // it right, and Space during the Round does nothing. P1 keeps going right. Each byte is
    // sent just after a step, and must act at the next one, 8 ticks later.
    task automatic uart_scenario();
        int waited = 0;
        uart_send("x");
        uart_send(8'h0A);                            // LF: not a command
        wait_ticks(10);
        if (dut.u_position_logic.run !== 1'b0) fail("a byte that is not a command started the Round");
        uart_send(8'h0D);                            // Enter: Start
        while (dut.u_position_logic.run !== 1'b1) begin
            @(posedge dut.clk_juego);
            #1;
            if (++waited > 16) fail("Enter did not start the Round within 16 ticks");
        end
        arena_model_prepare();
        last_step_tick = -1;
        step_ok("P2 straight", 1, 0, -1, 0);
        uart_send("w");
        step_ok("w: P2 turns up", 1, 0, 0, -1);
        check_frame_here("P2 heading up");
        uart_send("S");                              // reverse of Up: ignored
        step_ok("S while heading up: ignored", 1, 0, 0, -1);
        uart_send("D");
        step_ok("D: P2 turns right", 1, 0, 1, 0);
        uart_send(" ");                              // Space while the Round runs
        step_ok("Space while the Round runs", 1, 0, 1, 0);
        check_frame_here("P2 heading right");
        arena_check("after P2's turns");
    endtask

    initial begin
        void'($value$plusargs("scenario=%s", scenario));
        STEP = dut.u_position_logic.u_step_counter.STEP_TICKS;
        $display("STEP_TICKS = %0d", STEP);
        $display("SPRITE_SHIFT = %0d (sprites drawn %0d px to the right)", SPRITE_SHIFT, SPRITE_SHIFT);
        if (!$value$plusargs("bike_mem=%s", bike_file))
            fail("no sprite data: run xsim with -testplusarg bike_mem=<file>.mem");
        $readmemh(bike_file, bike_mem);
        rw_cell = '{-1, -1, -1};
        foreach (bike_mem[i])
            if ($isunknown(bike_mem[i])) fail($sformatf("%s does not fill sprite word %0d", bike_file, i));
        // board_reset_sync starts asserted, so the first clk_juego edge (about 8 ms) puts the
        // bikes at their starts; the Round waits for Start. pos_link carries the starts to
        // drawcon on the next clk_juego tick and the next curr_y = 800 after it, up to two
        // frames later, so the first frame is checked after that.
        #70ms;
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
            "match":        match_scenario();
            "pause":        pause_scenario();
            "rewards":      rewards_scenario();
            "uart":         uart_scenario();
            "uart_uturn":   uart_uturn();
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
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                match_scenario();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                pause_scenario();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                rewards_scenario();
                cpu_resetn = 1'b0; #60ms; cpu_resetn = 1'b1; #60ms;
                uart_scenario();
            end
            default: fail($sformatf("unknown scenario %s", scenario));
        endcase

        // Scenarios that draw Trails must check some on a stripe.
        if (scenario inside {"steps", "turns", "head_on", "wall_crash", "rewards", "uart", "uart_uturn", "all"}
                && stripe_px == 0)
            fail($sformatf("%0d Trail pixels checked, none on a pulse stripe", trail_px));
        $display("ok   %0d Trail pixels checked on a pulse stripe, %0d off it", stripe_px, trail_px);
        $display("PASS game_top_tb %s", scenario);
        $finish;
    end
endmodule
