// Colour of each pixel, from top to bottom priority: walls, HUD, block, empty arena.
// The block colour comes from the switches.
module drawcon(
    input              clk,                     // clk_pix (83.46 MHz)
    input logic [10:0] curr_x, curr_y,          // coordinates of the current pixel
    input logic [10:0] blkpos1_x, blkpos1_y,    // position of bike 1
    input logic [10:0] blkpos2_x, blkpos2_y,    // position of bike 2
    input logic [11:0] sw,                      // to change color in the future
    input logic [1:0]  heading1, heading2,      // 00: up, 01: right, 10: down, 11: left
    
    output logic [3:0] draw_r,                  // R component of the current pixel
    output logic [3:0] draw_g,                  // G component of the current pixel
    output logic [3:0] draw_b                   // B component of the current pixel
);
    // ---------------------------------------------------------------
    // Internal signals (source -> destination)
    // ---------------------------------------------------------------
    logic [4:0] add1_x, add1_y, add2_x, add2_y; // relative position of the current pixel from the top-left corner of the bike sprite
    logic [11:0] color1, color2;                // color of each pixel of the bike sprites
    logic [9:0] add1, add2;                     // address of each pixel of the bike sprites
    
    // ---------------------------------------------------------------
    // Address calculation (bike sprite -> ROM)
    // ---------------------------------------------------------------
    assign add1_x = curr_x + 8 - blkpos1_x;
    assign add1_y = curr_y + 8 - blkpos1_y;
    assign add2_x = curr_x + 8 - blkpos2_x;
    assign add2_y = curr_y + 8 - blkpos2_y;

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
    // Priorities: walls -> HUD -> bike 1 -> bike 2 -> empty arena
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
                   (curr_x < (blkpos1_x + 24)) && (curr_y < (blkpos1_y + 24))) begin // bike 1
            // P1: Blue
            if(color1 == 12'h0F0) begin // TODO: add elseif h000 transparent
                draw_r = 4'b0000;
                draw_g = 4'b1101;
                draw_b = 4'b1111;
            end else begin
                draw_r = color1[11:8];
                draw_g = color1[7:4];
                draw_b = color1[3:0];
            end
        end else if ((curr_x>= (blkpos2_x - 8)) && (curr_y>= (blkpos2_y - 8)) && 
                   (curr_x < (blkpos2_x + 24)) && (curr_y < (blkpos2_y + 24))) begin // bike 2
            // P2: Orange
            if(color2 == 12'h0F0) begin // TODO: add elseif h000 transparent
                draw_r = 4'b1111;
                draw_g = 4'b1000;
                draw_b = 4'b0000;
            end else begin 
                draw_r = color2[11:8];
                draw_g = color2[7:4];
                draw_b = color2[3:0];
            end
        end else begin // TODO: add another background
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end


endmodule
