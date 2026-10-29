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
module drawcon_game #(
    parameter string SPRITE_DIR = "src/prototypes/core_blocks/game/sprites/"   // .mem prefix (XSim run folder)
) (
    input  logic        clk,
    input  logic [10:0] curr_x, curr_y,
    input  logic [3:0]  b_rdata,
    input  logic [2:0]  snap_phase,
    input  logic        snap_paused,
    input  logic [7:0]  snap_phase_ticks,
    input  logic [12:0] snap_head_p1, snap_head_p2,
    input  logic [1:0]  snap_shown_p1, snap_shown_p2,
    input  logic        snap_crashed_p1, snap_crashed_p2,
    input  logic [5:0]  points_p1, points_p2,
    input  logic [1:0]  lives_p1, lives_p2,
    output logic [12:0] b_addr,
    output logic [3:0]  draw_r, draw_g, draw_b
);
    import game_pkg::*;
    localparam logic [11:0] C_BG = 12'h001, C_WALL = 12'hF4D, C_HUD = 12'h102,
        C_P1 = 12'h0FF, C_P2 = 12'hF80, C_P1_TRAIL = 12'h0AA, C_P2_TRAIL = 12'hA50,
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
        if (curr_x == 11'd0 && curr_y == 11'd800) begin
            f_head_p1 <= snap_head_p1; f_head_p2 <= snap_head_p2;
            f_dir_p1 <= snap_shown_p1; f_dir_p2 <= snap_shown_p2;
            // Bikes appear from the first preparation on; a crashed Bike
            // blinks (~4 Hz) during the Crash display.
            f_show_p1 <= snap_phase != G_IDLE &&
                         !(snap_crashed_p1 && snap_phase == G_CRASH && snap_phase_ticks[3]);
            f_show_p2 <= snap_phase != G_IDLE &&
                         !(snap_crashed_p2 && snap_phase == G_CRASH && snap_phase_ticks[3]);
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

    // --- composition at the current pixel ------------------------------------
    logic [12:0] here;
    logic [11:0] rgb;
    logic visible;
    logic [10:0] off_p1, off_p2;
    always_comb begin
        here = {curr_y[9:4], curr_x[10:4]};
        visible = curr_x < 11'd1280 && curr_y < 11'd800;
        off_p1 = curr_x - 11'd16;
        off_p2 = 11'd1263 - curr_x;

        case (b_rdata)
            CELL_WALL:                    rgb = C_WALL;
            CELL_P1_TRAIL, CELL_P1_HEAD:  rgb = C_P1_TRAIL;
            CELL_P2_TRAIL, CELL_P2_HEAD:  rgb = C_P2_TRAIL;
            CELL_CRASH:  rgb = (here == f_head_p1) ? C_P1_TRAIL : (here == f_head_p2) ? C_P2_TRAIL : C_CRASH;
            CELL_REWARD0, CELL_REWARD1:   rgb = (tex_gem  != COLOR_TRANSPARENT) ? tint(tex_gem,  C_REWARD1) : C_BG;
            CELL_REWARD2:                 rgb = (tex_star != COLOR_TRANSPARENT) ? tint(tex_star, C_REWARD3) : C_BG;
            default:                      rgb = C_BG;
        endcase
        if (in_p2_q2 && tex_p2 != COLOR_TRANSPARENT) rgb = tint(tex_p2, C_P2);
        if (in_p1_q2 && tex_p1 != COLOR_TRANSPARENT) rgb = tint(tex_p1, C_P1);

        // HUD band: Points bars (8 px per Point) and Lives squares; dark when paused.
        if (curr_y < 11'(HUD_ROWS * 16)) begin
            rgb = snap_paused ? 12'h000 : C_HUD;
            if (curr_y >= 11'd16 && curr_y < 11'd32) begin
                if (curr_x >= 11'd16 && curr_x < 11'd16 + {points_p1, 3'b000}) rgb = C_P1;
                if (curr_x < 11'd1264 && curr_x >= 11'd1264 - {points_p2, 3'b000}) rgb = C_P2;
            end
            if (curr_y >= 11'd40 && curr_y < 11'd56) begin
                if (curr_x >= 11'd16 && curr_x < 11'd112 && !off_p1[4] && off_p1[6:5] < lives_p1) rgb = C_P1_TRAIL;
                if (curr_x >= 11'd1168 && curr_x < 11'd1264 && !off_p2[4] && off_p2[6:5] < lives_p2) rgb = C_P2_TRAIL;
            end
        end

        if (visible && (curr_x < 11'(BORDER_PX) || curr_x >= 11'(1280 - BORDER_PX) ||
                        curr_y < 11'(BORDER_PX) || curr_y >= 11'(800 - BORDER_PX)))
            rgb = C_WHITE;
        if (!visible) rgb = 12'h000;
        {draw_r, draw_g, draw_b} = rgb;
    end
endmodule
