module drawcon(
    input logic [10:0] curr_x,
    input logic [10:0] curr_y,
    input logic [11:0] sw,
    output logic [3:0] draw_r,
    output logic [3:0] draw_g,
    output logic [3:0] draw_b
);

    always_comb begin
        if (curr_x < 640 && curr_y < 400) begin
            draw_r = sw[11:8];
            draw_g = 4'b0000;
            draw_b = 4'b0000;
        end
        else if (curr_x >= 640 && curr_y < 400) begin
            draw_r = 4'b0000;
            draw_g = sw[7:4];
            draw_b = 4'b0000;
        end
        else if (curr_x < 640 && curr_y >= 400) begin
            draw_r = 4'b0000;
            draw_g = 4'b0000;
            draw_b = sw[3:0];
        end
        else begin
            draw_r = sw[11:8];
            draw_g = sw[7:4];
            draw_b = sw[3:0];
        end
    end
endmodule
