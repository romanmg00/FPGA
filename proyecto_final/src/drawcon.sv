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
    // ===============================================================
    // 1. defining the adress for the memory maps
    // ===============================================================
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
    // ===============================================================
    // 2. reading the memory maps
    // ===============================================================
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

    // ===============================================================
    // 3. Drawing: pixels assigned to wall, player 1, player 2, hud and empty arena
    // 3.1 pixels assigned to wall, player 1, player 2, hud
    // ===============================================================
    logic [11:0] color;
    logic wall;
    logic player1;
    logic player2;
    logic hud;
    // pixels assigned to wall
    assign wall = (curr_x < 11'd16 && (curr_y>=11'd64 && curr_y < 11'd800)) ||                               // left wall, cx 0
            (curr_x < 11'd1280 && (curr_y >= 11'd64 && curr_y < 11'd80)) ||                                 // top wall, cy 4
            (curr_x < 11'd1280 && (curr_y >= 11'd784 && curr_y < 11'd800)) ||                               // bottom wall, cy 49
            ((curr_x >= 11'd1264 && curr_x < 11'd1280) && (curr_y >= 11'd64 && curr_y < 11'd800));         // right wall, cx 79
    // pixels assigned to player 1
    assign player1 = ((curr_x>= (blkpos1_x - 8)) && (curr_y>= (blkpos1_y - 8)) &&                         // box left and top
                   (curr_x < (blkpos1_x + 24)) && (curr_y < (blkpos1_y + 24)) &&                         // box right and bottom
                   (color1 != 12'h000)); 
    // pixels assigned to player 2
    assign player2 = ((curr_x>= (blkpos2_x - 8)) && (curr_y>= (blkpos2_y - 8)) &&   // box left and top
                   (curr_x < (blkpos2_x + 24)) && (curr_y < (blkpos2_y + 24)) &&   // box right and bottom
                   (color2 != 12'h000)); 
    // pixels assigned to hud
    assign hud = (curr_y < 11'd64);  
    // ===============================================================
    // 3.2. Frame counter: the grid line's pulse phase is frame_cnt[4:3].    
    // ===============================================================   
    logic [4:0] frame_cnt = 5'b0;
    always_ff @(posedge clk)
    begin
        if(curr_x == 0 && curr_y == 800) begin
            frame_cnt <= frame_cnt + 1'b1;
        end
    end
    // ===============================================================
    // 3.3. empty arena color  
    // ===============================================================   
    logic [10:0] sky_y;      // row inside arena: curr_y - 64, so each band edge falls on a grid line
    logic [3:0]  sky_level;  // 0-5, band every 128 px
    assign sky_y = curr_y - 11'd64;
    assign sky_level = sky_y >> 7;

    
    // Striped sun (prototype's synthwave look): radius 160, centred on the Arena at (640, 432).
    // sun_rows.mem has one 21-bit word per row, from y = 272 to y = 592:
    // {lit, half width [7:0], colour [11:0]}; lit = 0 for a cut row (a stripe).
    logic [20:0] sun_rom [0:320];
    initial $readmemh("sun_rows.mem", sun_rom);

    logic [10:0] sun_row;    // row inside the sun: curr_y - 272
    logic [20:0] sun_word;   // that row's word
    logic        sun_lit;    // 1: the row is drawn, 0: a stripe
    logic [7:0]  sun_hw;     // half width of the row, in px
    logic [11:0] sun_color;  // colour of the row
    logic        sun;        // the pixel is inside the sun
    assign sun_row   = curr_y - 11'd272;
    assign sun_word  = sun_rom[sun_row[8:0]];
    assign sun_lit   = sun_word[20];
    assign sun_hw    = sun_word[19:12];
    assign sun_color = sun_word[11:0];
    assign sun = (curr_y >= 11'd272) && (curr_y <= 11'd592) && sun_lit &&
                 (curr_x >= 11'd640 - sun_hw) && (curr_x < 11'd640 + sun_hw);

    // ===============================================================
    // 3.4. Drawing pixels  
    // ===============================================================   
    always_comb begin
        if (wall) begin // walls: white
            color = 12'hFFF;
        end else if(hud) begin
            color = 12'h444;
        end else if (player1) begin 
                if(color1 == 12'h0F0) begin    // P1 cyan
                    color = 12'h0DF;
                end else begin                 
                    color = color1;
                end
        end else if (player2) begin 
                if(color2 == 12'h0F0) begin    // P2 orange
                    color = 12'hF80;
                end else begin
                    color = color2;
                end
        // Trails and empty Arena are read from arena_map's port B. The 4-bit code is:
        // 0 EMPTY, 1 WALL, 2 P1 Trail, 3 P1 head, 4 P2 Trail, 5 P2 head, 8-10 Rewards
        end else if (arena_code == 4'd2) begin  // P1 Trail
            color = 12'h068;
        end else if (arena_code == 4'd4) begin  // P2 Trail
            color = 12'h840;
        end else begin                          
            if(curr_x[4:0]==0 || curr_y[4:0]==0)begin // Purple grid line
                case(frame_cnt[4:3])                  // Breathing effect
                    2'b00: color = 12'h818;
                    2'b01: color = 12'hA2C;
                    2'b10: color = 12'hD2E;
                    2'b11: color = 12'hA2C;
                endcase
            end else if (curr_x[4:0]==1 || curr_x[4:0]==31 || curr_y[4:0]==1 || curr_y[4:0]==31) begin // Grid glow
                color= {sky_level+4'd3, 4'h0, sky_level+1'b1+4'd3};
            end else if (sun) begin                 // striped sun, under the grid
                color = sun_color;
            end else begin                          // empty arena
                color = {sky_level, 4'h0, sky_level+1'b1};
            end
        end
        draw_r = color[11:8];
        draw_g = color[7:4];
        draw_b = color[3:0];
    end

endmodule
