// Author: Alan (AIF31).
// Points, Lives and the play or crown icon in the 64 px band, laid out as juego/hud.py.
module hud_layer (
    input  logic        clk,                    // clk_pix
    input  logic        rst,
    input  logic [10:0] curr_x, curr_y,
    // From seg7_link
    input  logic        pause,                  // SW0
    input  logic [5:0]  points_p1, points_p2,
    input  logic [1:0]  lives_p1, lives_p2,
    input  logic        waiting_start,
    input  logic [1:0]  result,                 // 0 Match on, 1 P1 wins, 2 P2 wins, 3 Draw
    input  logic        crashed_p1, crashed_p2,
    output logic [11:0] hud_color               // colour of (curr_x, curr_y)
);

    // ===============================================================
    // 1. Values of this frame
    // ===============================================================
    logic [3:0] tens_p1, ones_p1, tens_p2, ones_p2;
    logic [6:0] segs_tens_p1, segs_ones_p1, segs_tens_p2, segs_ones_p2;   // [0] = a ... [6] = g, active low

    assign tens_p1 = points_p1 / 10;
    assign ones_p1 = points_p1 % 10;
    assign tens_p2 = points_p2 / 10;
    assign ones_p2 = points_p2 % 10;

    sevenseg u_tens_p1 (.num(tens_p1), .a(segs_tens_p1[0]), .b(segs_tens_p1[1]), .c(segs_tens_p1[2]),
        .d(segs_tens_p1[3]), .e(segs_tens_p1[4]), .f(segs_tens_p1[5]), .g(segs_tens_p1[6]));
    sevenseg u_ones_p1 (.num(ones_p1), .a(segs_ones_p1[0]), .b(segs_ones_p1[1]), .c(segs_ones_p1[2]),
        .d(segs_ones_p1[3]), .e(segs_ones_p1[4]), .f(segs_ones_p1[5]), .g(segs_ones_p1[6]));
    sevenseg u_tens_p2 (.num(tens_p2), .a(segs_tens_p2[0]), .b(segs_tens_p2[1]), .c(segs_tens_p2[2]),
        .d(segs_tens_p2[3]), .e(segs_tens_p2[4]), .f(segs_tens_p2[5]), .g(segs_tens_p2[6]));
    sevenseg u_ones_p2 (.num(ones_p2), .a(segs_ones_p2[0]), .b(segs_ones_p2[1]), .c(segs_ones_p2[2]),
        .d(segs_ones_p2[3]), .e(segs_ones_p2[4]), .f(segs_ones_p2[5]), .g(segs_ones_p2[6]));

    logic [6:0] lit_tens_p1 = 7'd0, lit_ones_p1 = 7'd0, lit_tens_p2 = 7'd0, lit_ones_p2 = 7'd0;   // 1 lit
    logic [1:0] frame_lives_p1 = 2'd0, frame_lives_p2 = 2'd0, frame_result = 2'd0;
    logic       frame_crashed_p1 = 1'b0, frame_crashed_p2 = 1'b0;
    logic       frame_wait = 1'b0, frame_crown = 1'b0;
    logic [4:0] blink = 5'd0;            // [4] = 1 hides blinking items
    logic       crown;                   // Match over, after its Crash pause
    logic       in_crash, frame_in_crash;
    assign crown          = (result != 2'd0) && !crashed_p1 && !crashed_p2;
    assign in_crash       = crashed_p1 || crashed_p2;
    assign frame_in_crash = frame_crashed_p1 || frame_crashed_p2;

    // Copied once per frame, and in every cycle of rst.
    always_ff @(posedge clk)
    begin
        if (rst || (curr_x == 11'd0 && curr_y == 11'd800))
        begin
            lit_tens_p1      <= ~segs_tens_p1;
            lit_ones_p1      <= ~segs_ones_p1;
            lit_tens_p2      <= ~segs_tens_p2;
            lit_ones_p2      <= ~segs_ones_p2;
            frame_lives_p1   <= lives_p1;
            frame_lives_p2   <= lives_p2;
            frame_result     <= result;
            frame_crashed_p1 <= crashed_p1;
            frame_crashed_p2 <= crashed_p2;
            frame_wait       <= waiting_start;
            frame_crown      <= crown;
            if (rst || {waiting_start, crown, in_crash} != {frame_wait, frame_crown, frame_in_crash})
                blink <= 5'd0;
            else if (!pause)
                blink <= blink + 5'd1;
        end
    end

    // Blinking: the play icon while waiting for Start, a crashed Player's digits.
    logic show_play, show_digits_p1, show_digits_p2;
    assign show_play      = frame_wait && !blink[4];
    assign show_digits_p1 = !(frame_crashed_p1 && blink[4]);
    assign show_digits_p2 = !(frame_crashed_p2 && blink[4]);

    // ===============================================================
    // 2. Rows of the current line
    // ===============================================================
    // Digits in rows 21-52 (8 x 16 glyph at scale 2), icons in rows 29-44.
    logic [10:0] digit_y;                // glyph row = digit_y[4:1]
    logic [10:0] icon_y;                 // icon row = icon_y[3:0]
    assign digit_y = curr_y - 11'd21;
    assign icon_y  = curr_y - 11'd29;

    // Word {icon, row}, bit c = column c. Icon 0 Life, 1 lost Life, 2 play, 3 crown.
    logic [15:0] icon_rom [0:63];
    initial $readmemh("hud_icons.mem", icon_rom);

    logic        digit_row, icon_row;
    logic        row_a, row_bf, row_g, row_ce, row_d;   // the line crosses these segments
    logic [15:0] life_bits, lost_bits, play_bits, crown_bits;
    always_ff @(posedge clk)
    begin
        digit_row  <= (curr_y >= 11'd21) && (curr_y < 11'd53);
        icon_row   <= (curr_y >= 11'd29) && (curr_y < 11'd45);
        row_a      <= (digit_y[4:1] <= 4'd1);
        row_bf     <= (digit_y[4:1] >= 4'd1) && (digit_y[4:1] <= 4'd7);
        row_g      <= (digit_y[4:1] == 4'd7) || (digit_y[4:1] == 4'd8);
        row_ce     <= (digit_y[4:1] >= 4'd8) && (digit_y[4:1] <= 4'd14);
        row_d      <= (digit_y[4:1] >= 4'd14);
        life_bits  <= icon_rom[{2'd0, icon_y[3:0]}];
        lost_bits  <= icon_rom[{2'd1, icon_y[3:0]}];
        play_bits  <= icon_rom[{2'd2, icon_y[3:0]}];
        crown_bits <= icon_rom[{2'd3, icon_y[3:0]}];
    end

    // ===============================================================
    // 3. Boxes of the next pixel, 16 px wide: first column, and column in the box
    // ===============================================================
    logic [10:0] next_x;
    logic        p2;                     // right half: P2
    assign next_x = curr_x + 11'd1;
    assign p2     = (next_x >= 11'd640);

    // Digits: P1 at x 24 and 44, P2 at 1220 and 1240.
    logic [10:0] digit_x0, digit_dx;
    logic [6:0]  digit_lit;
    assign digit_x0  = (next_x < 11'd44)   ? 11'd24   :
                       (next_x < 11'd640)  ? 11'd44   :
                       (next_x < 11'd1240) ? 11'd1220 : 11'd1240;
    assign digit_lit = (next_x < 11'd44)   ? lit_tens_p1 :
                       (next_x < 11'd640)  ? lit_ones_p1 :
                       (next_x < 11'd1240) ? lit_tens_p2 : lit_ones_p2;
    assign digit_dx  = next_x - digit_x0;

    // Lives: P1 at x 68, 88, 108, P2 at 1156, 1176, 1196. Life k is full while k < Lives.
    logic [10:0] life_x0, life_dx;
    logic [1:0]  life_k;
    logic        life_full;
    assign life_x0 = (next_x < 11'd88)   ? 11'd68   :
                     (next_x < 11'd108)  ? 11'd88   :
                     (next_x < 11'd640)  ? 11'd108  :
                     (next_x < 11'd1176) ? 11'd1156 :
                     (next_x < 11'd1196) ? 11'd1176 : 11'd1196;
    assign life_dx = next_x - life_x0;
    always_comb
    begin
        case (life_x0)
            11'd68, 11'd1156: life_k = 2'd0;
            11'd88, 11'd1176: life_k = 2'd1;
            default:          life_k = 2'd2;
        endcase
    end
    assign life_full = (life_k < (p2 ? frame_lives_p2 : frame_lives_p1));

    // Play or crown at x 632.
    logic [10:0] state_dx;
    assign state_dx = next_x - 11'd632;

    // ===============================================================
    // 4. Colour of the next pixel
    // ===============================================================
    // Glyph columns (juego/font.py): a, d, g in 1-6; e, f in 0-1; b, c in 6-7.
    logic [2:0] glyph_col;
    logic       mid, left, right;
    logic [6:0] pixel_segments;          // segments that cover the pixel, [0] = a ... [6] = g
    assign glyph_col      = digit_dx[3:1];
    assign mid            = (glyph_col >= 3'd1) && (glyph_col <= 3'd6);
    assign left           = (glyph_col <= 3'd1);
    assign right          = (glyph_col >= 3'd6);
    assign pixel_segments = {mid && row_g, left && row_bf, left && row_ce, mid && row_d,
                             right && row_ce, right && row_bf, mid && row_a};

    logic digit_on, life_on, state_on;
    assign digit_on = digit_row && (digit_dx < 11'd16) && (p2 ? show_digits_p2 : show_digits_p1) &&
                      ((digit_lit & pixel_segments) != 7'd0);
    assign life_on  = icon_row && (life_dx < 11'd16) && (life_full ? life_bits[life_dx[3:0]] : lost_bits[life_dx[3:0]]);
    assign state_on = icon_row && (state_dx < 11'd16) &&
                      (frame_crown ? crown_bits[state_dx[3:0]] : show_play && play_bits[state_dx[3:0]]);

    logic [11:0] player_color, state_color, next_color;
    assign player_color = p2 ? 12'hF80 : 12'h0DF;
    assign state_color  = (frame_crown && frame_result == 2'd1) ? 12'h0DF :   // P1's crown
                          (frame_crown && frame_result == 2'd2) ? 12'hF80 :   // P2's crown
                                                                  12'hFFF;    // play, Draw crown
    assign next_color   = (digit_on || life_on) ? player_color :
                          state_on              ? state_color  : 12'h000;

    always_ff @(posedge clk)
        hud_color <= next_color;

endmodule
