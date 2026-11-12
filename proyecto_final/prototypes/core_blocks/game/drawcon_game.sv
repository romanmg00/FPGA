// drawcon_game: the Tron picture with sprites from ROM. Owner: Roman (drawcon,
// sprite_rom), written here as provisional integration evidence. Domain:
// clk_pix; no crossing (the snapshot comes from fast_core in clk_pix, Arena
// port B and the sprite ROMs are on clk_pix).
//
// Follows the VGA and Sprite Design Plan, Decision B: curr_x/curr_y are the
// pixel vga_out outputs now, and composition uses them; memories are read
// early from a FUTURE raster position (complete raster advance, line and frame
// wrap included), never from a bare curr_x + L.
//   Arena port B: 1 cycle of latency -> address of the position 1 ahead.
//   Sprite ROMs:  2 cycles (sprite_rom)  -> address of the position 2 ahead.
// Bike positions and Headings are latched once per frame, at the start of
// the last blanking line, so a prefetched texel and its display use the same
// state and a Bike never tears mid-frame. The Arena is live: render coherence
// with mid-frame Arena writes is still open (ADR 0003, Left open).
//
// Layers, bottom to top: background; Arena Cells (Walls, Trails, Crash Cells);
// Rewards (16 x 16 ROM art in their Cell); Bikes (32 x 32 ROM art pointing UP,
// rotated by address, centred on the head Cell; a crashed Bike blinks during
// the Crash display); the HUD band; the 10 px white border.
// Art: the synthwave final design (bike-synth-32, reward-neon-gem-16 for +1,
// reward-neon-star-16 for +3). 000 is transparent; 0F0 takes the Player's or
// the Reward's colour. PROVISIONAL (ADR 0005): ports, colours and latching.
//
// HUD: the synthwave Scoreboard of juego/hud.py (font "seg"), at its pixel
// positions. Per Player: two seven-segment Points digits, 16 x 32 px (8 x 16
// glyph at scale 2), and three 16 x 16 Life diamonds (hollow once lost); P2
// is mirrored.
// A centre icon blinks "play" while waiting for Start and shows a crown in
// the winner's colour (white for a Draw) after the Match. The digits are
// segment rectangles (comparators, no ROM); the icons are a 64 x 16-bit
// LUT ROM (sprites/hud-icons-16.mem, tools/make_hud_icons.py). The HUD colour
// is computed for the next pixel (the Arena look-ahead) and registered, so it
// adds no logic between curr_x/curr_y and the VGA pins. Its values are
// latched with the Bikes, once per frame; rst restores the idle HUD at once,
// so a reset never shows the previous Match for a frame. Blinks use
// snap_blink_ticks[4] (BLINK_TICKS = 16 in juego/hud.py and render.py).
//
// Neon Wall (juego/fx.py _neon_wall, synthwave palette): Wall Cells are black
// (wall 000; 101 read as a magenta band on the board) with a neon tube around
// the playable Arena: 2 px of wall_line (F4D) just outside it, 2 px of glow
// (halve(F4D) = 726) outside the tube, and a 1 px glow on the Arena's own edge,
// under Trails, Rewards and Bikes. Box comparators on the look-ahead pixel,
// registered like the HUD.
//
// Trails (juego/render.py, trail "pulse"): a Trail or head Cell is the Player
// colour (0FF, F80) and a pixel (x, y) with (x + y - 2 frame) mod 64 < 6 takes
// the shine colour c/4 + CCC (CFF, FEC): diagonal stripes 64 px apart that
// slide 2 px per video frame. A crashed head Cell is drawn as its Player's
// Trail. The stripe test is computed on the look-ahead pixel and registered.
//
// Background (juego/fx.py build_base, synthwave): inside the Arena a sky
// gradient (one colour per 16 px band), a striped sun of radius 160 centred
// on the Arena, 2 x 2 px stars from a position hash that twinkle by phase,
// and a neon grid every 32 px (1 px line pulsing over 4 phases, 1 px glow on
// each side), all under Trails, Rewards and Bikes. Tables:
// sprites/synthwave-{sky,sun,grid}.mem from tools/make_bg_luts.py.
module drawcon_game #(
    parameter string SPRITE_DIR = "src/prototypes/core_blocks/game/sprites/"   // .mem prefix (XSim run folder)
) (
    input  logic        clk, rst,               // rst: synchronous, active high (rst_pix)
    input  logic [10:0] curr_x, curr_y,
    input  logic [3:0]  b_rdata,
    input  logic [2:0]  snap_phase,
    input  logic        snap_paused,
    input  logic [4:0]  snap_blink_ticks,       // phase ticks mod 32, not held at 255 (fast_core)
    input  logic [12:0] snap_head_p1, snap_head_p2,
    input  logic [1:0]  snap_shown_p1, snap_shown_p2,
    input  logic        snap_crashed_p1, snap_crashed_p2,
    input  logic [5:0]  points_p1, points_p2,
    input  logic [1:0]  lives_p1, lives_p2,
    input  logic [1:0]  result,                 // 0 none, 1 P1, 2 P2, 3 Draw
    output logic [12:0] b_addr,
    output logic [3:0]  draw_r, draw_g, draw_b
);
    import game_pkg::*;
    localparam logic [11:0] C_WALL = 12'h000, C_HUD = 12'h000,
        C_WALL_LINE = 12'hF4D, C_WALL_GLOW = 12'h726,
        C_P1 = 12'h0FF, C_P2 = 12'hF80, C_P1_SHINE = 12'hCFF, C_P2_SHINE = 12'hFEC,
        C_CRASH = 12'hF00, C_REWARD1 = 12'hFE3, C_REWARD3 = 12'hC8F, C_WHITE = 12'hFFF;

    // --- raster positions ---------------------------------------------------
    // vga_out: curr_x = hcnt - 336, curr_y = vcnt - 27 (11-bit), so the raster
    // counters can be recovered and advanced with their own wrap.
    function automatic logic [21:0] ahead(input logic [10:0] x, y, input integer lead);
        logic [10:0] hc, vc;
        hc = x + 11'(H_SYNC + H_BP);
        vc = y + 11'(V_SYNC + V_BP);
        hc = hc + 11'(lead);
        if (hc >= 11'(H_TOTAL)) begin
            hc = hc - 11'(H_TOTAL);
            vc = (vc == 11'(V_TOTAL - 1)) ? 11'd0 : vc + 11'd1;
        end
        return {vc - 11'(V_SYNC + V_BP), hc - 11'(H_SYNC + H_BP)};
    endfunction

    // Sprite ROM address for square art pointing UP (juego/sprites.py rom_address).
    function automatic logic [9:0] bike_addr(input logic [1:0] heading, input logic [4:0] dx, dy);
        case (heading)
            DIR_UP:    return {dy, dx};
            DIR_DOWN:  return {~dy, ~dx};
            DIR_RIGHT: return {~dx, dy};
            default:   return {dx, ~dy};
        endcase
    endfunction

    logic [10:0] ax, ay, sx, sy;                  // Arena look-ahead (1), sprite look-ahead (2)
    always_comb begin
        {ay, ax} = ahead(curr_x, curr_y, 1);
        {sy, sx} = ahead(curr_x, curr_y, 2);
        b_addr = (ax < 11'd1280 && ay < 11'd800) ? {ay[9:4], ax[10:4]} : 13'd0;
    end

    // --- per-frame Bike snapshot (latched in vertical blanking) --------------
    logic [12:0] f_head_p1 = '0, f_head_p2 = '0;
    logic [1:0]  f_dir_p1 = '0, f_dir_p2 = '0;
    logic        f_show_p1 = 1'b0, f_show_p2 = 1'b0;
    always_ff @(posedge clk) begin
        if (rst) begin
            f_show_p1 <= 1'b0; f_show_p2 <= 1'b0;
        end else if (curr_x == 11'd0 && curr_y == 11'd800) begin
            f_head_p1 <= snap_head_p1; f_head_p2 <= snap_head_p2;
            f_dir_p1 <= snap_shown_p1; f_dir_p2 <= snap_shown_p2;
            // Bikes appear from the first preparation on; a crashed Bike
            // blinks during the Crash display (juego/render.py: BLINK_TICKS = 16).
            f_show_p1 <= snap_phase != G_IDLE &&
                         !(snap_crashed_p1 && snap_phase == G_CRASH && snap_blink_ticks[4]);
            f_show_p2 <= snap_phase != G_IDLE &&
                         !(snap_crashed_p2 && snap_phase == G_CRASH && snap_blink_ticks[4]);
        end
    end

    // --- sprite reads, 2 cycles ahead -----------------------------------------
    logic [10:0] u_p1, v_p1, u_p2, v_p2;
    logic in_p1, in_p2;
    logic in_p1_q1 = 1'b0, in_p1_q2 = 1'b0, in_p2_q1 = 1'b0, in_p2_q2 = 1'b0;
    logic [9:0] addr_p1, addr_p2;
    logic [11:0] tex_p1, tex_p2, tex_gem, tex_star;
    always_comb begin
        // Sprite top-left = head Cell origin - 8 px, so the Bike is centred.
        u_p1 = sx - ({f_head_p1[6:0], 4'd0} - 11'd8);
        v_p1 = sy - ({1'b0, f_head_p1[12:7], 4'd0} - 11'd8);
        u_p2 = sx - ({f_head_p2[6:0], 4'd0} - 11'd8);
        v_p2 = sy - ({1'b0, f_head_p2[12:7], 4'd0} - 11'd8);
        in_p1 = f_show_p1 && u_p1 < 11'd32 && v_p1 < 11'd32;
        in_p2 = f_show_p2 && u_p2 < 11'd32 && v_p2 < 11'd32;
        addr_p1 = bike_addr(f_dir_p1, u_p1[4:0], v_p1[4:0]);
        addr_p2 = bike_addr(f_dir_p2, u_p2[4:0], v_p2[4:0]);
    end
    always_ff @(posedge clk) begin
        in_p1_q1 <= in_p1; in_p1_q2 <= in_p1_q1;
        in_p2_q1 <= in_p2; in_p2_q2 <= in_p2_q1;
    end
    sprite_rom #(.AW(10), .INIT_FILE({SPRITE_DIR, "bike-synth-32.mem"})) u_bike_p1 (.clk, .addr(addr_p1), .data(tex_p1));
    sprite_rom #(.AW(10), .INIT_FILE({SPRITE_DIR, "bike-synth-32.mem"})) u_bike_p2 (.clk, .addr(addr_p2), .data(tex_p2));
    // Rewards fill exactly one Cell: the texel is the position inside the Cell.
    sprite_rom #(.AW(8), .INIT_FILE({SPRITE_DIR, "reward-neon-gem-16.mem"}))  u_gem  (.clk, .addr({sy[3:0], sx[3:0]}), .data(tex_gem));
    sprite_rom #(.AW(8), .INIT_FILE({SPRITE_DIR, "reward-neon-star-16.mem"})) u_star (.clk, .addr({sy[3:0], sx[3:0]}), .data(tex_star));

    function automatic logic [11:0] tint(input logic [11:0] texel, colour);
        return (texel == COLOR_TINT_KEY) ? colour : texel;
    endfunction

    // --- HUD ---------------------------------------------------------------
    // Layout of juego/hud.py layout(): digits at y 21..52, icons at y 29..44.
    localparam int DIG_Y = 21, ICON_Y = 29;
    localparam int D_P1_TENS = 24, D_P1_ONES = 44, D_P2_TENS = 1220, D_P2_ONES = 1240;
    localparam int I_P1_LIFE0 = 68, I_P2_LIFE0 = 1156, I_STATE = 632, I_STEP = 20;
    localparam logic [11:0] C_HUD_FG = 12'hFFF;
    localparam logic [1:0] ICON_LIFE = 2'd0, ICON_LOST = 2'd1, ICON_PLAY = 2'd2, ICON_CROWN = 2'd3;

    // Points in decimal: tens by comparison (Points stay below 64).
    function automatic logic [7:0] two_digits(input logic [5:0] v);
        logic [3:0] t;
        t = (v >= 6'd60) ? 4'd6 : (v >= 6'd50) ? 4'd5 : (v >= 6'd40) ? 4'd4 :
            (v >= 6'd30) ? 4'd3 : (v >= 6'd20) ? 4'd2 : (v >= 6'd10) ? 4'd1 : 4'd0;
        return {t, 4'(v - 6'({t, 3'b000}) - 6'({t, 1'b0}))};
    endfunction
    // Segments {g, f, e, d, c, b, a} lit for a digit.
    function automatic logic [6:0] seg_mask(input logic [3:0] d);
        case (d)
            4'd0: return 7'h3F; 4'd1: return 7'h06; 4'd2: return 7'h5B; 4'd3: return 7'h4F;
            4'd4: return 7'h66; 4'd5: return 7'h6D; 4'd6: return 7'h7D; 4'd7: return 7'h07;
            4'd8: return 7'h7F; default: return 7'h6F;
        endcase
    endfunction
    // Segment rectangles of the 8 x 16 glyph (juego/font.py _SEGMENTS) that contain (gx, gy).
    function automatic logic [6:0] seg_at(input logic [2:0] gx, input logic [3:0] gy);
        logic mid_x, left, right;
        mid_x = gx >= 3'd1 && gx <= 3'd6;
        left  = gx <= 3'd1;
        right = gx >= 3'd6;
        return {mid_x && (gy == 4'd7 || gy == 4'd8),        // g
                left  && gy >= 4'd1 && gy <= 4'd7,           // f
                left  && gy >= 4'd8 && gy <= 4'd14,          // e
                mid_x && gy >= 4'd14,                        // d
                right && gy >= 4'd8 && gy <= 4'd14,          // c
                right && gy >= 4'd1 && gy <= 4'd7,           // b
                mid_x && gy <= 4'd1};                        // a
    endfunction

    (* rom_style = "distributed" *) logic [15:0] icon_rom [0:63];
    initial $readmemh({SPRITE_DIR, "hud-icons-16.mem"}, icon_rom);

    // Per-frame HUD state, latched with the Bikes.
    logic [7:0] f_pts_p1 = '0, f_pts_p2 = '0;            // {tens, ones}
    logic [1:0] f_lives_p1 = '0, f_lives_p2 = '0;
    logic       f_dig_p1 = 1'b0, f_dig_p2 = 1'b0;        // digits shown (crash blink)
    logic       f_play = 1'b0, f_crown = 1'b0;
    logic [11:0] f_crown_c = '0;
    always_ff @(posedge clk) begin
        if (rst) begin                                    // the idle HUD of a new Match
            f_pts_p1 <= '0; f_pts_p2 <= '0;
            f_lives_p1 <= 2'(LIVES_START); f_lives_p2 <= 2'(LIVES_START);
            f_dig_p1 <= 1'b1; f_dig_p2 <= 1'b1;
            f_play <= 1'b1; f_crown <= 1'b0; f_crown_c <= C_HUD_FG;   // idle, tick 0: play shown
        end else if (curr_x == 11'd0 && curr_y == 11'd800) begin
            f_pts_p1 <= two_digits(points_p1); f_pts_p2 <= two_digits(points_p2);
            f_lives_p1 <= lives_p1; f_lives_p2 <= lives_p2;
            // hud.py: a crashed Player's digits blink with BLINK_TICKS = 16.
            f_dig_p1 <= !(snap_phase == G_CRASH && snap_crashed_p1 && snap_blink_ticks[4]);
            f_dig_p2 <= !(snap_phase == G_CRASH && snap_crashed_p2 && snap_blink_ticks[4]);
            f_play  <= (snap_phase == G_IDLE || snap_phase == G_READY) && !snap_blink_ticks[4];
            f_crown <= snap_phase == G_MATCH && result != 2'd0;
            f_crown_c <= (result == 2'd1) ? C_P1 : (result == 2'd2) ? C_P2 : C_HUD_FG;
        end
    end

    // HUD colour of the NEXT pixel (ax, ay), registered into hud_rgb.
    logic [10:0] hdx, hix, hdy, hiy;
    logic [3:0]  h_digit;
    logic        h_dig_in, h_icon_in, h_icon_bit;
    logic [11:0] h_dig_c, h_icon_c, hud_next;
    logic [1:0]  h_icon;
    logic [6:0]  h_segs;
    logic [11:0] hud_rgb = '0;
    always_comb begin
        hdy = ay - 11'(DIG_Y);
        hiy = ay - 11'(ICON_Y);
        // Digit box: at most one contains the pixel.
        h_dig_in = 1'b0; hdx = '0; h_digit = '0; h_dig_c = C_P1;
        if (ax >= 11'(D_P1_TENS) && ax < 11'(D_P1_TENS + 16)) begin
            h_dig_in = f_dig_p1; hdx = ax - 11'(D_P1_TENS); h_digit = f_pts_p1[7:4];
        end else if (ax >= 11'(D_P1_ONES) && ax < 11'(D_P1_ONES + 16)) begin
            h_dig_in = f_dig_p1; hdx = ax - 11'(D_P1_ONES); h_digit = f_pts_p1[3:0];
        end else if (ax >= 11'(D_P2_TENS) && ax < 11'(D_P2_TENS + 16)) begin
            h_dig_in = f_dig_p2; hdx = ax - 11'(D_P2_TENS); h_digit = f_pts_p2[7:4];
            h_dig_c = C_P2;
        end else if (ax >= 11'(D_P2_ONES) && ax < 11'(D_P2_ONES + 16)) begin
            h_dig_in = f_dig_p2; hdx = ax - 11'(D_P2_ONES); h_digit = f_pts_p2[3:0];
            h_dig_c = C_P2;
        end
        if (ay < 11'(DIG_Y) || ay >= 11'(DIG_Y + 32)) h_dig_in = 1'b0;
        h_segs = seg_at(hdx[3:1], hdy[4:1]);

        // Icon box: Life k of P1 at 68 + 20k, of P2 at 1156 + 20k; the state icon.
        h_icon_in = 1'b0; hix = '0; h_icon = ICON_LIFE; h_icon_c = C_P1;
        for (int k = 0; k < 3; k++) begin
            if (ax >= 11'(I_P1_LIFE0 + I_STEP * k) && ax < 11'(I_P1_LIFE0 + I_STEP * k + 16)) begin
                h_icon_in = 1'b1; hix = ax - 11'(I_P1_LIFE0 + I_STEP * k);
                h_icon = (2'(k) < f_lives_p1) ? ICON_LIFE : ICON_LOST; h_icon_c = C_P1;
            end
            if (ax >= 11'(I_P2_LIFE0 + I_STEP * k) && ax < 11'(I_P2_LIFE0 + I_STEP * k + 16)) begin
                h_icon_in = 1'b1; hix = ax - 11'(I_P2_LIFE0 + I_STEP * k);
                h_icon = (2'(k) < f_lives_p2) ? ICON_LIFE : ICON_LOST; h_icon_c = C_P2;
            end
        end
        if (ax >= 11'(I_STATE) && ax < 11'(I_STATE + 16)) begin
            h_icon_in = f_play || f_crown; hix = ax - 11'(I_STATE);
            h_icon = f_crown ? ICON_CROWN : ICON_PLAY; h_icon_c = f_crown ? f_crown_c : C_HUD_FG;
        end
        if (ay < 11'(ICON_Y) || ay >= 11'(ICON_Y + 16)) h_icon_in = 1'b0;
        h_icon_bit = icon_rom[{h_icon, hiy[3:0]}][hix[3:0]];

        hud_next = C_HUD;
        if (h_dig_in && |(h_segs & seg_mask(h_digit))) hud_next = h_dig_c;
        if (h_icon_in && h_icon_bit)                   hud_next = h_icon_c;
    end
    always_ff @(posedge clk) hud_rgb <= hud_next;

    // --- neon Wall, for the next pixel (ax, ay), registered ---------------------
    // The playable Arena in pixels: [AX0, AX1) x [AY0, AY1).
    localparam int AX0 = PLAY_CX_MIN * 16, AX1 = (PLAY_CX_MAX + 1) * 16;
    localparam int AY0 = PLAY_CY_MIN * 16, AY1 = (PLAY_CY_MAX + 1) * 16;
    // Inside the Arena grown by k px on every side (k = -1 shrinks it).
    function automatic logic in_arena(input logic [10:0] x, y, input int k);
        return x >= 11'(AX0 - k) && x < 11'(AX1 + k) && y >= 11'(AY0 - k) && y < 11'(AY1 + k);
    endfunction
    logic [11:0] wall_rgb = '0;                   // a Wall Cell's colour
    always_ff @(posedge clk)
        wall_rgb <= in_arena(ax, ay, 2) ? C_WALL_LINE : in_arena(ax, ay, 4) ? C_WALL_GLOW : C_WALL;

    // --- synthwave background (juego/fx.py build_base: sky, sun, stars, neon grid)
    // The colour of an empty Arena pixel, computed from the position 7 ahead
    // through seven registers, so it is ready when that pixel is shown. The tables come
    // from fx.py through tools/make_bg_luts.py. The animation phase is
    // fx.phase(frame) = frame[4:3], frame counting video frames.
    localparam int SUN_CX = (AX0 + AX1) / 2, SUN_TOP = (AY0 + AY1) / 2 - 160;   // 640, 272 (SUN_R 160)
    localparam logic [11:0] C_STAR = 12'hCCF, C_STAR_DIM = 12'h667, C_GRID_GLOW = 12'h304;
    logic [11:0] sky_rom [0:63];
    logic [11:0] grid_rom [0:3];
    (* rom_style = "block" *) logic [20:0] sun_rom [0:320];
    initial begin
        $readmemh({SPRITE_DIR, "synthwave-sky.mem"}, sky_rom);
        $readmemh({SPRITE_DIR, "synthwave-sun.mem"}, sun_rom);
        $readmemh({SPRITE_DIR, "synthwave-grid.mem"}, grid_rom);
    end
    logic [4:0] frame_cnt = '0;
    always_ff @(posedge clk)
        if (rst) frame_cnt <= '0;
        else if (curr_x == 11'd0 && curr_y == 11'd800) frame_cnt <= frame_cnt + 5'd1;

    // Pipeline, seven registers from the position 7 ahead to bg_rgb. The star
    // hash's constant multiplies map to DSP48s, each with its multiplier (MREG)
    // and output (PREG) register; the position's other features travel beside
    // them. fx._star_hash: ((hx * 0x2C9 + 7) ^ (hy * 0x1F3 + (hx >> 3))) * 0x3B
    // & 0xFFFF with hx = x >> 1, hy = y >> 1; only the low 16 bits matter.
    typedef struct packed {
        logic [11:0] sky;                 // sky band colour
        logic [20:0] sun;                 // sun row {lit, half width, colour}
        logic        sun_ok;              // the row is inside the sun's 321 rows
        logic [10:0] x;
        logic        core, halo, rim;     // grid line, grid glow, Arena-edge glow
    } bg_feat_t;
    logic [10:0] bx, by, p0_x = '0, p0_y = '0;
    logic [9:0]  hx0, hy0;
    logic [10:0] sun_row;
    logic [15:0] m_a = '0, m_b = '0, a2 = '0, b2 = '0, ab3 = '0, mh4 = '0, h5 = '0;
    logic [6:0]  hx3_1 = '0;
    bg_feat_t    f1 = '0, f2 = '0, f3 = '0, f4 = '0, f5 = '0;
    always_comb begin
        {by, bx} = ahead(curr_x, curr_y, 7);
        hx0 = p0_x[10:1]; hy0 = p0_y[10:1];
        sun_row = p0_y - 11'(SUN_TOP);
    end
    always_ff @(posedge clk) begin
        p0_x <= bx; p0_y <= by;                                         // 1: position
        m_a <= 16'(32'(hx0) * 32'h2C9);                                 // 2: multiply (MREG)
        m_b <= 16'(32'(hy0) * 32'h1F3);
        hx3_1 <= hx0[9:3];
        f1.sky <= sky_rom[p0_y[9:4]];
        f1.sun <= sun_rom[sun_row[8:0]];
        f1.sun_ok <= p0_y >= 11'(SUN_TOP) && p0_y <= 11'(SUN_TOP + 320);
        f1.x <= p0_x;
        f1.core <= p0_x[4:0] == 5'd0 || p0_y[4:0] == 5'd0;
        f1.halo <= p0_x[4:0] == 5'd1 || p0_x[4:0] == 5'd31 || p0_y[4:0] == 5'd1 || p0_y[4:0] == 5'd31;
        f1.rim <= in_arena(p0_x, p0_y, 0) && !in_arena(p0_x, p0_y, -1);
        a2 <= m_a + 16'd7;                                              // 3: post-add (PREG)
        b2 <= m_b + 16'(hx3_1);
        f2 <= f1;
        ab3 <= a2 ^ b2;                                                 // 4
        f3 <= f2;
        mh4 <= 16'(32'(ab3) * 32'h3B);                                  // 5: multiply (MREG)
        f4 <= f3;
        h5 <= mh4;                                                      // 6: (PREG)
        f5 <= f4;
    end

    // stage 7: layers in build_base order, sky < sun < stars < grid < Wall edge glow
    logic [7:0]  s_w;
    logic        s_sun, s_star;
    logic [11:0] bg_next, bg_rgb = '0;
    always_comb begin
        s_w = f5.sun[19:12];
        s_sun = f5.sun_ok && f5.sun[20] && f5.x >= 11'(SUN_CX) - 11'(s_w) && f5.x < 11'(SUN_CX) + 11'(s_w);
        s_star = h5[13:5] == 9'd0 && !s_sun;
        bg_next = f5.sky;
        if (s_sun) bg_next = f5.sun[11:0];
        if (s_star) bg_next = (h5[3:2] == frame_cnt[4:3]) ? C_STAR_DIM : C_STAR;   // a quarter twinkle per phase
        if (f5.halo && !f5.core) bg_next = C_GRID_GLOW;
        if (f5.core) bg_next = grid_rom[frame_cnt[4:3]];
        if (f5.rim) bg_next = C_WALL_GLOW;
    end
    always_ff @(posedge clk) bg_rgb <= bg_next;

    // --- Trail stripes, for the next pixel (ax, ay), registered --------------------
    logic [5:0] stripe_pos;
    logic       stripe = 1'b0;
    always_comb stripe_pos = ax[5:0] + ay[5:0] - {frame_cnt, 1'b0};   // (x + y - 2 frame) mod 64
    always_ff @(posedge clk) stripe <= stripe_pos < 6'd6;

    // --- composition at the current pixel ------------------------------------
    logic [12:0] here;
    logic [11:0] rgb;
    logic visible;
    always_comb begin
        here = {curr_y[9:4], curr_x[10:4]};
        visible = curr_x < 11'd1280 && curr_y < 11'd800;

        case (b_rdata)
            CELL_WALL:                    rgb = wall_rgb;
            CELL_P1_TRAIL, CELL_P1_HEAD:  rgb = stripe ? C_P1_SHINE : C_P1;
            CELL_P2_TRAIL, CELL_P2_HEAD:  rgb = stripe ? C_P2_SHINE : C_P2;
            CELL_CRASH:  rgb = (here == f_head_p1) ? (stripe ? C_P1_SHINE : C_P1) :
                               (here == f_head_p2) ? (stripe ? C_P2_SHINE : C_P2) : C_CRASH;
            CELL_REWARD0, CELL_REWARD1:   rgb = (tex_gem  != COLOR_TRANSPARENT) ? tint(tex_gem,  C_REWARD1) : bg_rgb;
            CELL_REWARD2:                 rgb = (tex_star != COLOR_TRANSPARENT) ? tint(tex_star, C_REWARD3) : bg_rgb;
            default:                      rgb = bg_rgb;
        endcase
        if (in_p2_q2 && tex_p2 != COLOR_TRANSPARENT) rgb = tint(tex_p2, C_P2);
        if (in_p1_q2 && tex_p1 != COLOR_TRANSPARENT) rgb = tint(tex_p1, C_P1);

        // HUD band, from the registered look-ahead (snap_paused: no Pause screen yet).
        if (curr_y < 11'(HUD_ROWS * 16)) rgb = hud_rgb;

        if (visible && (curr_x < 11'(BORDER_PX) || curr_x >= 11'(1280 - BORDER_PX) ||
                        curr_y < 11'(BORDER_PX) || curr_y >= 11'(800 - BORDER_PX)))
            rgb = C_WHITE;
        if (!visible) rgb = 12'h000;
        {draw_r, draw_g, draw_b} = rgb;
    end
endmodule
