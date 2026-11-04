module drawcon(
    input logic [10:0] curr_x, curr_y,
    input logic [10:0] blkpos_x, blkpos_y,
    input logic [11:0] sw,  
    output logic [3:0] draw_r,
    output logic [3:0] draw_g,
    output logic [3:0] draw_b
);

    // Con todos los switches abajo el bloque seria negro sobre negro: entonces usa cian.
    logic [11:0] blk_color;
    assign blk_color = (sw == 12'h000) ? 12'h0FF : sw;

    always_comb begin
        if ((curr_x < 11'd16 && (curr_y>=11'd64 && curr_y < 11'd800)) || 
            (curr_x < 11'd1280 && (curr_y >= 11'd64 && curr_y < 11'd80)) ||
            (curr_x < 11'd1280 && (curr_y >= 11'd784 && curr_y < 11'd800)) ||
            ((curr_x >= 11'd1264 && curr_x < 11'd1280) && (curr_y >= 11'd64 && curr_y < 11'd800))) begin //walls
            draw_r = 4'b1111;
            draw_g = 4'b1111;
            draw_b = 4'b1111;
        end else if (curr_y < 11'd64) begin //HUD
            draw_r = 4'b0100;
            draw_g = 4'b0100;
            draw_b = 4'b0100;
        end else if ((curr_x>= blkpos_x && curr_y>= blkpos_y) && 
                   (curr_x < blkpos_x + 16 && curr_y < blkpos_y + 16)) begin //block 
            draw_r = blk_color[11:8];
            draw_g = blk_color[7:4];
            draw_b = blk_color[3:0];
        end else begin //playground
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
    end
endmodule
