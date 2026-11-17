module game_top (
    input  logic        clk, cpu_resetn,
    input  logic [11:0] sw,
    input  logic [4:0]  btn,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs
);

    logic [10:0] blkpos1_x, blkpos1_y;     // position_logic -> bike_glide: bike Cell in pixels
    logic [10:0] blkpos2_x, blkpos2_y;
    logic [10:0] glide1_x, glide1_y;       // bike_glide -> drawcon: drawn position, registered
    logic [10:0] glide2_x, glide2_y;

    // Ticks of clk_juego per step (ADR 0007, ADR 0010): 8 gives about 7.5 Cells/s. One value
    // for position_logic and both bike_glide, so the slide always lasts exactly one step.
    localparam int STEP_TICKS = 8;
    logic [10:0] curr_x, curr_y;
    logic [3:0]  draw_r, draw_g, draw_b;
    logic [1:0]  heading1, heading2;
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

    // Arena (contract section 3): position_logic <-> arena_link (clk_juego) <-> arena_ctrl
    // (clk_pix), the only writer of arena_map; drawcon reads arena_map's port B.
    logic        load, step, codes_valid;
    logic [3:0]  code1_u, code1_r, code1_d, code1_l, code2_u, code2_r, code2_d, code2_l;
    logic        req_tgl, req_prepare, ack_tgl;
    logic [12:0] req_old1, req_old2, req_new1, req_new2;
    logic [15:0] nbr1, nbr2;
    logic [12:0] a_addr, arena_addr;
    logic        a_we;
    logic [3:0]  a_wdata, a_rdata, arena_code;

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
    position_logic #(
        .STEP_TICKS(STEP_TICKS)
    ) u_position_logic (
        // Inputs 
        .clk(clk_juego),
        .rst(rst_juego),
        .btn(btn_sync),
        .turn_req2(4'b0000),
        .pause(1'b0),
        .match_over(1'b0),
        // Outputs
        .blkpos1_x(blkpos1_x), 
        .blkpos1_y(blkpos1_y),
        .blkpos2_x(blkpos2_x), 
        .blkpos2_y(blkpos2_y), 
        .heading1(heading1),
        .heading2(heading2),
        .crash1(),
        .crash2(),
        .crash_done(),
        // Arena
        .load(load),
        .step(step),
        .code1_u(code1_u), .code1_r(code1_r), .code1_d(code1_d), .code1_l(code1_l),
        .code2_u(code2_u), .code2_r(code2_r), .code2_d(code2_d), .code2_l(code2_l),
        .codes_valid(codes_valid)
    );

    // After each step, the heads go to the Arena and the codes of their neighbours come back.
    arena_link u_arena_link (
        .clk(clk_juego), .rst(rst_juego),
        .load(load), .step(step),
        .blkpos1_x(blkpos1_x), .blkpos1_y(blkpos1_y),
        .blkpos2_x(blkpos2_x), .blkpos2_y(blkpos2_y),
        .code1_u(code1_u), .code1_r(code1_r), .code1_d(code1_d), .code1_l(code1_l),
        .code2_u(code2_u), .code2_r(code2_r), .code2_d(code2_d), .code2_l(code2_l),
        .codes_valid(codes_valid),
        .req_tgl(req_tgl), .req_prepare(req_prepare),
        .req_old1(req_old1), .req_old2(req_old2), .req_new1(req_new1), .req_new2(req_new2),
        .ack_tgl(ack_tgl), .nbr1(nbr1), .nbr2(nbr2)
    );

    arena_ctrl u_arena_ctrl (
        .clk(clk_pix), .rst(rst_pix),
        .req_tgl(req_tgl), .req_prepare(req_prepare),
        .req_old1(req_old1), .req_old2(req_old2), .req_new1(req_new1), .req_new2(req_new2),
        .ack_tgl(ack_tgl), .nbr1(nbr1), .nbr2(nbr2),
        .a_addr(a_addr), .a_we(a_we), .a_wdata(a_wdata), .a_rdata(a_rdata)
    );

    arena_map u_arena_map (
        .clk(clk_pix),
        .a_addr(a_addr), .a_we(a_we), .a_wdata(a_wdata), .a_rdata(a_rdata),   // arena_ctrl
        .b_addr(arena_addr), .b_rdata(arena_code)                             // drawcon
    );

    // Each bike's square slides a few pixels every tick toward its current Cell (ADR 0010).
    bike_glide #(.STEPS(STEP_TICKS)) u_glide1 (
        // Inputs
        .clk(clk_juego),
        .rst(rst_juego),
        .pos_x(blkpos1_x),
        .pos_y(blkpos1_y),
        // Outputs
        .draw_x(glide1_x),
        .draw_y(glide1_y)
    );

    bike_glide #(.STEPS(STEP_TICKS)) u_glide2 (
        // Inputs
        .clk(clk_juego),
        .rst(rst_juego),
        .pos_x(blkpos2_x),
        .pos_y(blkpos2_y),
        // Outputs
        .draw_x(glide2_x),
        .draw_y(glide2_y)
    );

    drawcon u_drawcon(
        // Inputs
        .clk(clk_pix),
        .curr_x(curr_x),
        .curr_y(curr_y),
        .blkpos1_x(glide1_x), 
        .blkpos1_y(glide1_y),
        .blkpos2_x(glide2_x),
        .blkpos2_y(glide2_y),
        .sw(sw_sync),
        .heading1(heading1),
        .heading2(heading2),
        // Outputs
        .draw_r(draw_r),
        .draw_g(draw_g),
        .draw_b(draw_b),
        .arena_addr(arena_addr),
        .arena_code(arena_code)
    );

    vga_out u_vga_out(
        // Inputs
        .clk_pix(clk_pix),
        .rst(rst_pix),
        .draw_r(draw_r),
        .draw_g(draw_g),
        .draw_b(draw_b),
        // Outputs
        .curr_x(curr_x),
        .curr_y(curr_y),
        .tick_60hz(),
        .pix_r(vga_r),
        .pix_g(vga_g),
        .pix_b(vga_b),
        .hsync(vga_hs),
        .vsync(vga_vs)
    );

endmodule
