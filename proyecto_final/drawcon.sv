// Author: Roman (romanmg00). Changes by Alan (AIF31): Trails read from arena_map's port B (#40),
// sprite colour 000 drawn as transparent (#39).
// Colour of each pixel, from top to bottom priority: walls, HUD, bikes, Trails, empty arena.
// Trails come from arena_map's port B, read 2 pixels ahead (its latency is 2 cycles).
module drawcon(
    input              clk,                     // clk_pix (83.46 MHz)
    input logic [10:0] curr_x, curr_y,          // coordinates of the current pixel
    input logic [10:0] blkpos1_x, blkpos1_y,    // position of bike 1
    input logic [10:0] blkpos2_x, blkpos2_y,    // position of bike 2
    input logic [11:0] sw,                      // to change color in the future
    input logic [1:0]  heading1, heading2,      // 00: up, 01: right, 10: down, 11: left
    
    output logic [3:0] draw_r,                  // R component of the current pixel
    output logic [3:0] draw_g,                  // G component of the current pixel
    output logic [3:0] draw_b,                  // B component of the current pixel
    output logic [12:0] arena_addr,             // arena_map port B: {cy, cx} of the pixel 2 ahead
    input  logic [3:0]  arena_code              // code of the current pixel's Cell (2 cycles later)
);
    // ---------------------------------------------------------------
    // Internal signals (source -> destination)
    // ---------------------------------------------------------------
    logic [4:0] add1_x, add1_y, add2_x, add2_y; // relative position of the current pixel from the top-left corner of the bike sprite
    logic [11:0] color1, color2;                // color of each pixel of the bike sprites
    logic [9:0] add1, add2;                     // address of each pixel of the bike sprites
    logic [10:0] ahead_x;                       // x of the pixel 2 ahead, for the Arena read
    
    // ---------------------------------------------------------------
    // Address calculation (bike sprite -> ROM)
    // ---------------------------------------------------------------
    assign add1_x = curr_x + 8 - blkpos1_x;
    assign add1_y = curr_y + 8 - blkpos1_y;
    assign add2_x = curr_x + 8 - blkpos2_x;
    assign add2_y = curr_y + 8 - blkpos2_y;

    // Arena address: the Cell of the pixel 2 ahead, so its code arrives with the pixel.
    // In blanking curr_x wraps (2046, 2047), so the first two pixels read Cell 0 as they must.
    assign ahead_x    = curr_x + 11'd2;
    assign arena_addr = {curr_y[9:4], ahead_x[10:4]};

    // ---------------------------------------------------------------
    // Sprite address calculation
    // ---------------------------------------------------------------
    always_comb begin
        // Bike 1
        case(heading1) 
            2'b00: add1 = {add1_y, add1_x};    //Up
            2'b01: add1 = {~add1_x, add1_y};   //Right
            2'b10: add1 = {~add1_y, ~add1_x};  //Down
            2'b11: add1 = {add1_x, ~add1_y};   //Left
        endcase

        // Bike 2
        case(heading2) 
            2'b00: add2 = {add2_y, add2_x};    // Up
            2'b01: add2 = {~add2_x, add2_y};   // Right
            2'b10: add2 = {~add2_y, ~add2_x};  // Down
            2'b11: add2 = {add2_x, ~add2_y};   // Left
        endcase
    end

    // ---------------------------------------------------------------
    // Color assignment
    // ---------------------------------------------------------------

    bike_rom bike_rom_1 (
        .clka (clk),
        .ena (1'b1),
        .addra (add1),
        // Outputs
        .douta (color1)
    );
    
    bike_rom bike_rom_2 (
        .clka (clk),
        .ena (1'b1),
        .addra (add2),
        // Outputs
        .douta (color2)
    );
    // ---------------------------------------------------------------
    // Colors
    // Priorities: walls -> HUD -> bike 1 -> bike 2 -> Trails -> empty arena
    // Sprite pixels 000 are transparent (tools/png2coe.py), so a bike's box only covers
    // what is under its drawn pixels
    // ---------------------------------------------------------------
    always_comb begin
        if ((curr_x < 11'd16 && (curr_y>=11'd64 && curr_y < 11'd800)) || 
            (curr_x < 11'd1280 && (curr_y >= 11'd64 && curr_y < 11'd80)) ||
            (curr_x < 11'd1280 && (curr_y >= 11'd784 && curr_y < 11'd800)) ||
            ((curr_x >= 11'd1264 && curr_x < 11'd1280) && (curr_y >= 11'd64 && curr_y < 11'd800))) 
            begin // walls
            draw_r = 4'b1111;
            draw_g = 4'b1111;
            draw_b = 4'b1111;    
        end else if (curr_y < 11'd64) begin // HUD
            draw_r = 4'b0100;
            draw_g = 4'b0100;
            draw_b = 4'b0100;
        end else if ((curr_x>= (blkpos1_x - 8)) && (curr_y>= (blkpos1_y - 8)) && 
                   (curr_x < (blkpos1_x + 24)) && (curr_y < (blkpos1_y + 24)) &&
                   (color1 != 12'h000)) begin // bike 1, not transparent
            // P1: Blue
            if(color1 == 12'h0F0) begin
                draw_r = 4'b0000;
                draw_g = 4'b1101;
                draw_b = 4'b1111;
            end else begin
                draw_r = color1[11:8];
                draw_g = color1[7:4];
                draw_b = color1[3:0];
            end
        end else if ((curr_x>= (blkpos2_x - 8)) && (curr_y>= (blkpos2_y - 8)) && 
                   (curr_x < (blkpos2_x + 24)) && (curr_y < (blkpos2_y + 24)) &&
                   (color2 != 12'h000)) begin // bike 2, not transparent
            // P2: Orange
            if(color2 == 12'h0F0) begin
                draw_r = 4'b1111;
                draw_g = 4'b1000;
                draw_b = 4'b0000;
            end else begin 
                draw_r = color2[11:8];
                draw_g = color2[7:4];
                draw_b = color2[3:0];
            end
        // Trails only: heads (3, 5) are not painted, because the bike slides into its head
        // Cell during the next step (ADR 0010) and a painted head would show ahead of it.
        end else if (arena_code == 4'd2) begin  // P1 Trail, a darker cyan
            draw_r = 4'b0000;
            draw_g = 4'b0110;
            draw_b = 4'b1000;
        end else if (arena_code == 4'd4) begin  // P2 Trail, a darker orange
            draw_r = 4'b1000;
            draw_g = 4'b0100;
            draw_b = 4'b0000;
        end else begin // TODO: add another background
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end


endmodule
