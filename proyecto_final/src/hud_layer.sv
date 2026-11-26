// Author: Alan (AIF31), proposed for Roman's HUD (contract section 4).
// Points, Lives and the play or crown icon in the 64 px band, laid out as prototipos/tron_fpga/juego/hud.py.
module hud_layer (
    input  logic        clk,                    // clk_pix
    input  logic [10:0] curr_x, curr_y,
    input  logic [5:0]  points_p1, points_p2,   // from seg7_link
    input  logic [1:0]  lives_p1, lives_p2,     // from seg7_link
    input  logic        waiting_start,          // from seg7_link: Bikes at their starts, waiting for Start
    input  logic [1:0]  result,                 // 0 Match on, 1 P1 wins, 2 P2 wins, 3 Draw
    input  logic [1:0]  crashed,                // {P2, P1}, until the Crash pause ends
    output logic [11:0] hud_color               // colour of (curr_x, curr_y)
);

    // ===============================================================
    // 1. Points, Lives and state of this frame
    // ===============================================================
    logic [3:0] tens_p1, ones_p1, tens_p2, ones_p2;
    logic [6:0] segs_tens_p1, segs_ones_p1, segs_tens_p2, segs_ones_p2;   // sevenseg: [0] = a ... [6] = g, active low

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

    logic [6:0] lit_tens_p1 = 7'd0, lit_ones_p1 = 7'd0;    // [0] = a ... [6] = g, 1 lit
    logic [6:0] lit_tens_p2 = 7'd0, lit_ones_p2 = 7'd0;
    logic [1:0] frame_lives_p1 = 2'd0, frame_lives_p2 = 2'd0;

    logic       crown;                   // the Match is over, after its Crash pause
    logic       frame_wait = 1'b0, frame_crown = 1'b0;
    logic [1:0] frame_result = 2'd0, frame_crashed = 2'd0;
    logic [4:0] blink = 5'd0;            // frames since the phase changed; [4] = 1: blinking items off
    assign crown = (result != 2'd0) && (crashed == 2'b00);

    // Copied once per frame, so the whole band shows the same values.
    always_ff @(posedge clk)
    begin
        if (curr_x == 0 && curr_y == 800)
        begin
            lit_tens_p1    <= ~segs_tens_p1;
            lit_ones_p1    <= ~segs_ones_p1;
            lit_tens_p2    <= ~segs_tens_p2;
            lit_ones_p2    <= ~segs_ones_p2;
            frame_lives_p1 <= lives_p1;
            frame_lives_p2 <= lives_p2;
            frame_wait     <= waiting_start;
            frame_crown    <= crown;
            frame_result   <= result;
            frame_crashed  <= crashed;
            if ({waiting_start, crown, crashed != 2'b00} != {frame_wait, frame_crown, frame_crashed != 2'b00})
                blink <= 5'd0;
            else
                blink <= blink + 5'd1;
        end
    end

    // 16 frames on, 16 off: the play icon while waiting for Start, a crashed Player's digits.
    logic show_play, show_p1, show_p2;
    assign show_play = frame_wait && !blink[4];
    assign show_p1   = !(frame_crashed[0] && blink[4]);
    assign show_p2   = !(frame_crashed[1] && blink[4]);

    logic [11:0] crown_color;            // the winner's colour, white for a Draw
    always_comb
    begin
        case (frame_result)
            2'd1:    crown_color = 12'h0DF;
            2'd2:    crown_color = 12'hF80;
            default: crown_color = 12'hFFF;
        endcase
    end

    // ===============================================================
    // 2. Rows of the current line
    // ===============================================================
    // Digits: rows 21-52, an 8 x 16 glyph at scale 2 (juego/font.py). Icons: rows 29-44.
    logic [10:0] digit_y;                // curr_y - 21; glyph row = digit_y[4:1]
    logic [10:0] icon_y;                 // curr_y - 29; icon row = icon_y[3:0]
    assign digit_y = curr_y - 11'd21;
    assign icon_y  = curr_y - 11'd29;

    // Icons: word {icon, row}, bit c = column c. Icon 0 full Life, 1 lost Life, 2 play, 3 crown.
    logic [15:0] icon_rom [0:63];
    initial $readmemh("hud_icons.mem", icon_rom);

    logic        digit_row;              // the line crosses the digits
    logic        row_a, row_bf, row_g, row_ce, row_d;   // the line crosses these segments
    logic        icon_row;               // the line crosses the icons
    logic [15:0] life_bits, lost_bits, play_bits, crown_bits;   // this line of each icon
    always_ff @(posedge clk)
    begin
        digit_row <= (curr_y >= 11'd21) && (curr_y < 11'd53);
        row_a     <= (digit_y[4:1] <= 4'd1);
        row_bf    <= (digit_y[4:1] >= 4'd1) && (digit_y[4:1] <= 4'd7);
        row_g     <= (digit_y[4:1] == 4'd7) || (digit_y[4:1] == 4'd8);
        row_ce    <= (digit_y[4:1] >= 4'd8) && (digit_y[4:1] <= 4'd14);
        row_d     <= (digit_y[4:1] >= 4'd14);
        icon_row  <= (curr_y >= 11'd29) && (curr_y < 11'd45);
        life_bits <= icon_rom[{2'd0, icon_y[3:0]}];
        lost_bits <= icon_rom[{2'd1, icon_y[3:0]}];
        play_bits <= icon_rom[{2'd2, icon_y[3:0]}];
        crown_bits <= icon_rom[{2'd3, icon_y[3:0]}];
    end

    // ===============================================================
    // 3. The next pixel: digit, Life or state box, and its column in the box
    // ===============================================================
    logic [10:0] next_x;                 // curr_x + 1
    assign next_x = curr_x + 11'd1;

    // Digits 16 px wide: P1 at x 24 and 44, P2 at 1220 and 1240.
    logic        in_digit;
    logic [6:0]  digit_lit;              // that digit's lit segments
    logic [10:0] digit_dx;               // column in the box; glyph column = digit_dx[3:1]
    logic [11:0] digit_color;
    always_comb
    begin
        in_digit    = 1'b1;
        digit_lit   = lit_tens_p1;
        digit_dx    = next_x - 11'd24;
        digit_color = 12'h0DF;           // P1 cyan
        if (next_x >= 11'd24 && next_x < 11'd40)
        begin
            in_digit  = show_p1;
            digit_lit = lit_tens_p1;
            digit_dx  = next_x - 11'd24;
        end
        else if (next_x >= 11'd44 && next_x < 11'd60)
        begin
            in_digit  = show_p1;
            digit_lit = lit_ones_p1;
            digit_dx  = next_x - 11'd44;
        end
        else if (next_x >= 11'd1220 && next_x < 11'd1236)
        begin
            in_digit    = show_p2;
            digit_lit   = lit_tens_p2;
            digit_dx    = next_x - 11'd1220;
            digit_color = 12'hF80;       // P2 orange
        end
        else if (next_x >= 11'd1240 && next_x < 11'd1256)
        begin
            in_digit    = show_p2;
            digit_lit   = lit_ones_p2;
            digit_dx    = next_x - 11'd1240;
            digit_color = 12'hF80;
        end
        else
            in_digit = 1'b0;
    end

    // Lives 16 px wide, Life k at x 68 + 20k for P1 and 1156 + 20k for P2; Life k is full while k < Lives.
    logic        in_life;
    logic        life_full;
    logic [10:0] life_dx;                // column in the box
    logic [11:0] life_color;
    always_comb
    begin
        in_life    = 1'b1;
        life_full  = 1'b0;
        life_dx    = next_x - 11'd68;
        life_color = 12'h0DF;
        if (next_x >= 11'd68 && next_x < 11'd84)
        begin
            life_full = (frame_lives_p1 > 2'd0);
            life_dx   = next_x - 11'd68;
        end
        else if (next_x >= 11'd88 && next_x < 11'd104)
        begin
            life_full = (frame_lives_p1 > 2'd1);
            life_dx   = next_x - 11'd88;
        end
        else if (next_x >= 11'd108 && next_x < 11'd124)
        begin
            life_full = (frame_lives_p1 > 2'd2);
            life_dx   = next_x - 11'd108;
        end
        else if (next_x >= 11'd1156 && next_x < 11'd1172)
        begin
            life_full  = (frame_lives_p2 > 2'd0);
            life_dx    = next_x - 11'd1156;
            life_color = 12'hF80;
        end
        else if (next_x >= 11'd1176 && next_x < 11'd1192)
        begin
            life_full  = (frame_lives_p2 > 2'd1);
            life_dx    = next_x - 11'd1176;
            life_color = 12'hF80;
        end
        else if (next_x >= 11'd1196 && next_x < 11'd1212)
        begin
            life_full  = (frame_lives_p2 > 2'd2);
            life_dx    = next_x - 11'd1196;
            life_color = 12'hF80;
        end
        else
            in_life = 1'b0;
    end

    // Play or crown icon, 16 px wide at x 632.
    logic        in_state;
    logic [10:0] state_dx;               // column in the box
    assign in_state = (next_x >= 11'd632) && (next_x < 11'd648);
    assign state_dx = next_x - 11'd632;

    // ===============================================================
    // 4. Colour of the next pixel
    // ===============================================================
    // Segments of the glyph (juego/font.py): a, d, g in columns 1-6, e, f in 0-1, b, c in 6-7.
    logic [2:0] gx;
    logic       col_mid, col_left, col_right;
    logic [6:0] here;                    // segments that cover the pixel, [0] = a ... [6] = g
    logic       digit_on, life_on, state_on;
    assign gx        = digit_dx[3:1];
    assign col_mid   = (gx >= 3'd1) && (gx <= 3'd6);
    assign col_left  = (gx <= 3'd1);
    assign col_right = (gx >= 3'd6);
    assign here      = {col_mid   && row_g,     // g
                        col_left  && row_bf,    // f
                        col_left  && row_ce,    // e
                        col_mid   && row_d,     // d
                        col_right && row_ce,    // c
                        col_right && row_bf,    // b
                        col_mid   && row_a};    // a
    assign digit_on  = in_digit && digit_row && ((digit_lit & here) != 7'd0);
    assign life_on   = in_life && icon_row && (life_full ? life_bits[life_dx[3:0]] : lost_bits[life_dx[3:0]]);
    assign state_on  = in_state && icon_row &&
                       (frame_crown ? crown_bits[state_dx[3:0]] : (show_play && play_bits[state_dx[3:0]]));

    always_ff @(posedge clk)
    begin
        if (digit_on)
            hud_color <= digit_color;
        else if (life_on)
            hud_color <= life_color;
        else if (state_on)
            hud_color <= frame_crown ? crown_color : 12'hFFF;
        else
            hud_color <= 12'h000;        // band background
    end

endmodule
