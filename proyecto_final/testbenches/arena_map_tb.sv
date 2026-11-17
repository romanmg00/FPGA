// Author: Alan (AIF31).
// Builder's own check of arena_map: all 8192 words written and read back, port A in exactly
// 1 cycle and port B in exactly 2, and a port A write with a port B read of the same word
// (B may return the old or the new word then; nothing may depend on which).
// Not the official bench of contract section 7.
`timescale 1ns/1ps
module arena_map_tb;
    logic        clk = 1'b0;
    logic [12:0] a_addr = '0, b_addr = '0;
    logic        a_we = 1'b0;
    logic [3:0]  a_wdata = '0, a_rdata, b_rdata;
    int          checks = 0;

    arena_map dut (.clk, .a_addr, .a_we, .a_wdata, .a_rdata, .b_addr, .b_rdata);
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
            a_addr = 13'(i); a_we = 1'b1; a_wdata = pattern(i, seed);
        end
        @(negedge clk) a_we = 1'b0;
    endtask

    // A reads up, B reads down, one address per cycle. After rising edge n, a_rdata must be the
    // word whose address was presented before edge n, and b_rdata the one presented before n-1.
    task automatic read_all(int seed);
        int b_prev = -1;
        for (int i = 0; i <= 8192; i++) begin
            @(negedge clk);
            if (i < 8192) begin a_addr = 13'(i); b_addr = 13'(8191 - i); end
            edge_check();
            if (i < 8192 && a_rdata !== pattern(i, seed))
                fail($sformatf("port A word %0d: read %0d, expected %0d", i, a_rdata, pattern(i, seed)));
            if (b_prev >= 0 && b_rdata !== pattern(b_prev, seed))
                fail($sformatf("port B word %0d: read %0d, expected %0d (2 cycles)", b_prev, b_rdata, pattern(b_prev, seed)));
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
        @(negedge clk) b_addr = 13'd100; a_addr = 13'd101;
        edge_check();
        if (b_rdata === pattern(100, 5)) fail("port B answered after 1 cycle");
        edge_check();
        if (b_rdata !== pattern(100, 5)) fail("port B did not answer after 2 cycles");

        // Same word: A writes 9 while B reads it. A reads the old word at that edge (read first);
        // B returns the old or the new word; both read the new word afterwards.
        @(negedge clk) a_addr = 13'd3000; b_addr = 13'd3000; a_we = 1'b1; a_wdata = 4'd9;
        edge_check();
        if (a_rdata !== pattern(3000, 5)) fail("port A during its own write did not read the old word");
        @(negedge clk) a_we = 1'b0;
        edge_check();
        if (b_rdata !== pattern(3000, 5) && b_rdata !== 4'd9) fail("port B read during the write returned neither word");
        if (a_rdata !== 4'd9) fail("port A one cycle after the write did not read the new word");
        edge_check();
        if (b_rdata !== 4'd9) fail("port B after the write did not read the new word");
        checks += 4;

        $display("PASS arena_map_tb (%0d checks)", checks);
        $finish;
    end
endmodule
