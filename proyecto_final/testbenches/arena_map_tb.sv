// Author: Alan (AIF31).
// Builder's own check of arena_map: all 8192 words written and read back, the ctrl port in exactly
// 1 cycle and the draw port in exactly 2, and a ctrl port write with a draw port read of the same word
// (the draw port may return the old or the new word then; nothing may depend on which).
// Not the official bench of contract section 7.
`timescale 1ns/1ps
module arena_map_tb;
    logic        clk = 1'b0;
    logic [12:0] ctrl_addr = '0, draw_addr = '0;
    logic        ctrl_write = 1'b0;
    logic [3:0]  ctrl_write_code = '0, ctrl_read_code, draw_code;
    int          checks = 0;

    arena_map dut (.clk, .ctrl_addr, .ctrl_write, .ctrl_write_code, .ctrl_read_code, .draw_addr, .draw_code);
    always #6 clk = ~clk;

    // Neighbouring addresses always hold different words, so a read one cycle early or late fails.
    function automatic logic [3:0] pattern(int addr, int seed);
        return 4'((addr + (addr >> 7) + seed) & 15);
    endfunction

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "arena_map_tb failed");
    endfunction

    // Inputs change on the falling edge; outputs are checked 1 ns after the rising edge.
    task automatic edge_check();
        @(posedge clk);
        #1;
    endtask

    task automatic write_all(int seed);
        for (int i = 0; i < 8192; i++) begin
            @(negedge clk);
            ctrl_addr = 13'(i); ctrl_write = 1'b1; ctrl_write_code = pattern(i, seed);
        end
        @(negedge clk) ctrl_write = 1'b0;
    endtask

    // ctrl reads up, draw reads down, one address per cycle. After rising edge n, ctrl_read_code must be the
    // word whose address was presented before edge n, and draw_code the one presented before n-1.
    task automatic read_all(int seed);
        int b_prev = -1;
        for (int i = 0; i <= 8192; i++) begin
            @(negedge clk);
            if (i < 8192) begin ctrl_addr = 13'(i); draw_addr = 13'(8191 - i); end
            edge_check();
            if (i < 8192 && ctrl_read_code !== pattern(i, seed))
                fail($sformatf("ctrl port word %0d: read %0d, expected %0d", i, ctrl_read_code, pattern(i, seed)));
            if (b_prev >= 0 && draw_code !== pattern(b_prev, seed))
                fail($sformatf("draw port word %0d: read %0d, expected %0d (2 cycles)", b_prev, draw_code, pattern(b_prev, seed)));
            b_prev = (i < 8192) ? 8191 - i : -1;
            checks += 2;
        end
    endtask

    initial begin
        write_all(0);
        read_all(0);
        write_all(5);
        read_all(5);

        // Port B holds its address: the word shows 2 edges later, not 1.
        @(negedge clk) draw_addr = 13'd100; ctrl_addr = 13'd101;
        edge_check();
        if (draw_code === pattern(100, 5)) fail("draw port answered after 1 cycle");
        edge_check();
        if (draw_code !== pattern(100, 5)) fail("draw port did not answer after 2 cycles");

        // Same word: A writes 9 while B reads it. A reads the old word at that edge (read first);
        // B returns the old or the new word; both read the new word afterwards.
        @(negedge clk) ctrl_addr = 13'd3000; draw_addr = 13'd3000; ctrl_write = 1'b1; ctrl_write_code = 4'd9;
        edge_check();
        if (ctrl_read_code !== pattern(3000, 5)) fail("ctrl port during its own write did not read the old word");
        @(negedge clk) ctrl_write = 1'b0;
        edge_check();
        if (draw_code !== pattern(3000, 5) && draw_code !== 4'd9) fail("draw port read during the write returned neither word");
        if (ctrl_read_code !== 4'd9) fail("ctrl port one cycle after the write did not read the new word");
        edge_check();
        if (draw_code !== 4'd9) fail("draw port after the write did not read the new word");
        checks += 4;

        $display("PASS arena_map_tb (%0d checks)", checks);
        $finish;
    end
endmodule
