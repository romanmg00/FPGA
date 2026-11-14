// Colour of each pixel, from top to bottom priority: walls, HUD, block, empty arena.
// The block colour comes from the switches.
module drawcon(
    input logic [10:0] curr_x, curr_y,
    input logic [10:0] blkpos1_x, blkpos1_y,
    input logic [10:0] blkpos2_x, blkpos2_y,
    input logic [11:0] sw,  // to change color in the future
    //input logic [1:0]  heading1, heading2,
    output logic [3:0] draw_r,
    output logic [3:0] draw_g,
    output logic [3:0] draw_b
);

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
        end else if ((curr_x>= blkpos1_x && curr_y>= blkpos1_y) && 
                   (curr_x < blkpos1_x + 16 && curr_y < blkpos1_y + 16)) begin // bike 1
            draw_r = 4'b0000;
            draw_g = 4'b1101;
            draw_b = 4'b1111;
        end else if ((curr_x>= blkpos2_x && curr_y>= blkpos2_y) && 
                   (curr_x < blkpos2_x + 16 && curr_y < blkpos2_y + 16)) begin // bike 2
            draw_r = 4'b1111;
            draw_g = 4'b1000;
            draw_b = 4'b0000;
        end else begin // empty arena
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end
endmodule
