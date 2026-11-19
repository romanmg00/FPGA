// Authors: Roman (romanmg00): first version, clock Wizard, vga_out, drawcon, Bike wiring and
// pos_link (X1, #48). Alan (AIF31): reset and synchronizers (#12), clk_juego from a counter on
// clk_pix (ADR 0006, #16), bike_glide (#31), Arena (#40), Match and Scoreboard (#47).
// Top level of the Tron game: clocks, reset, synchronizers and the video, movement, Arena,
// Match and Scoreboard blocks.
module game_top (
    input  logic        clk, cpu_resetn,
    input  logic [15:0] sw,             // SW0 Pause, {SW15, SW14} Points Goal, SW11-SW0 drawcon
    input  logic [4:0]  btn,
    output logic [3:0]  vga_r, vga_g, vga_b,
    output logic        vga_hs, vga_vs,
    output logic [6:0]  seg,            // Scoreboard: seg[0] = CA ... seg[6] = CG, active low
    output logic        dp,             // decimal point, always off
    output logic [7:0]  an              // active low, an[0] = rightmost digit
);

    logic [10:0] blkpos1_x, blkpos1_y;     // position_logic -> bike_glide: bike Cell in pixels
    logic [10:0] blkpos2_x, blkpos2_y;
    logic [10:0] glide1_x, glide1_y;       // bike_glide -> pos_link: drawn position, registered (clk_juego)
    logic [10:0] glide2_x, glide2_y;
    logic [10:0] draw1_x, draw1_y;         // pos_link -> drawcon: drawn position for this frame (clk_pix)
    logic [10:0] draw2_x, draw2_y;
    logic [1:0]  draw_heading1, draw_heading2;  // pos_link -> drawcon: headings for this frame (clk_pix)

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
    // (clk_pix), the only writer of arena_map; drawcon reads arena_map's draw_ port.
    logic        load, step, codes_valid;
    logic [3:0]  code1_u, code1_r, code1_d, code1_l, code2_u, code2_r, code2_d, code2_l;
    logic        heads_tgl, prepare, codes_tgl;
    logic [12:0] old_head_p1, old_head_p2, new_head_p1, new_head_p2;
    logic [15:0] neighbours_p1, neighbours_p2;
    logic [12:0] ctrl_addr, arena_addr;
    logic        ctrl_write;
    logic [3:0]  ctrl_write_code, ctrl_read_code, arena_code;

    // Match (G3/G5) and Scoreboard (ADR 0008), on clk_juego up to seg7_link.
    logic        pause;                         // SW0 on clk_juego
    logic [1:0]  goal_sel;                      // {SW15, SW14} on clk_juego
    logic        crash1, crash2, crash_done;    // position_logic -> match_fsm, score_unit
    logic        waiting, new_match, restart, round_start;    // match_fsm outputs
    logic        match_over;                    // score_unit -> match_fsm, position_logic
    logic [5:0]  points_p1, points_p2;          // score_unit -> seg7_link
    logic [1:0]  lives_p1, lives_p2;
    logic [1:0]  view;                          // seg7_view -> seg7_link
    logic [5:0]  points_p1_pix, points_p2_pix;  // seg7_link -> seg7_driver (clk_pix)
    logic [1:0]  lives_p1_pix, lives_p2_pix, view_pix, goal_sel_pix;

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

    // BTNC (btn[4]) is never reset, so a Start held through CPU_RESETN still reads as held
    // and match_fsm waits for its release.
    for (genvar i = 0; i < 5; i++) begin : g_btn
        sync_2ff u_sync (.clk(clk_juego), .rst((i == 4) ? 1'b0 : rst_juego), .async_in(btn[i]), .sync_out(btn_sync[i]));
    end

    for (genvar i = 0; i < 12; i++) begin : g_sw
        sync_2ff u_sync (.clk(clk_pix), .rst(rst_pix), .async_in(sw[i]), .sync_out(sw_sync[i]));
    end

    // Switches read on clk_juego: Pause and the Points Goal. The two goal bits are synchronized
    // apart; a change of both between two ticks can show a middle value for one tick, which
    // only restarts the Goal view.
    sync_2ff u_sync_pause (.clk(clk_juego), .rst(rst_juego), .async_in(sw[0]),  .sync_out(pause));
    sync_2ff u_sync_goal0 (.clk(clk_juego), .rst(rst_juego), .async_in(sw[14]), .sync_out(goal_sel[0]));
    sync_2ff u_sync_goal1 (.clk(clk_juego), .rst(rst_juego), .async_in(sw[15]), .sync_out(goal_sel[1]));

    // Match control (G3): Start reaches round_fsm as a 1-tick pulse, and each new Match resets
    // position_logic (Bikes to their starts).
    match_fsm u_match_fsm (
        .clk(clk_juego), .rst(rst_juego),
        .start_btn(btn_sync[4]), .crash(crash1 || crash2), .crash_done(crash_done),
        .match_over(match_over), .pause(pause),
        .waiting(waiting), .new_match(new_match), .restart(restart), .round_start(round_start)
    );

    // Points and Lives (G5)
    score_unit u_score_unit (
        .clk(clk_juego), .rst(rst_juego),
        .new_match(new_match), .crash1(crash1), .crash2(crash2),
        .points_p1(points_p1), .points_p2(points_p2), .lives_p1(lives_p1), .lives_p2(lives_p2),
        .result(), .match_over(match_over)
    );

    // The bike moves on its own in rounds, turns with the buttons and crashes at a wall.
    position_logic #(
        .STEP_TICKS(STEP_TICKS)
    ) u_position_logic (
        // Inputs 
        .clk(clk_juego),
        .rst(rst_juego || restart),
        .btn({round_start, btn_sync[3:0]}), // Start only through match_fsm
        .turn_req2(4'b0000),
        .pause(pause),
        .match_over(match_over),
        // Outputs
        .blkpos1_x(blkpos1_x), 
        .blkpos1_y(blkpos1_y),
        .blkpos2_x(blkpos2_x), 
        .blkpos2_y(blkpos2_y), 
        .heading1(heading1),
        .heading2(heading2),
        .crash1(crash1),
        .crash2(crash2),
        .crash_done(crash_done),
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
        .heads_tgl(heads_tgl), .prepare(prepare),
        .old_head_p1(old_head_p1), .old_head_p2(old_head_p2),
        .new_head_p1(new_head_p1), .new_head_p2(new_head_p2),
        .codes_tgl(codes_tgl), .neighbours_p1(neighbours_p1), .neighbours_p2(neighbours_p2)
    );

    arena_ctrl u_arena_ctrl (
        .clk(clk_pix), .rst(rst_pix),
        .heads_tgl(heads_tgl), .prepare(prepare),
        .old_head_p1(old_head_p1), .old_head_p2(old_head_p2),
        .new_head_p1(new_head_p1), .new_head_p2(new_head_p2),
        .codes_tgl(codes_tgl), .neighbours_p1(neighbours_p1), .neighbours_p2(neighbours_p2),
        .ctrl_addr(ctrl_addr), .ctrl_write(ctrl_write),
        .ctrl_write_code(ctrl_write_code), .ctrl_read_code(ctrl_read_code)
    );

    arena_map u_arena_map (
        .clk(clk_pix),
        .ctrl_addr(ctrl_addr), .ctrl_write(ctrl_write),                        // arena_ctrl
        .ctrl_write_code(ctrl_write_code), .ctrl_read_code(ctrl_read_code),
        .draw_addr(arena_addr), .draw_code(arena_code)                         // drawcon
    );

    // Each bike's square slides a few pixels every tick toward its current Cell (ADR 0010).
    bike_glide #(.STEP_TICKS(STEP_TICKS)) u_glide1 (
        // Inputs
        .clk(clk_juego),
        .rst(rst_juego),
        .blkpos_x(blkpos1_x),
        .blkpos_y(blkpos1_y),
        // Outputs
        .glide_x(glide1_x),
        .glide_y(glide1_y)
    );

    bike_glide #(.STEP_TICKS(STEP_TICKS)) u_glide2 (
        // Inputs
        .clk(clk_juego),
        .rst(rst_juego),
        .blkpos_x(blkpos2_x),
        .blkpos_y(blkpos2_y),
        // Outputs
        .glide_x(glide2_x),
        .glide_y(glide2_y)
    );

    // Drawn positions and headings cross from clk_juego to clk_pix (X1, issue #30): a toggle
    // through sync_2ff copies them to a pending register, which drawcon gets at curr_y == 800,
    // so a whole frame is drawn with the same positions.
    pos_link u_pos_link (
        // clk_juego side
        .clk_juego(clk_juego),
        .rst_juego(rst_juego),
        .glide1_x(glide1_x), .glide1_y(glide1_y),
        .glide2_x(glide2_x), .glide2_y(glide2_y),
        .heading1(heading1), .heading2(heading2),
        // clk_pix side
        .clk_pix(clk_pix),
        .rst_pix(rst_pix),
        .curr_y(curr_y),
        .draw1_x(draw1_x), .draw1_y(draw1_y),
        .draw2_x(draw2_x), .draw2_y(draw2_y),
        .draw_heading1(draw_heading1), .draw_heading2(draw_heading2)
    );

    drawcon u_drawcon(
        // Inputs
        .clk(clk_pix),
        .curr_x(curr_x),
        .curr_y(curr_y),
        .blkpos1_x(draw1_x), 
        .blkpos1_y(draw1_y),
        .blkpos2_x(draw2_x),
        .blkpos2_y(draw2_y),
        .sw(sw_sync),
        .heading1(draw_heading1),
        .heading2(draw_heading2),
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

    // Physical Scoreboard (ADR 0008): the view on clk_juego, one crossing to clk_pix, and the
    // homework 1 display path scanning the eight digits.
    seg7_view #(.VIEW_TICKS(180)) u_seg7_view (
        .clk(clk_juego), .rst(rst_juego),
        .new_match(new_match), .waiting(waiting), .goal_sel(goal_sel), .view(view)
    );

    seg7_link u_seg7_link (
        .clk_juego(clk_juego),
        .points_p1(points_p1), .points_p2(points_p2), .lives_p1(lives_p1), .lives_p2(lives_p2),
        .view(view), .goal_sel(goal_sel),
        .clk_pix(clk_pix),
        .points_p1_pix(points_p1_pix), .points_p2_pix(points_p2_pix),
        .lives_p1_pix(lives_p1_pix), .lives_p2_pix(lives_p2_pix),
        .view_pix(view_pix), .goal_sel_pix(goal_sel_pix)
    );

    seg7_driver #(.COUNT_BITS(17)) u_seg7_driver (
        .clk(clk_pix), .rst(rst_pix),
        .points_p1(points_p1_pix), .points_p2(points_p2_pix),
        .lives_p1(lives_p1_pix), .lives_p2(lives_p2_pix),
        .view(view_pix), .goal_sel(goal_sel_pix),
        .seg(seg), .an(an)
    );
    assign dp = 1'b1;

endmodule
