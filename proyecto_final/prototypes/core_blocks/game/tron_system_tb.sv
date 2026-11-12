// tron_system_tb: end-to-end smoke test of the playable core through its
// board-facing pins: bouncy buttons, serial 8N1 UART frames, switches, the
// VGA pixel stream and the multiplexed 7-segment display. Expected values come
// from the agreed specification and contract (start Cells and Headings, one
// Cell per Step, Turns, Pause, a Wall Crash costing a Life and giving the
// other Player the +3 Survival Bonus, the Crash display, then the ready wait),
// not from the model.
//
// Scaling: CLK_PIX_HZ = 1.152 MHz in the RTL parameters makes a UART bit 10
// clk_pix cycles and the 1 ms debounce 1152 cycles; one game tick is
// TICK_CYCLES clk_pix cycles instead of ~1.39 M. A frame is still 1680 x 828
// cycles, so pixel checks run while paused.
// Owner: Alan, the builder's own check (not an official contract §7 bench).
// Domains: clk_pix and clk_juego, as in tron_system.sv. PROVISIONAL (ADR 0005).
module tron_system_tb;
    import game_pkg::*;
    parameter bit QUALIFIED = 1'b0;
    parameter bit RSP_REG = 1'b0;
    parameter integer STEP_TICKS = game_pkg::STEP_TICKS;
    // -g DUMP_FRAMES=1 writes whole frames (one RGB444 word per line, row by
    // row) to frame-*.hex in the run folder, for tools/hdl_frame_to_png.py.
    parameter bit DUMP_FRAMES = 1'b0;
    localparam integer TICK_CYCLES = 40000;
    localparam integer HZ = 1152000;                 // 10 cycles per UART bit at 115200
    localparam integer BIT = 10;

    logic clk_pix = 0, clk_juego = 0, rst_pix = 1, rst_game = 1, uart_rx = 1;
    logic [4:0] btn = 0;
    logic [15:0] sw = 0;
    logic [3:0] vga_r, vga_g, vga_b;
    logic vga_hs, vga_vs;
    logic [6:0] seg;
    logic [7:0] an;
    logic [15:0] led;
    always #6 clk_pix = !clk_pix;
    always #(TICK_CYCLES * 6 + 1) clk_juego = !clk_juego;

    tron_system #(.QUALIFIED(QUALIFIED), .RSP_REG(RSP_REG), .STEP_TICKS(STEP_TICKS), .CLK_PIX_HZ(HZ), .DEBOUNCE_MS(1), .WINDOW(TICK_CYCLES / 2), .FIXED_SEED(1'b1)) dut (
        .clk_pix, .clk_juego, .rst_pix, .rst_game, .btn, .sw, .uart_rx,
        .vga_r, .vga_g, .vga_b, .vga_hs, .vga_vs, .seg, .an, .led);

    integer errors = 0;
    task automatic check(input bit ok, input string what);
        if (!ok) begin errors++; $error("CHECK FAILED: %s", what); end
        else $display("ok: %s", what);
    endtask

    // --- VGA monitor: output-raster position from the sync pulses ----------
    // hsync falls when the output shows hcnt 0; vsync rises with line 0.
    integer hc = 0, line = 0;
    logic hs_d = 1, vs_d = 0;
    always @(posedge clk_pix) begin
        hs_d <= vga_hs; vs_d <= vga_vs;
        if (hs_d && !vga_hs) begin
            hc <= 1;
            line <= (!vs_d && vga_vs) ? 0 : line + 1;
        end else hc <= hc + 1;
    end
    // Colour shown at output pixel (x, y), 0..1279 x 0..799.
    // hc/line hold the raster position of the current cycle (hc = hcnt), so the
    // pins are sampled at the falling edge in the middle of that cycle.
    task automatic pixel(input integer x, input integer y, output logic [11:0] rgb);
        @(negedge clk_pix iff (line == 27 + y && hc == 336 + x));
        rgb = {vga_r, vga_g, vga_b};
    endtask
    task automatic cell_rgb(input integer cx, input integer cy, output logic [11:0] rgb);
        pixel(cx * 16 + 8, cy * 16 + 8, rgb);
    endtask
    // One whole frame from the pins, if DUMP_FRAMES (call while paused).
    task automatic dump_frame(input string name);
        integer fd;
        if (DUMP_FRAMES) begin
            fd = $fopen(name, "w");
            for (int y = 0; y < 800; y++) begin
                @(negedge clk_pix iff (line == 27 + y && hc == 336));
                for (int x = 0; x < 1280; x++) begin
                    if (x > 0) @(negedge clk_pix);
                    $fwrite(fd, "%03h\n", {vga_r, vga_g, vga_b});
                end
            end
            $fclose(fd);
            $display("ok: wrote %s", name);
        end
    endtask

    // --- board inputs --------------------------------------------------------
    task automatic uart_send(input logic [7:0] b);
        uart_rx = 0; repeat (BIT) @(posedge clk_pix);
        for (int i = 0; i < 8; i++) begin uart_rx = b[i]; repeat (BIT) @(posedge clk_pix); end
        uart_rx = 1; repeat (BIT * 2) @(posedge clk_pix);
    endtask
    task automatic press(input integer bit_i);          // bounce, hold 3 ms, bounce
        for (int i = 0; i < 6; i++) begin btn[bit_i] = !btn[bit_i]; repeat (37) @(posedge clk_pix); end
        btn[bit_i] = 1; repeat (3 * HZ / 1000) @(posedge clk_pix);
        for (int i = 0; i < 6; i++) begin btn[bit_i] = !btn[bit_i]; repeat (41) @(posedge clk_pix); end
        btn[bit_i] = 0; repeat (2 * HZ / 1000) @(posedge clk_pix);
    endtask
    task automatic ticks(input integer n);
        repeat (n) @(posedge clk_juego);
    endtask
    task automatic wait_phase(input logic [2:0] p, input integer max_ticks);
        integer t = 0;
        while (led[2:0] != p && t < max_ticks) begin @(posedge clk_juego); t++; end
        check(led[2:0] == p, $sformatf("phase %0d reached within %0d ticks", p, max_ticks));
    endtask
    task automatic pause(input bit on);
        sw[0] = on;
        ticks(4);                                    // 2-FF in game_core + snapshot latch
        // drawcon latches Bike positions once per frame (~35 ticks here): let a
        // frame start after Pause so sprite checks see the paused positions.
        if (on) @(posedge vga_vs);
        if (on) check(led[3] == 1'b1, "paused");
        else check(led[3] == 1'b0, "running again");
    endtask

    // --- 7-segment decode ----------------------------------------------------
    function automatic string glyph(input logic [6:0] s);
        case (~s)
            7'b0111111: return "0"; 7'b0000110: return "1"; 7'b1011011: return "2";
            7'b1001111: return "3"; 7'b1100110: return "4"; 7'b1101101: return "5";
            7'b1111101: return "6"; 7'b0000111: return "7"; 7'b1111111: return "8";
            7'b1101111: return "9"; 7'b1110011: return "P"; 7'b0111000: return "L";
            7'b0111101: return "G"; 7'b1110111: return "A"; 7'b0000000: return " ";
            default: return "?";
        endcase
    endfunction
    task automatic read_display(output string text);
        string d[8];
        int seen = 0;
        while (seen != 8'hFF) begin
            @(posedge clk_pix);
            for (int i = 0; i < 8; i++)
                if (an == ~(8'd1 << i) && !seen[i]) begin
                    repeat (50) @(posedge clk_pix);  // settle inside the digit slot
                    if (an == ~(8'd1 << i)) begin d[i] = glyph(seg); seen[i] = 1; end
                end
        end
        text = {d[7], d[6], d[5], d[4], d[3], d[2], d[1], d[0]};
    endtask

    function automatic string expect_points();
        return $sformatf("P2%02dP1%02d", dut.u_game.points_p2, dut.u_game.points_p1);
    endfunction
    function automatic string expect_lives();
        return $sformatf("L2%02dL1%02d", dut.u_game.lives_p2, dut.u_game.lives_p1);
    endfunction

    // --- sprite expectations, from the art and the Design Plan's bike_addr ----
    localparam logic [11:0] C_WALL = 12'h000, C_TUBE = 12'hF4D, C_GLOW = 12'h726, C_P1 = 12'h0FF, C_P2 = 12'hF80,
        C_P1_TRAIL = 12'h0AA, C_P2_TRAIL = 12'hA50, C_REWARD3 = 12'hC8F;
    logic [11:0] bike_mem [0:1023];
    logic [11:0] star_mem [0:255];
    logic [11:0] sky_lut [0:63];
    logic [20:0] sun_lut [0:320];
    logic [11:0] grid_lut [0:3];
    initial begin
        $readmemh("src/prototypes/core_blocks/game/sprites/bike-synth-32.mem", bike_mem);
        $readmemh("src/prototypes/core_blocks/game/sprites/reward-neon-star-16.mem", star_mem);
        $readmemh("src/prototypes/core_blocks/game/sprites/synthwave-sky.mem", sky_lut);
        $readmemh("src/prototypes/core_blocks/game/sprites/synthwave-sun.mem", sun_lut);
        $readmemh("src/prototypes/core_blocks/game/sprites/synthwave-grid.mem", grid_lut);
    end
    // Empty Arena pixel (x, y) at animation phase ph, as juego/fx.py build_base
    // (synthwave): sky, sun (radius 160 at (640, 432)), stars, neon grid, the
    // Arena-edge glow. Tables from tools/make_bg_luts.py; the rest from fx.py.
    function automatic logic [11:0] bg_at(input integer x, y, input logic [1:0] ph);
        logic [11:0] c;
        logic [20:0] row;
        integer hx, hy, h, w;
        bit sun;
        c = sky_lut[y / 16];
        sun = 0;
        if (y >= 272 && y <= 592) begin
            row = sun_lut[y - 272]; w = row[19:12];
            if (row[20] && x >= 640 - w && x < 640 + w) begin sun = 1; c = row[11:0]; end
        end
        hx = x / 2; hy = y / 2;
        h = (((hx * 'h2C9 + 7) ^ (hy * 'h1F3 + hx / 8)) * 'h3B) % 65536;
        if ((h / 32) % 512 == 0 && !sun) c = ((h / 4) % 4 == ph) ? 12'h667 : 12'hCCF;
        if (x % 32 == 1 || x % 32 == 31 || y % 32 == 1 || y % 32 == 31) c = 12'h304;
        if (x % 32 == 0 || y % 32 == 0) c = grid_lut[ph];
        if (x == 16 || x == 1263 || y == 80 || y == 783) c = C_GLOW;
        return c;
    endfunction
    task automatic bg_pixel(input integer x, y, output logic [11:0] rgb, output logic [11:0] want);
        pixel(x, y, rgb);
        want = bg_at(x, y, dut.u_draw.frame_cnt[4:3]);
    endtask
    // ROM word for Bike-local pixel (dx, dy) of art pointing UP (juego/sprites.py rom_address).
    function automatic logic [11:0] bike_texel(input logic [1:0] h, input integer dx, dy);
        integer row, col;
        case (h)
            DIR_UP:    begin row = dy;      col = dx;      end
            DIR_DOWN:  begin row = 31 - dy; col = 31 - dx; end
            DIR_RIGHT: begin row = 31 - dx; col = dy;      end
            default:   begin row = dx;      col = 31 - dy; end
        endcase
        return bike_mem[row * 32 + col];
    endfunction
    // Read the 32 output pixels of the row through a Bike's centre in one frame
    // and compare every opaque texel with the expected (tinted) art.
    task automatic check_bike(input logic [12:0] head, input logic [1:0] dir,
                              input logic [11:0] colour, input string who);
        logic [11:0] got [0:31];
        logic [11:0] tex;
        integer x0, y, drawn, matched;
        x0 = head[6:0] * 16 - 8;
        y = head[12:7] * 16 - 8 + 16;
        for (int u = 0; u < 32; u++) pixel(x0 + u, y, got[u]);
        drawn = 0; matched = 0;
        for (int u = 0; u < 32; u++) begin
            tex = bike_texel(dir, u, 16);
            if (tex != 12'h000) begin
                drawn++;
                if (got[u] == ((tex == 12'h0F0) ? colour : tex)) matched++;
            end
        end
        check(drawn > 0 && matched == drawn,
              $sformatf("%s sprite row at (%0d,%0d) heading %0d: %0d/%0d opaque texels", who,
                        head[6:0], head[12:7], dir, matched, drawn));
    endtask
    task automatic check_star(input logic [12:0] star_cell);
        logic [11:0] got [0:15];
        logic [11:0] tex;
        integer drawn, matched;
        for (int u = 0; u < 16; u++) pixel(star_cell[6:0] * 16 + u, star_cell[12:7] * 16 + 8, got[u]);
        drawn = 0; matched = 0;
        for (int u = 0; u < 16; u++) begin
            tex = star_mem[8 * 16 + u];
            if (tex != 12'h000) begin
                drawn++;
                if (got[u] == ((tex == 12'h0F0) ? C_REWARD3 : tex)) matched++;
            end
        end
        check(drawn > 0 && matched == drawn, $sformatf("+3 Reward sprite row: %0d/%0d opaque texels", matched, drawn));
    endtask

    // --- the test ------------------------------------------------------------
    logic [11:0] rgb, want;
    logic [12:0] h1, h2;
    integer k, m;
    string disp;
    initial begin
        ticks(3);                                    // stretched reset across game edges
        rst_game = 0;
        @(posedge clk_pix) rst_pix = 0;
        ticks(2);

        // Idle screen: border, Wall ring, HUD band, empty Arena, no Bikes yet.
        pixel(5, 5, rgb);       check(rgb == 12'hFFF, "border pixel (5,5) white");
        pixel(1275, 400, rgb);  check(rgb == 12'hFFF, "border pixel (1275,400) white");
        cell_rgb(40, 4, rgb);   check(rgb == C_WALL, "Wall row cy=4 black");
        // Neon Wall (juego/fx.py _neon_wall): Arena = x 16..1263, y 80..783.
        // Outside it 2 px tube then 2 px glow, then black Wall; 1 px glow on its edge.
        pixel(640, 76, rgb);    check(rgb == C_GLOW, "top Wall: outer glow (y 76)");
        pixel(640, 78, rgb);    check(rgb == C_TUBE, "top Wall: tube (y 78)");
        pixel(640, 79, rgb);    check(rgb == C_TUBE, "top Wall: tube (y 79)");
        pixel(640, 80, rgb);    check(rgb == C_GLOW, "Arena top edge glow (y 80)");
        bg_pixel(640, 81, rgb, want);  check(rgb == want, $sformatf("Arena inside the edge (y 81): %h, background %h", rgb, want));
        pixel(11, 400, rgb);    check(rgb == C_WALL, "left Wall black (x 11)");
        pixel(13, 400, rgb);    check(rgb == C_GLOW, "left Wall: outer glow (x 13)");
        pixel(15, 400, rgb);    check(rgb == C_TUBE, "left Wall: tube (x 15)");
        pixel(16, 400, rgb);    check(rgb == C_GLOW, "Arena left edge glow (x 16)");
        pixel(1263, 400, rgb);  check(rgb == C_GLOW, "Arena right edge glow (x 1263)");
        pixel(1264, 400, rgb);  check(rgb == C_TUBE, "right Wall: tube (x 1264)");
        pixel(1267, 400, rgb);  check(rgb == C_GLOW, "right Wall: outer glow (x 1267)");
        pixel(1268, 400, rgb);  check(rgb == C_WALL, "right Wall black (x 1268)");
        pixel(640, 785, rgb);   check(rgb == C_TUBE, "bottom Wall: tube (y 785)");
        pixel(640, 786, rgb);   check(rgb == C_GLOW, "bottom Wall: outer glow (y 786)");
        pixel(640, 789, rgb);   check(rgb == C_WALL, "bottom Wall black above the border (y 789)");
        bg_pixel(20 * 16 + 8, 27 * 16 + 8, rgb, want);  check(rgb == want, "no Bike before Start");
        // Background (fx.py build_base): sky, a star, the sun, a cut stripe, grid
        // line and glow, at the frame's animation phase.
        for (int i = 0; i < 12; i++) begin
            case (i)
                0: begin m = 33; k = 95; end
                1: begin m = 100; k = 120; end    // sky
                2: begin m = 1000; k = 150; end
                3: begin m = 200; k = 260; end
                4: begin m = 481; k = 300; end    // grid glow
                5: begin m = 640; k = 300; end    // sun, upper half
                6: begin m = 480; k = 416; end    // grid crossing on the sun
                7: begin m = 500; k = 432; end    // sun's left side
                8: begin m = 800; k = 470; end
                9: begin m = 640; k = 590; end    // sun, bottom rows (cut stripes)
                10: begin m = 1100; k = 650; end
                default: begin m = 320; k = 700; end    // grid line, lower sky
            endcase
            bg_pixel(m, k, rgb, want);
            check(rgb == want, $sformatf("background at (%0d,%0d): %h, expected %h", m, k, rgb, want));
        end
        // HUD (juego/hud.py layout): "00" per Player, three full Life diamonds.
        pixel(26, 21, rgb);     check(rgb == C_P1, "HUD P1 tens 0: segment a lit");
        pixel(30, 35, rgb);     check(rgb == 12'h000, "HUD P1 tens 0: segment g dark");
        pixel(1242, 21, rgb);   check(rgb == C_P2, "HUD P2 ones 0: segment a lit");
        pixel(76, 37, rgb);     check(rgb == C_P1, "HUD P1 Life 1 full");
        pixel(1204, 37, rgb);   check(rgb == C_P2, "HUD P2 Life 3 full");
        pixel(300, 40, rgb);    check(rgb == 12'h000, "HUD band background black");
        check(led[2:0] == G_IDLE, "G_IDLE after reset");
        read_display(disp);
        check(disp == "P200P100" || disp == "L203L103" || disp == "G0AL  10", {"idle Scoreboard shows ", disp});
        // Goal page: changing {SW15, SW14} while idle jumps to it at once. "O" and
        // "0" are the same 7-segment glyph, so GOAL decodes as G0AL.
        sw[15:14] = 2'b10; ticks(4);
        read_display(disp);
        check(disp == "G0AL  30", {"goal switches show G0AL  30, got ", disp});
        sw[15:14] = 2'b00; ticks(4);
        read_display(disp);
        check(disp == "G0AL  10", {"goal switches back show G0AL  10, got ", disp});

        // Start from the web page (UART Space), then the Round runs.
        uart_send(8'h20);
        wait_phase(G_PLAY, 20);
        ticks(STEP_TICKS * 3 + 2);
        pause(1);
        k = dut.u_game.step_count;
        h1 = dut.u_game.head_p1; h2 = dut.u_game.head_p2;
        check(k >= 3, $sformatf("%0d Steps taken", k));
        check(h1 == {6'd27, 7'(20 + k)}, $sformatf("P1 moved right to (%0d,%0d)", h1[6:0], h1[12:7]));
        check(h2 == {6'd27, 7'(59 - k)}, $sformatf("P2 moved left to (%0d,%0d)", h2[6:0], h2[12:7]));
        ticks(12);
        check(dut.u_game.head_p1 == h1 && dut.u_game.step_count == k, "Pause freezes the Bikes");
        check_bike(h1, DIR_RIGHT, C_P1, "P1");
        check_bike(h2, DIR_LEFT, C_P2, "P2");
        cell_rgb(20, 27, rgb);          check(rgb == C_P1_TRAIL, "P1 start Cell is now Trail");
        cell_rgb(59, 27, rgb);          check(rgb == C_P2_TRAIL, "P2 start Cell is now Trail");
        if (dut.u_fast.slot2_valid) check_star(dut.u_fast.slot2_cell);
        read_display(disp);
        check(disp == expect_points() || disp == expect_lives(), {"Scoreboard shows ", disp});

        // P1 turns Up with a bouncy BTNU; P2 turns Down with UART 's'.
        pause(0);
        press(BTN_U);
        uart_send("s");
        ticks(STEP_TICKS * 3 + 4);
        pause(1);
        h1 = dut.u_game.head_p1; h2 = dut.u_game.head_p2;
        check(h1[12:7] < 6'd27 && dut.u_game.shown_p1 == DIR_UP, $sformatf("P1 turned Up, now (%0d,%0d)", h1[6:0], h1[12:7]));
        check(h2[12:7] > 6'd27 && dut.u_game.shown_p2 == DIR_DOWN, $sformatf("P2 turned Down, now (%0d,%0d)", h2[6:0], h2[12:7]));
        check_bike(h1, DIR_UP, C_P1, "P1 after the Turn");
        check_bike(h2, DIR_DOWN, C_P2, "P2 after the Turn");
        dump_frame("frame-play.hex");

        // Run into the Walls: P2 reaches the bottom Wall first and Crashes.
        pause(0);
        wait_phase(G_CRASH, STEP_TICKS * 30);
        check(dut.u_game.crashed_p2 && !dut.u_game.crashed_p1, "only P2 Crashed");
        check(dut.u_game.lives_p2 == 2 && dut.u_game.lives_p1 == 3, "P2 lost one Life");
        check(dut.u_game.points_p1 >= 3, $sformatf("P1 got the +3 Survival Bonus (Points %0d)", dut.u_game.points_p1));
        h2 = dut.u_game.head_p2;
        check(h2[12:7] == 6'd48, "P2 stays on its last valid Cell");
        pause(1);
        cell_rgb(h2[6:0], h2[12:7], rgb);
        check(rgb == C_P2_TRAIL || rgb == C_P2 || rgb == bike_texel(DIR_DOWN, 16, 16),
              $sformatf("P2 Crash Cell: blinking sprite over its Crash Cell (%h)", rgb));
        read_display(disp);
        check(disp == expect_points() || disp == expect_lives(), {"Scoreboard shows ", disp});
        pause(0);

        // Crash display (~2 s), then the next Round waits for Start.
        wait_phase(G_READY, CRASH_TICKS + 20);
        pause(1);
        check_bike({6'd27, 7'd20}, DIR_RIGHT, C_P1, "next Round: P1 on its start Cell");
        check_bike({6'd27, 7'd59}, DIR_LEFT, C_P2, "next Round: P2 on its start Cell");
        bg_pixel(h2[6:0] * 16 + 8, h2[12:7] * 16 + 8, rgb, want); check(rgb == want, "old Crash Cell cleared");
        pixel(1204, 37, rgb);   check(rgb == 12'h000, "HUD P2 third Life hollow after the Crash");
        pixel(1164, 37, rgb);   check(rgb == C_P2, "HUD P2 first Life still full");
        pixel(76, 37, rgb);     check(rgb == C_P1, "HUD P1 Lives unchanged");
        // P1 ones digit, segment g (x 50, y 35): lit for 2 3 4 5 6 8 9.
        m = dut.u_game.points_p1 % 10;
        pixel(50, 35, rgb);
        check(rgb == ((m != 0 && m != 1 && m != 7) ? C_P1 : 12'h000),
              $sformatf("HUD P1 ones digit %0d, segment g (%h)", m, rgb));
        dump_frame("frame-ready.hex");
        pause(0);

        // A wait longer than 255 ticks: game_core holds phase_ticks at 255, but
        // the play icon keeps blinking (juego/hud.py, BLINK_TICKS = 16).
        ticks(260);
        check(dut.u_game.phase_ticks == 8'hFF, "ready wait past 255 ticks");
        for (int i = 0; i < 2; i++) begin
            m = dut.u_fast.snap_blink_ticks[4];
            k = 0;
            while (dut.u_fast.snap_blink_ticks[4] == m[0] && k < 40) begin ticks(1); k++; end
            check(k < 40, $sformatf("blink bit changes after tick 255 (%0d ticks)", k));
            pause(1);
            pixel(640, 37, rgb);
            check(rgb == (dut.u_fast.snap_blink_ticks[4] ? 12'h000 : 12'hFFF),
                  $sformatf("play icon follows the blink (%h, blink %0d)", rgb, dut.u_fast.snap_blink_ticks));
            pause(0);
        end
        press(BTN_C);                                // BTNC Start releases the Round
        wait_phase(G_PLAY, 20);
        check(dut.u_fast.late_publish == 0 && dut.u_game.overrun == 0, "no late publish, no Step overrun");

        // Play on until the Match ends: P2 turns Down into the bottom Wall each
        // Round, so P1 wins (on Lives, or on the goal if Rewards got it there).
        for (int r = 0; r < 4 && led[2:0] != G_MATCH; r++) begin
            if (led[2:0] == G_READY) begin press(BTN_C); wait_phase(G_PLAY, 20); end
            uart_send("s");
            k = 0;
            while (led[2:0] != G_READY && led[2:0] != G_MATCH && k < STEP_TICKS * 30 + CRASH_TICKS + 40) begin
                ticks(1); k++;
            end
        end
        check(led[2:0] == G_MATCH && dut.u_game.result == 2'd1,
              $sformatf("Match over, P1 wins (phase %0d, result %0d)", led[2:0], dut.u_game.result));
        pause(1);
        pixel(640, 37, rgb);    check(rgb == C_P1, $sformatf("HUD crown in P1's colour (%h)", rgb));
        pixel(640, 31, rgb);    check(rgb == 12'h000, "HUD crown: background between its points");
        if (dut.u_game.lives_p2 == 0) begin
            pixel(1164, 37, rgb); check(rgb == 12'h000, "HUD P2 first Life hollow at 0 Lives");
        end
        dump_frame("frame-match.hex");
        pause(0);

        if (errors != 0) $fatal(1, "%0d checks failed", errors);
        $display("PASS tron_system_tb");
        $finish;
    end
endmodule
