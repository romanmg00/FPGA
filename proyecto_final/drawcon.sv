// Colour of each pixel, from top to bottom priority: walls, HUD, block, empty arena.
// The block colour comes from the switches.
module drawcon(
    input logic [10:0] curr_x, curr_y,
    input logic [10:0] blkpos_x, blkpos_y,
    input logic [11:0] sw,  
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
        end else if ((curr_x>= blkpos_x && curr_y>= blkpos_y) && 
                   (curr_x < blkpos_x + 16 && curr_y < blkpos_y + 16)) begin // block
            draw_r = sw[11:8];
            draw_g = sw[7:4];
            draw_b = sw[3:0];
        end else begin // empty arena
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end
endmodule
