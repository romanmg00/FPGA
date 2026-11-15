// Colour of each pixel, from top to bottom priority: walls, HUD, block, empty arena.
// The block colour comes from the switches.
module drawcon(
    input              clk,
    input logic [10:0] curr_x, curr_y,
    input logic [10:0] blkpos1_x, blkpos1_y,
    input logic [10:0] blkpos2_x, blkpos2_y,
    input logic [11:0] sw,  // to change color in the future
    //input logic [1:0]  heading1, heading2,
    output logic [3:0] draw_r,
    output logic [3:0] draw_g,
    output logic [3:0] draw_b
);
    logic [4:0] add1_x, add1_y, add2_x, add2_y;
    logic [11:0] color1, color2;
    assign add1_x = curr_x + 8 - blkpos1_x;
    assign add1_y = curr_y + 8 - blkpos1_y;
    assign add2_x = curr_x + 8 - blkpos2_x;
    assign add2_y = curr_y + 8 - blkpos2_y;

    always_comb begin
        if ((curr_x < 11'd16 && (curr_y>=11'd64 && curr_y < 11'd800)) || 
            (curr_x < 11'd1280 && (curr_y >= 11'd64 && curr_y < 11'd80)) ||
            (curr_x < 11'd1280 && (curr_y >= 11'd784 && curr_y < 11'd800)) ||
            ((curr_x >= 11'd1264 && curr_x < 11'd1280) && (curr_y >= 11'd64 && curr_y < 11'd800))) begin // walls
            draw_r = 4'b1111;
            draw_g = 4'b1111;
            draw_b = 4'b1111;
        end else if (curr_y < 11'd64) begin // HUD
            draw_r = 4'b0100;
            draw_g = 4'b0100;
            draw_b = 4'b0100;
        end else if ((curr_x>= (blkpos1_x - 8)) && (curr_y>= (blkpos1_y - 8)) && 
                   (curr_x < (blkpos1_x + 24)) && (curr_y < (blkpos1_y + 24))) begin // bike 1
            // Blue
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
                   (curr_x < (blkpos2_x + 24)) && (curr_y < (blkpos2_y + 24))) begin // bike 2
            // Orange
            if(color2 == 12'h0F0) begin 
                draw_r = 4'b1111;
                draw_g = 4'b1000;
                draw_b = 4'b0000;
            end else begin 
                draw_r = color2[11:8];
                draw_g = color2[7:4];
                draw_b = color2[3:0];
            end
        end else begin // empty arena
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end


    bike_rom bike_rom_1 (
        .clka (clk),
        .ena (1'b1),
        .addra ({add1_y, add1_x}),
        // Outputs
        .douta (color1)
    );
    
    bike_rom bike_rom_2 (
        .clka (clk),
        .ena (1'b1),
        .addra ({add2_y, add2_x}),
        // Outputs
        .douta (color2)
    );

endmodule
