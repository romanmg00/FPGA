module game_top (
    input  logic        clk, cpu_resetn,
    input  logic [11:0] sw,
    input  logic [4:0]  btn,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs
);

    logic [10:0] blkpos_x, blkpos_y;     // position_logic -> drawcon: bike position in pixels
    logic [10:0] curr_x, curr_y;
    logic [3:0]  draw_r, draw_g, draw_b;
    logic        clk_juego;
    logic        clk_juego_toggle = 1'b0;
    logic        clk_pix;

    // clk_juego sale de un contador sobre clk_pix, sin segundo Clocking Wizard (ADR 0006):
    // alterna cada CLK_JUEGO_N ciclos, 83,455,882 Hz / (2 * 695,466) = 59.99997 Hz.
    // game_top_timing.xdc usa -divide_by 2 * CLK_JUEGO_N, y build_game_top.tcl revisa que
    // coincidan. El contador cuenta de 0 a N-1, asi que necesita $clog2(N) = 20 bits.
    localparam int CLK_JUEGO_N = 695_466;
    localparam int CLK_CNT_W   = $clog2(CLK_JUEGO_N);
    logic [CLK_CNT_W-1:0] clk_cnt = '0;

    logic        rst_request;
    logic        rst_pix, rst_juego;
    logic [4:0]  btn_sync;
    logic [11:0] sw_sync;

    assign rst_request = ~cpu_resetn;   // se invierte una sola vez (contrato 1)

    clk_wiz_0 u_clk(
        .clk_in1(clk),
        .clk_out1(clk_pix)
    );

    // El divisor NO se resetea: position_logic tiene reset sincrono, asi que necesita
    // flancos de clk_juego durante el reset. Si este reloj se detuviera, nunca lo veria.
    always_ff @(posedge clk_pix) begin
        clk_cnt <= clk_cnt + 1'b1;
        if (clk_cnt == CLK_CNT_W'(CLK_JUEGO_N - 1)) begin
            clk_juego_toggle <= ~clk_juego_toggle;
            clk_cnt <= '0;
        end
    end

    // clk_juego va por la red global de relojes, no por rutas de datos.
    `ifdef SYNTHESIS
    BUFG u_bufg_juego (.I(clk_juego_toggle), .O(clk_juego));
    `else
    assign clk_juego = clk_juego_toggle;
    `endif

    // Entradas asincronas: un reset por dominio y 2 flip-flops por cada boton y switch.
    board_reset_sync u_rst_pix   (.clk(clk_pix),   .async_reset(rst_request), .rst(rst_pix));
    board_reset_sync u_rst_juego (.clk(clk_juego), .async_reset(rst_request), .rst(rst_juego));

    for (genvar i = 0; i < 5; i++) begin : g_btn
        sync_2ff u_sync (.clk(clk_juego), .rst(rst_juego), .async_in(btn[i]), .sync_out(btn_sync[i]));
    end

    for (genvar i = 0; i < 12; i++) begin : g_sw
        sync_2ff u_sync (.clk(clk_pix), .rst(rst_pix), .async_in(sw[i]), .sync_out(sw_sync[i]));
    end

    // The bike moves on its own in rounds, turns with the buttons and crashes at a wall.
    position_logic u_position_logic (
        .clk(clk_juego),
        .rst(rst_juego),
        .btn(btn_sync),
        .blkpos_x(blkpos_x),
        .blkpos_y(blkpos_y),
        .heading()               // for the sprites, later
    );

    drawcon u_drawcon(
        .curr_x(curr_x),
        .curr_y(curr_y),
        .blkpos_x(blkpos_x),
        .blkpos_y(blkpos_y),
        .sw(sw_sync),
        .draw_r(draw_r),
        .draw_g(draw_g),
        .draw_b(draw_b)
    );

    vga_out u_vga_out(
        .clk_pix(clk_pix),
        .rst(rst_pix),
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
