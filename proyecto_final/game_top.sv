module game_top (
    input  logic        clk, cpu_resetn,
    input  logic [11:0] sw,
    input  logic [4:0]  btn,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs
);

    logic [10:0] blkpos_x, blkpos_y;
    logic [10:0] curr_x, curr_y;
    logic [3:0]  draw_r, draw_g, draw_b;
    logic        clk_juego;
    logic        clk_pix;
    logic        clk_5mhz;
    logic [15:0] clk_cnt;
    logic        rst;

assign rst = ~cpu_resetn;

clk_wiz_0 u_clk(
    .clk_in1(clk),
    .clk_out1(clk_pix)
);

clk_wiz_1 u_clk1 (  
    .clk_in1(clk_pix),
    .clk_out1(clk_5mhz)
);

always_ff @(posedge clk_5mhz)begin
    if(rst) begin
        clk_cnt<=16'b0;
        clk_juego<=1'b0;
    end
    else begin
        clk_cnt <= clk_cnt + 1'b1;
        if (clk_cnt == 41666) begin
            clk_juego <= ~clk_juego;
            clk_cnt <= 16'b0;
        end
    end
end

position_logic u_position_logic (
        .rst(rst),
        .clk(clk_juego),
        .btn(btn),
        .blkpos_x(blkpos_x),
        .blkpos_y(blkpos_y)
    );

drawcon u_drawcon(
    .curr_x(curr_x),
    .curr_y(curr_y),
    .blkpos_x(blkpos_x),
    .blkpos_y(blkpos_y),
    .sw(sw),
    .draw_r(draw_r),
    .draw_g(draw_g),
    .draw_b(draw_b)
);

vga_out u_vga_out(
    .clk_pix(clk_pix),
    .rst(rst),
    .tick_60hz(),
    .curr_x(curr_x),
    .curr_y(curr_y),
    .draw_r(draw_r),
    .draw_g(draw_g),
    .draw_b(draw_b),
    .pix_r(vga_r),
    .pix_g(vga_g),
    .pix_b(vga_b),
    .hsync(vga_hs),
    .vsync(vga_vs)
);

endmodule
