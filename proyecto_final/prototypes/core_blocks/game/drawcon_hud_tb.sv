// drawcon_hud_tb: checks every pixel of drawcon_game's 64 px HUD band against
// a reference built from the Python viewer's synthwave HUD (juego/hud.py
// layout() and draw(), juego/font.py _SEGMENTS / _DIGIT_SEGMENTS, font
// "seg"), not from the HDL: positions are derived from hud.py's constants,
// segment rectangles keep Python's exclusive ends, and the Life/play/crown
// bitmaps are the generator's output (proyecto_final/prototypes/core_blocks/tools/make_hud_icons.py), read
// independently of the HDL's addressing. Python's final scanline and flash
// stage (fx.finish) is not part of the HUD and is not modelled.
//
// States: reset straight into the idle HUD (no frame of the previous Match),
// Points 0..63 with carries, Lives 0..3 per Player, the crash blink of the
// digits, the play icon's blink while waiting, and the crown for P1, P2 and
// a Draw (none outside the Match end).
// Owner: Alan, the builder's own check (not an official contract §7 bench).
// Domain: one clock standing in for clk_pix; the raster is the handout's
// 1680 x 828 counters with curr_x = hcnt - 336, curr_y = vcnt - 27 as in
// vga_out. PROVISIONAL (ADR 0005): drawcon_game's ports.
module drawcon_hud_tb;
    import game_pkg::*;
    localparam string SPRITE_DIR = "src/prototypes/core_blocks/game/sprites/";
    localparam logic [11:0] P1 = 12'h0FF, P2 = 12'hF80, FG = 12'hFFF, BG = 12'h000;

    logic clk = 0, rst = 0;
    always #6 clk = !clk;

    // --- raster ------------------------------------------------------------
    logic [10:0] hcnt = 0, vcnt = 0, curr_x, curr_y;
    always_ff @(posedge clk) begin
        hcnt <= (hcnt == 11'd1679) ? 11'd0 : hcnt + 11'd1;
        if (hcnt == 11'd1679) vcnt <= (vcnt == 11'd827) ? 11'd0 : vcnt + 11'd1;
    end
    assign curr_x = hcnt - 11'd336;
    assign curr_y = vcnt - 11'd27;

    // --- snapshot driven by the bench ----------------------------------------
    logic [2:0] phase = G_IDLE;
    logic [4:0] blink = 0;
    logic crashed_p1 = 0, crashed_p2 = 0;
    logic [5:0] points_p1 = 0, points_p2 = 0;
    logic [1:0] lives_p1 = 3, lives_p2 = 3, result = 0;
    logic [12:0] b_addr;
    logic [3:0] draw_r, draw_g, draw_b;

    drawcon_game #(.SPRITE_DIR(SPRITE_DIR)) dut (.clk, .rst, .curr_x, .curr_y, .b_rdata(CELL_EMPTY),
        .snap_phase(phase), .snap_paused(1'b0), .snap_blink_ticks(blink),
        .snap_head_p1({6'd27, 7'd20}), .snap_head_p2({6'd27, 7'd59}),
        .snap_shown_p1(DIR_RIGHT), .snap_shown_p2(DIR_LEFT),
        .snap_crashed_p1(crashed_p1), .snap_crashed_p2(crashed_p2),
        .points_p1, .points_p2, .lives_p1, .lives_p2, .result,
        .b_addr, .draw_r, .draw_g, .draw_b);

    // --- reference: juego/hud.py and juego/font.py -------------------------------
    localparam int BORDER = 10, BAND = 64, W = 1280;
    localparam int SCALE = 2, DW = 8 * SCALE, DH = 16 * SCALE, GAP = 4, ICON = 16;
    localparam int PTS_W = 2 * DW + GAP, PIPS_W = 3 * ICON + 2 * GAP;
    localparam int TOTAL = PTS_W + 2 * GAP + PIPS_W;
    localparam int Y = BORDER + (BAND - BORDER - DH) / 2, IY = Y + (DH - ICON) / 2;
    localparam int P1_PX = 24, P1_IX = 24 + PTS_W + 2 * GAP;              // _group(0, 24, ...)
    localparam int P2_X0 = W - 24 - TOTAL;                                 // _group(1, W - 24, mirror)
    localparam int P2_PX = P2_X0 + PIPS_W + 2 * GAP, P2_IX = P2_X0;
    localparam int STATE_X = W / 2 - ICON / 2;

    logic [15:0] icons [0:63];                          // generator output: life, life_lost, play, crown
    initial $readmemh({SPRITE_DIR, "hud-icons-16.mem"}, icons);

    // _SEGMENTS: (col0, row0, col1, row1), exclusive ends; a..g
    function automatic bit in_seg(input int s, input int c, input int r);
        int c0, r0, c1, r1;
        case (s)
            0: begin c0 = 1; r0 = 0;  c1 = 7; r1 = 2;  end   // a
            1: begin c0 = 6; r0 = 1;  c1 = 8; r1 = 8;  end   // b
            2: begin c0 = 6; r0 = 8;  c1 = 8; r1 = 15; end   // c
            3: begin c0 = 1; r0 = 14; c1 = 7; r1 = 16; end   // d
            4: begin c0 = 0; r0 = 8;  c1 = 2; r1 = 15; end   // e
            5: begin c0 = 0; r0 = 1;  c1 = 2; r1 = 8;  end   // f
            default: begin c0 = 1; r0 = 7; c1 = 7; r1 = 9; end   // g
        endcase
        return c >= c0 && c < c1 && r >= r0 && r < r1;
    endfunction
    // _DIGIT_SEGMENTS as strings of segment letters
    function automatic bit digit_has(input int d, input int s);
        string segs;
        case (d)
            0: segs = "abcdef"; 1: segs = "bc"; 2: segs = "abged"; 3: segs = "abgcd"; 4: segs = "fgbc";
            5: segs = "afgcd"; 6: segs = "afgedc"; 7: segs = "abc"; 8: segs = "abcdefg"; default: segs = "abcdfg";
        endcase
        for (int i = 0; i < segs.len(); i++)
            if (segs[i] == 8'(8'h61 + s)) return 1;
        return 0;
    endfunction
    function automatic bit icon_px(input int icon, input int c, input int r);
        logic [15:0] row;
        row = icons[icon * 16 + r];
        return row[c];
    endfunction
    // Glyph bitmaps from the two tables above, built once.
    bit glyph [0:9][0:15][0:7];
    task automatic build_glyphs();
        for (int r = 0; r < 16; r++)
            for (int c = 0; c < 8; c++) begin
                for (int d = 0; d < 10; d++) begin
                    glyph[d][r][c] = 0;
                    for (int s = 0; s < 7; s++) if (in_seg(s, c, r) && digit_has(d, s)) glyph[d][r][c] = 1;
                end
            end
    endtask
    function automatic bit blink_on();                 // hud._blink_on(ticks)
        return blink[4] == 1'b0;
    endfunction

    // Colour of HUD pixel (x, y), y < 64, as HudRenderer.draw then the border.
    function automatic logic [11:0] expect_px(input int x, input int y);
        logic [11:0] c;
        int v, dig, gx, gy, ox, k;
        c = BG;
        for (int p = 0; p < 2; p++) begin
            for (int d = 0; d < 2; d++) begin             // Points, tens then ones
                ox = (p == 0 ? P1_PX : P2_PX) + d * (DW + GAP);
                if (x >= ox && x < ox + DW && y >= Y && y < Y + DH &&
                    !(phase == G_CRASH && (p == 0 ? crashed_p1 : crashed_p2) && !blink_on())) begin
                    v = (p == 0) ? points_p1 : points_p2;
                    dig = (d == 0) ? v / 10 : v % 10;
                    gx = (x - ox) / SCALE; gy = (y - Y) / SCALE;
                    if (glyph[dig][gy][gx]) c = (p == 0) ? P1 : P2;
                end
            end
            for (k = 0; k < 3; k++) begin                 // Lives: index < lives is full
                ox = (p == 0 ? P1_IX : P2_IX) + k * (ICON + GAP);
                if (x >= ox && x < ox + ICON && y >= IY && y < IY + ICON &&
                    icon_px((k < ((p == 0) ? lives_p1 : lives_p2)) ? 0 : 1, x - ox, y - IY))
                    c = (p == 0) ? P1 : P2;
            end
        end
        if (x >= STATE_X && x < STATE_X + ICON && y >= IY && y < IY + ICON) begin
            if ((phase == G_IDLE || phase == G_READY) && blink_on() && icon_px(2, x - STATE_X, y - IY))
                c = FG;
            if (phase == G_MATCH && result != 0 && icon_px(3, x - STATE_X, y - IY))
                c = (result == 1) ? P1 : (result == 2) ? P2 : FG;
        end
        if (x < BORDER || x >= W - BORDER || y < BORDER) c = 12'hFFF;
        return c;
    endfunction

    // --- capture and compare ------------------------------------------------------
    integer errors = 0, checked = 0;
    logic [11:0] got [0:BAND-1][0:W-1];
    task automatic capture_band();
        @(negedge clk iff (curr_x == 0 && curr_y == 0));
        for (int y = 0; y < BAND; y++) begin
            if (y > 0) @(negedge clk iff (curr_x == 0 && curr_y == 11'(y)));
            for (int x = 0; x < W; x++) begin
                if (x > 0) @(negedge clk);
                got[y][x] = {draw_r, draw_g, draw_b};
            end
        end
    endtask
    task automatic compare(input string what);
        int bad = 0;
        logic [11:0] e;
        for (int y = 0; y < BAND; y++)
            for (int x = 0; x < W; x++) begin
                e = expect_px(x, y);
                if (got[y][x] !== e) begin
                    if (bad < 5) $display("  (%0d,%0d) got %h expected %h", x, y, got[y][x], e);
                    bad++;
                end
            end
        checked++;
        if (bad == 0) $display("ok: %s", what);
        else begin $error("%s: %0d HUD pixels differ", what, bad); errors++; end
    endtask
    // New state: let drawcon latch it (curr_x 0 of the last line, curr_y 800), then capture.
    task automatic show(input string what);
        @(negedge clk iff (curr_x == 11'd1 && curr_y == 11'd800));
        capture_band();
        compare(what);
    endtask
    task automatic set_state(input logic [2:0] ph, input logic [4:0] b, input logic [5:0] pt1, pt2,
                             input logic [1:0] l1, l2, input logic c1, c2, input logic [1:0] res);
        phase = ph; blink = b; points_p1 = pt1; points_p2 = pt2;
        lives_p1 = l1; lives_p2 = l2; crashed_p1 = c1; crashed_p2 = c2; result = res;
    endtask

    initial begin
        build_glyphs();
        // The Life diamonds (full and hollow) are mirror-symmetric both ways,
        // so the hollow ring has the same thickness on every side.
        for (int i = 0; i < 2; i++)
            for (int r = 0; r < 16; r++)
                for (int c = 0; c < 16; c++)
                    if (icon_px(i, c, r) != icon_px(i, 15 - c, r) || icon_px(i, c, r) != icon_px(i, c, 15 - r)) begin
                        $error("Life icon %0d not symmetric at (%0d,%0d)", i, c, r); errors++;
                    end
        // A Match won by P1 with large scores, then CPU_RESETN: the first band
        // after reset is already the idle HUD, before any frame latch.
        set_state(G_MATCH, 5'd20, 6'd46, 6'd12, 2'd1, 2'd0, 1'b0, 1'b0, 2'd1);
        show("Match over, P1 wins 46-12: cyan crown, P2 no Lives");
        @(negedge clk iff (curr_x == 11'd100 && curr_y == 11'd800));   // just after the latch
        rst = 1;
        set_state(G_IDLE, 5'd0, 6'd0, 6'd0, 2'd3, 2'd3, 1'b0, 1'b0, 2'd0);
        @(negedge clk); rst = 0;
        capture_band();                                  // no latch point crossed since reset
        compare("first band after reset: idle 00-00, three Lives each, play shown");

        set_state(G_IDLE, 5'd16, 6'd0, 6'd0, 2'd3, 2'd3, 1'b0, 1'b0, 2'd0);
        show("idle, blink off: no play icon");
        set_state(G_READY, 5'd15, 6'd7, 6'd10, 2'd3, 2'd2, 1'b0, 1'b0, 2'd0);
        show("ready, blink on: play icon; 07-10; P2 two Lives");
        set_state(G_PLAY, 5'd3, 6'd19, 6'd40, 2'd1, 2'd3, 1'b0, 1'b0, 2'd1);
        show("play 19-40, Lives 1-3, stale result: no crown");
        set_state(G_PLAY, 5'd9, 6'd63, 6'd59, 2'd0, 2'd1, 1'b0, 1'b0, 2'd0);
        show("play 63-59, Lives 0-1");
        set_state(G_PLAY, 5'd0, 6'd28, 6'd35, 2'd2, 2'd2, 1'b0, 1'b0, 2'd0);
        show("play 28-35");
        set_state(G_PLAY, 5'd0, 6'd41, 6'd6, 2'd3, 2'd1, 1'b0, 1'b0, 2'd0);
        show("play 41-06");
        set_state(G_CRASH, 5'd17, 6'd13, 6'd24, 2'd1, 2'd2, 1'b1, 1'b0, 2'd0);
        show("crash, P1 crashed, blink off: P1 digits hidden");
        set_state(G_CRASH, 5'd2, 6'd13, 6'd24, 2'd1, 2'd2, 1'b1, 1'b1, 2'd0);
        show("crash, both crashed, blink on: digits shown");
        set_state(G_CRASH, 5'd30, 6'd13, 6'd24, 2'd1, 2'd2, 1'b0, 1'b1, 2'd0);
        show("crash, P2 crashed, blink off: P2 digits hidden");
        set_state(G_MATCH, 5'd16, 6'd8, 6'd10, 2'd0, 2'd2, 1'b0, 1'b0, 2'd2);
        show("Match over, P2 wins: orange crown");
        set_state(G_MATCH, 5'd1, 6'd40, 6'd40, 2'd2, 2'd2, 1'b0, 1'b0, 2'd3);
        show("Match over, Draw 40-40: white crown");

        if (errors != 0 || checked != 13) $fatal(1, "%0d of %0d HUD states failed", errors, checked);
        $display("PASS drawcon_hud_tb");
        $finish;
    end
endmodule
