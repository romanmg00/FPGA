module vga_out (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [10:0] curr_x,
    output logic [9:0]  curr_y,
    output logic        tick_60hz,
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync
);

    logic [10:0] hcnt;
    logic [9:0] vcnt;
    logic visible;

    counters c_counter(
        .clk    (clk_pix), 
        .rst    (rst), 
        .hcnt   (hcnt), 
        .vcnt   (vcnt)
        );

    always_comb begin
        tick_60hz = 1'b0;
        curr_x = hcnt - 336;
        curr_y = vcnt - 27;
        visible = (hcnt>=336 && hcnt<1616) && (vcnt>=27 && vcnt<827);
    end

    always_ff @(posedge clk_pix) begin
        hsync <= ~ (hcnt>=11'b0 && hcnt<11'd136);
        vsync <= (vcnt>=10'b0 && vcnt<10'd3);
        if (visible) begin
            pix_r <= draw_r;
            pix_g <= draw_g;
            pix_b <= draw_b;
        end
        else begin
            pix_r <= 4'b0;
            pix_g <= 4'b0;
            pix_b <= 4'b0;
        end
    end

endmodule
