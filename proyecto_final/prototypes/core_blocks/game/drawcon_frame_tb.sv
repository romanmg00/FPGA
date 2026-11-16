// drawcon_frame_tb: renders one whole frame of drawcon_game from a fixed scene
// and writes it to frame.hex in the run folder, for proyecto_final/prototypes/core_blocks/tools/look_frame.py
// compare. It is the quick look check of look_loop.sh: no game logic runs, so
// one frame takes about a minute in XSim instead of the minutes of
// tron_system_tb. Not a self-checking bench: the comparison with the Python
// viewer is the check.
//
// The scene (proyecto_final/prototypes/core_blocks/tools/look_frame.py scene) is the Arena memory (8192 Cell codes,
// read with arena_map port B's one-cycle latency) and 14 snapshot words in the
// order of look_frame.SNAP_FIELDS. The dumped frame is the second one after
// reset, so drawcon's per-frame latches hold the scene and its video-frame
// counter is 1: animation phase 0, as the viewer's frame 1.
// Owner: Alan, the builder's own tool (not an official contract §7 bench).
// Domain: one clock standing in for clk_pix; the raster is the handout's
// 1680 x 828 counters with curr_x = hcnt - 336, curr_y = vcnt - 27 as in
// vga_out. PROVISIONAL (ADR 0005): drawcon_game's ports.
module drawcon_frame_tb;
    import game_pkg::*;
    parameter string SCENE_DIR = "src/prototypes/core_blocks/game/look/";
    localparam string SPRITE_DIR = "src/prototypes/core_blocks/game/sprites/";

    logic clk = 0, rst = 1;
    always #6 clk = !clk;

    logic [10:0] hcnt = 0, vcnt = 0, curr_x, curr_y;
    always_ff @(posedge clk) begin
        hcnt <= (hcnt == 11'd1679) ? 11'd0 : hcnt + 11'd1;
        if (hcnt == 11'd1679) vcnt <= (vcnt == 11'd827) ? 11'd0 : vcnt + 11'd1;
    end
    assign curr_x = hcnt - 11'd336;
    assign curr_y = vcnt - 11'd27;

    logic [3:0]  arena [0:8191];
    logic [31:0] snap [0:13];
    initial begin
        $readmemh({SCENE_DIR, "scene-arena.mem"}, arena);
        $readmemh({SCENE_DIR, "scene-snap.mem"}, snap);
    end
    logic [12:0] b_addr;
    logic [3:0]  b_rdata = '0, draw_r, draw_g, draw_b;
    always_ff @(posedge clk) b_rdata <= arena[b_addr];

    drawcon_game #(.SPRITE_DIR(SPRITE_DIR)) dut (.clk, .rst, .curr_x, .curr_y, .b_rdata,
        .snap_phase(snap[0][2:0]), .snap_paused(snap[1][0]), .snap_blink_ticks(snap[2][4:0]),
        .snap_head_p1(snap[3][12:0]), .snap_head_p2(snap[4][12:0]),
        .snap_shown_p1(snap[5][1:0]), .snap_shown_p2(snap[6][1:0]),
        .snap_crashed_p1(snap[7][0]), .snap_crashed_p2(snap[8][0]),
        .points_p1(snap[9][5:0]), .points_p2(snap[10][5:0]),
        .lives_p1(snap[11][1:0]), .lives_p2(snap[12][1:0]), .result(snap[13][1:0]),
        .b_addr, .draw_r, .draw_g, .draw_b);

    initial begin
        integer fd;
        repeat (10) @(posedge clk);
        rst = 0;
        @(negedge clk iff (curr_x == 11'd1 && curr_y == 11'd800));   // first latch done
        fd = $fopen("frame.hex", "w");
        for (int y = 0; y < 800; y++) begin
            @(negedge clk iff (curr_x == 11'd0 && curr_y == 11'(y)));
            for (int x = 0; x < 1280; x++) begin
                if (x > 0) @(negedge clk);
                $fwrite(fd, "%03h\n", {draw_r, draw_g, draw_b});
            end
        end
        $fclose(fd);
        $display("frame phase %0d", dut.frame_cnt[4:3]);
        $display("PASS drawcon_frame_tb");
        $finish;
    end
endmodule
