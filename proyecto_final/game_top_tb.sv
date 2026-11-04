// Builder's own check of game_top from its pins, with sim_clocks/ in place of the
// Wizards; not the official bench of contract section 7. Covers what PR 11 got wrong.
`timescale 1ns/1ps
module game_top_tb;
    logic clk = 1'b0, cpu_resetn = 1'b1;
    logic [11:0] sw = 12'h000;
    logic [4:0] btn = 5'b0;
    logic [3:0] r, g, b;
    logic hs, vs;
    int errors = 0, rises_in_reset = 0;

    game_top dut (.clk, .cpu_resetn, .sw, .btn, .vga_r(r), .vga_g(g), .vga_b(b), .vga_hs(hs), .vga_vs(vs));
    always #5 clk = ~clk;
    always @(posedge dut.clk_juego) if (!cpu_resetn) rises_in_reset++;

    task automatic expect_pos(string what, int ex, int ey);
        if (dut.blkpos_x !== 11'(ex) || dut.blkpos_y !== 11'(ey)) begin
            $display("FAIL %s: got (%0d,%0d), expected (%0d,%0d)", what, dut.blkpos_x, dut.blkpos_y, ex, ey);
            errors++;
        end else $display("ok   %s: (%0d,%0d)", what, ex, ey);
    endtask

    // Waits for the block's centre pixel on the raster; the pins show it one clk_pix later.
    task automatic expect_block_colour(string what, logic [11:0] want);
        logic [11:0] got;
        @(posedge dut.clk_pix iff (dut.curr_x == dut.blkpos_x + 8 && dut.curr_y == dut.blkpos_y + 8));
        @(negedge dut.clk_pix);
        got = {r, g, b};
        if (got !== want) begin
            $display("FAIL %s: pins show %03h, expected %03h", what, got, want);
            errors++;
        end else $display("ok   %s: %03h", what, got);
    endtask

    int ms_hold[3] = '{50, 100, 500};
    int block_pos_x, block_pos_y;
    initial begin
        #1 expect_pos("power-up, before any button or reset", 320, 432);
        #100ms expect_pos("100 ms later, nothing pressed", 320, 432);
        expect_block_colour("all switches down: black block", 12'h000);
        sw = 12'hF00;
        #1ms expect_block_colour("switch colour", 12'hF00);

        foreach (ms_hold[i]) begin
            btn = 5'b01010; #200ms; btn = 5'b0; #40ms;
            block_pos_x = dut.blkpos_x; block_pos_y = dut.blkpos_y;
            if (block_pos_x == 320 && block_pos_y == 432) begin
                $display("FAIL buttons did not move the block"); errors++;
            end else $display("ok   moved to (%0d,%0d)", block_pos_x, block_pos_y);
            cpu_resetn = 1'b0; rises_in_reset = 0;
            #(ms_hold[i] * 1ms);
            cpu_resetn = 1'b1;
            #60ms;
            $display("     reset held %0d ms: %0d clk_juego rises during reset", ms_hold[i], rises_in_reset);
            expect_pos("CPU_RESETN returns the block", 320, 432);
        end

        btn = 5'b10000; #60ms; btn = 5'b0; #40ms;
        expect_pos("BTNC centres the block", 632, 392);

        if (errors == 0) $display("PASS game_top_tb");
        else $fatal(1, "game_top_tb: %0d errors", errors);
        $finish;
    end
endmodule
