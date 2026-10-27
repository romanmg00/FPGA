module game_top (
    input  logic        clk, cpu_resetn,
    input logic [11:0]  sw,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs
);

    logic [10:0] curr_x, curr_y;
    logic [3:0]  draw_r, draw_g, draw_b;
    logic        tick_60hz;
    logic        clk_pix;

clk_wiz_0 u_clk(
    .clk_in1(clk),
    .clk_out1(clk_pix)
);

drawcon u_drawcon(
    .curr_x(curr_x),
    .curr_y(curr_y),
    .sw(sw),
    .draw_r(draw_r),
    .draw_g(draw_g),
    .draw_b(draw_b)
);

vga_out u_vga_out(
    .clk_pix(clk_pix),
    .rst(~cpu_resetn),
    .tick_60hz(tick_60hz),
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
