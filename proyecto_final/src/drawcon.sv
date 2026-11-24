// Author: Roman (romanmg00). Changes by Alan (AIF31): Trails read from arena_map's port B (#40),
// sprite colour 000 drawn as transparent (#39).
// Colour of each pixel. Priority: walls, HUD, bike 1, bike 2, Trails, empty Arena.
module drawcon(
    input              clk,                     // clk_pix
    input logic [10:0] curr_x, curr_y,          // current pixel
    input logic [10:0] blkpos1_x, blkpos1_y,    // bike 1 drawn position (bike_glide), in pixels
    input logic [10:0] blkpos2_x, blkpos2_y,    // bike 2 drawn position (bike_glide), in pixels
    input logic [11:0] sw,                      // not used yet
    input logic [1:0]  heading1, heading2,      // 0 up, 1 right, 2 down, 3 left

    output logic [3:0] draw_r,
    output logic [3:0] draw_g,
    output logic [3:0] draw_b,
    output logic [12:0] arena_addr,             // arena_map: {cy, cx} of the pixel 2 ahead
    input  logic [3:0]  arena_code              // that Cell's code, 2 cycles later
);
    logic [4:0] add1_x, add1_y, add2_x, add2_y; // pixel inside each 32 x 32 sprite box
    logic [11:0] color1, color2;                // sprite colour of that pixel
    logic [9:0] add1, add2;                     // bike_rom address
    logic [10:0] ahead_x;

    // The 32 x 32 sprite box starts 8 px up and left of the drawn 16 px square, so it is centred on it.
    assign add1_x = ahead_x + 8 - blkpos1_x;
    assign add1_y = curr_y + 8 - blkpos1_y;
    assign add2_x = ahead_x + 8 - blkpos2_x;
    assign add2_y = curr_y + 8 - blkpos2_y;

    // Read 2 pixels ahead, so the code arrives with its pixel (2-cycle latency).
    assign ahead_x    = curr_x + 11'd2;
    assign arena_addr = {curr_y[9:4], ahead_x[10:4]};

    // The sprite points up; each Heading turns it by swapping and inverting x and y.
    always_comb begin
        case(heading1)
            2'b00: add1 = {add1_y, add1_x};    // Up
            2'b01: add1 = {~add1_x, add1_y};   // Right
            2'b10: add1 = {~add1_y, ~add1_x};  // Down
            2'b11: add1 = {add1_x, ~add1_y};   // Left
        endcase

        case(heading2)
            2'b00: add2 = {add2_y, add2_x};    // Up
            2'b01: add2 = {~add2_x, add2_y};   // Right
            2'b10: add2 = {~add2_y, ~add2_x};  // Down
            2'b11: add2 = {add2_x, ~add2_y};   // Left
        endcase
    end

    bike_rom bike_rom_1 (
        .clka (clk),
        .ena (1'b1),
        .addra (add1),
        .douta (color1)
    );

    bike_rom bike_rom_2 (
        .clka (clk),
        .ena (1'b1),
        .addra (add2),
        .douta (color2)
    );

    // Sprite colour 000 is transparent; 0F0 is replaced by the Player's colour.
    always_comb begin
        if ((curr_x < 11'd16 && (curr_y>=11'd64 && curr_y < 11'd800)) ||                // left wall, cx 0
            (curr_x < 11'd1280 && (curr_y >= 11'd64 && curr_y < 11'd80)) ||             // top wall, cy 4
            (curr_x < 11'd1280 && (curr_y >= 11'd784 && curr_y < 11'd800)) ||           // bottom wall, cy 49
            ((curr_x >= 11'd1264 && curr_x < 11'd1280) && (curr_y >= 11'd64 && curr_y < 11'd800)))  // right wall, cx 79
            begin // walls: white
            draw_r = 4'b1111;
            draw_g = 4'b1111;
            draw_b = 4'b1111;
        end else if (curr_y < 11'd64) begin // HUD: cy 0-3, grey
            draw_r = 4'b0100;
            draw_g = 4'b0100;
            draw_b = 4'b0100;
        end else if ((curr_x>= (blkpos1_x - 8)) && (curr_y>= (blkpos1_y - 8)) &&   // box left and top
                   (curr_x < (blkpos1_x + 24)) && (curr_y < (blkpos1_y + 24)) &&   // box right and bottom
                   (color1 != 12'h000)) begin 
            if(color1 == 12'h0F0) begin    // P1 cyan
                draw_r = 4'b0000;
                draw_g = 4'b1101;
                draw_b = 4'b1111;
            end else begin                 
                draw_r = color1[11:8];
                draw_g = color1[7:4];
                draw_b = color1[3:0];
            end
        end else if ((curr_x>= (blkpos2_x - 8)) && (curr_y>= (blkpos2_y - 8)) &&   // box left and top
                   (curr_x < (blkpos2_x + 24)) && (curr_y < (blkpos2_y + 24)) &&   // box right and bottom
                   (color2 != 12'h000)) begin 
            if(color2 == 12'h0F0) begin    // P2 orange
                draw_r = 4'b1111;
                draw_g = 4'b1000;
                draw_b = 4'b0000;
            end else begin
                draw_r = color2[11:8];
                draw_g = color2[7:4];
                draw_b = color2[3:0];
            end
        // Trails and empty Arena are read from arena_map's port B. The 4-bit code is:
        // 0 EMPTY, 1 WALL, 2 P1 Trail, 3 P1 head, 4 P2 Trail, 5 P2 head, 8-10 Rewards
        end else if (arena_code == 4'd2) begin  // P1 Trail
            draw_r = 4'b0000;
            draw_g = 4'b0110;
            draw_b = 4'b1000;
        end else if (arena_code == 4'd4) begin  // P2 Trail
            draw_r = 4'b1000;
            draw_g = 4'b0100;
            draw_b = 4'b0000;
        end else begin                          // empty Arena
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end

endmodule
