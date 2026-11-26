// Author: Alan (AIF31).
// hud_layer alone: every pixel of the 64 px band against prototipos/tron_fpga/juego/hud.py and
// font.py, for each Player's Points 0-45 and Lives 0-3, the play icon, the crown of each result
// and the blinks. Inputs are copied only at curr_x = 0, curr_y = 800: values given at other
// pixels, or changed during the band, must not show. The raster is driven as vga_out gives it:
// hud_color is the colour of the pixel in curr_x.
// hud.py's phases from the inputs: IDLE or READY while waiting_start, CRASH while crashed != 0,
// MATCH_OVER once result != 0 with no Crash shown. Its phase_ticks are frames since the phase began.
`timescale 1ns/1ps
module hud_layer_tb;
    localparam logic [11:0] C_BAND = 12'h000, C_P1 = 12'h0DF, C_P2 = 12'hF80, C_FG = 12'hFFF;
    logic        clk = 1'b0;
    logic [10:0] curr_x = 11'd0, curr_y = 11'd0;
    logic [5:0]  points_p1 = 6'd0, points_p2 = 6'd0;
    logic [1:0]  lives_p1 = 2'd0, lives_p2 = 2'd0;
    logic        waiting_start = 1'b0;
    logic [1:0]  result = 2'd0, crashed = 2'd0;
    logic [11:0] hud_color;
    int          pixels = 0, bands = 0;

    // The values of the last copy, and hud.py's phase and ticks for them.
    int          m_pts1 = 0, m_pts2 = 0, m_lives1 = 0, m_lives2 = 0, m_result = 0, m_crashed = 0;
    int          m_phase = -1;           // 0 playing, 1 IDLE/READY, 2 CRASH, 3 MATCH_OVER
    int          m_ticks = 0;

    // juego/font.py ICONS through make_hud_icons.py: word {icon, row}, bit c = column c.
    logic [15:0] hud_icons [0:63];
    initial $readmemh("hud_icons.mem", hud_icons);

    hud_layer dut (
        .clk(clk), .curr_x(curr_x), .curr_y(curr_y),
        .points_p1(points_p1), .points_p2(points_p2), .lives_p1(lives_p1), .lives_p2(lives_p2),
        .waiting_start(waiting_start), .result(result), .crashed(crashed),
        .hud_color(hud_color)
    );
    always #6 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "hud_layer_tb failed");
    endfunction

    // juego/font.py _SEGMENTS: does segment s of the 8 x 16 glyph cover column c, row r?
    // Rectangles {col0, row0, col1, row1} with exclusive ends.
    function automatic bit seg_covers(byte s, int c, int r);
        case (s)
            "a":     return c >= 1 && c < 7 && r >= 0  && r < 2;
            "b":     return c >= 6 && c < 8 && r >= 1  && r < 8;
            "c":     return c >= 6 && c < 8 && r >= 8  && r < 15;
            "d":     return c >= 1 && c < 7 && r >= 14 && r < 16;
            "e":     return c >= 0 && c < 2 && r >= 8  && r < 15;
            "f":     return c >= 0 && c < 2 && r >= 1  && r < 8;
            default: return c >= 1 && c < 7 && r >= 7  && r < 9;    // g
        endcase
    endfunction

    // juego/font.py _DIGIT_SEGMENTS: is glyph pixel (c, r) lit in digit d?
    function automatic bit digit_lit(int d, int c, int r);
        string segs;
        case (d)
            0: segs = "abcdef";   1: segs = "bc";       2: segs = "abged";   3: segs = "abgcd";
            4: segs = "fgbc";     5: segs = "afgcd";    6: segs = "afgedc";  7: segs = "abc";
            8: segs = "abcdefg";  default: segs = "abcdfg";
        endcase
        for (int i = 0; i < segs.len(); i++)
            if (seg_covers(segs[i], c, r)) return 1'b1;
        return 1'b0;
    endfunction

    // hud.py _blink_on: shown in the first 16 ticks of every 32.
    function automatic bit blink_on(int ticks);
        return (ticks / 16) % 2 == 0;
    endfunction

    // The band pixel (x, y < 64), from juego/hud.py layout() with BORDER_PX 10, GAP 4, 16 x 16
    // icons and the 8 x 16 glyph at scale 2 (16 x 32). P1's group starts at x 24: two digits,
    // 2 GAP, three Lives. P2's is mirrored and ends at x 1256: Lives, 2 GAP, digits. Life k is
    // full while k < Lives. The state icon is centred: x 1280 / 2 - 8. draw() and _state_icon():
    // a crashed Player's digits blink in CRASH; play blinks in IDLE and READY, in hud_fg; the crown
    // in MATCH_OVER is the winner's colour, hud_fg for a Draw.
    function automatic logic [11:0] hud_colour(int x, int y);
        int dig_y  = 10 + (64 - 10 - 32) / 2;          // 21
        int icon_y = dig_y + (32 - 16) / 2;            // 29
        int pts_w  = 2 * 16 + 4;
        int lives_w = 3 * 16 + 2 * 4;
        int p2_x0  = 1280 - 24 - (pts_w + 2 * 4 + lives_w);
        int state_x = 1280 / 2 - 16 / 2;               // 632
        int dig_x [0:1], life_x [0:1], pts [0:1], lives [0:1];
        logic [11:0] col [0:1];
        int icon;                                      // state icon: 2 play, 3 crown, -1 none
        logic [11:0] icon_col;
        dig_x  = '{24, p2_x0 + lives_w + 2 * 4};       // 24, 1220
        life_x = '{24 + pts_w + 2 * 4, p2_x0};         // 68, 1156
        pts    = '{m_pts1, m_pts2};
        lives  = '{m_lives1, m_lives2};
        col    = '{C_P1, C_P2};
        for (int p = 0; p < 2; p++) begin
            for (int d = 0; d < 2; d++) begin
                int bx = dig_x[p] + d * (16 + 4);
                if (m_phase == 2 && m_crashed[p] && !blink_on(m_ticks)) continue;
                if (x >= bx && x < bx + 16 && y >= dig_y && y < dig_y + 32 &&
                    digit_lit(d == 0 ? pts[p] / 10 : pts[p] % 10, (x - bx) / 2, (y - dig_y) / 2))
                    return col[p];
            end
            for (int k = 0; k < 3; k++) begin
                int bx = life_x[p] + k * (16 + 4);
                if (x >= bx && x < bx + 16 && y >= icon_y && y < icon_y + 16 &&
                    hud_icons[(k < lives[p] ? 0 : 16) + y - icon_y][x - bx])
                    return col[p];
            end
        end
        icon = -1;
        icon_col = C_FG;
        if (m_phase == 1 && blink_on(m_ticks)) icon = 2;
        if (m_phase == 3) begin
            icon = 3;
            icon_col = (m_result == 1) ? C_P1 : (m_result == 2) ? C_P2 : C_FG;
        end
        if (icon >= 0 && x >= state_x && x < state_x + 16 && y >= icon_y && y < icon_y + 16 &&
            hud_icons[16 * icon + y - icon_y][x - state_x])
            return icon_col;
        return C_BAND;
    endfunction

    // One cycle at pixel (x, y), with inputs set on the falling edge.
    task automatic pixel_at(int x, int y);
        @(negedge clk);
        curr_x = 11'(x);
        curr_y = 11'(y);
    endtask

    // One frame's copy at (0, 800) of these values, with other values given at the pixels around
    // it and after it. The model follows: a new phase starts its ticks at 0.
    task automatic copy(int pts1, int pts2, int lives1, int lives2, int ws, int res, int cr);
        int phase = ws ? 1 : (cr != 0) ? 2 : (res != 0) ? 3 : 0;
        {points_p1, points_p2, lives_p1, lives_p2} = {6'(45 - pts1), 6'(45 - pts2), ~2'(lives1), ~2'(lives2)};
        {waiting_start, result, crashed} = {~1'(ws), ~2'(res), ~2'(cr)};
        pixel_at(0, 799);
        pixel_at(1, 800);
        pixel_at(1279, 800);
        {points_p1, points_p2, lives_p1, lives_p2} = {6'(pts1), 6'(pts2), 2'(lives1), 2'(lives2)};
        {waiting_start, result, crashed} = {1'(ws), 2'(res), 2'(cr)};
        pixel_at(0, 800);
        pixel_at(1, 800);
        {points_p1, points_p2, lives_p1, lives_p2} = {6'(pts2), 6'(pts1), 2'(lives2), 2'(lives1)};
        {waiting_start, result, crashed} = {~1'(ws), ~2'(res), ~2'(cr)};
        m_pts1    = pts1;
        m_pts2    = pts2;
        m_lives1  = lives1;
        m_lives2  = lives2;
        m_result  = res;
        m_crashed = cr;
        m_ticks = (phase == m_phase) ? m_ticks + 1 : 0;
        m_phase = phase;
    endtask

    // Checks every band pixel of the frame after the last copy. Each line starts 8 px early, as
    // the raster arrives from the line before.
    task automatic check_band(string what);
        logic [11:0] want;
        for (int y = 0; y < 64; y++) begin
            pixel_at(-8, y);
            for (int x = -7; x < 1280; x++) begin
                @(negedge clk);
                want = hud_colour(x, y);
                if (hud_color !== want)
                    fail($sformatf("%s: pixel (%0d,%0d) is %03h, expected %03h", what, x, y, hud_color, want));
                curr_x = 11'(x);
                pixels++;
            end
        end
        bands++;
    endtask

    // n frames of one state; the band is checked in the frames listed in show.
    task automatic frames(string what, int n, int ws, int res, int cr, int show [$]);
        for (int f = 0; f < n; f++) begin
            copy(12, 7, 2, 1, ws, res, cr);
            if (f inside {show}) check_band($sformatf("%s, frame %0d", what, f));
        end
        $display("ok   %s: frames %p", what, show);
    endtask

    initial begin
        foreach (hud_icons[i])
            if ($isunknown(hud_icons[i])) fail($sformatf("hud_icons.mem does not fill word %0d", i));

        // Every digit in both places for both Players; all 16 pairs of Lives.
        for (int n = 0; n <= 45; n++) begin
            copy(n, 45 - n, n % 4, (n / 4) % 4, 0, 0, 0);
            check_band($sformatf("Points %0d-%0d, Lives %0d-%0d", n, 45 - n, n % 4, (n / 4) % 4));
        end
        $display("ok   Points 0-45 and Lives 0-3 of each Player");

        // Blinks: shown in frames 0-15 and 32-47 of a state, hidden in 16-31.
        frames("waiting for Start: play blinks", 40, 1, 0, 0, '{0, 15, 16, 31, 32});
        frames("P1 crashed: P1's digits blink", 40, 0, 0, 1, '{0, 15, 16, 31, 32});
        frames("P2 crashed: P2's digits blink", 20, 0, 0, 2, '{16});
        frames("both crashed: both blink", 20, 0, 0, 3, '{16});
        frames("playing: nothing blinks", 20, 0, 0, 0, '{16});
        // A Crash that ends the Match: no crown until its pause ends.
        frames("last Crash, P2 wins", 20, 0, 2, 1, '{0, 16});
        frames("Match over, P2 wins: crown", 20, 0, 2, 0, '{0, 16});
        frames("Match over, P1 wins: crown", 20, 0, 1, 0, '{0, 16});
        frames("Match over, Draw: white crown", 20, 0, 3, 0, '{0, 16});
        // A new state restarts the blink: play shows again at once.
        frames("waiting again", 20, 1, 0, 0, '{0, 16});
        frames("P1 crashed again", 10, 0, 0, 1, '{0});
        frames("waiting after the Crash", 2, 1, 0, 0, '{0, 1});

        $display("ok   %0d bands, %0d pixels", bands, pixels);
        $display("PASS hud_layer_tb");
        $finish;
    end
endmodule
