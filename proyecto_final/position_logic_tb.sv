// Builder's own check of position_logic; not the official bench of contract section 7.
// Every tick is compared with its own arithmetic, so a wrong step cannot hide inside a
// long move that still ends at the right wall.
`timescale 1ns/1ps
module position_logic_tb;
    localparam int MIN_X = 16, MAX_X = 1248, MIN_Y = 80, MAX_Y = 768, STEP = 4;

    logic clk = 1'b0, rst = 1'b0;
    logic [4:0] btn = 5'b0;
    logic [10:0] x, y;
    int ex = 320, ey = 432;   // the position this bench expects

    position_logic dut (.clk, .rst, .btn, .blkpos_x(x), .blkpos_y(y));
    always #5 clk = ~clk;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "position_logic_tb failed");
    endfunction

    function automatic int clamp(int v, int lo, int hi);
        return v < lo ? lo : (v > hi ? hi : v);
    endfunction

    task automatic check(string what);
        if (x !== 11'(ex) || y !== 11'(ey))
            fail($sformatf("%s: got (%0d,%0d), expected (%0d,%0d)", what, x, y, ex, ey));
    endtask

    // Applies inputs for one tick, updates the expected position, and compares.
    task automatic tick(string what, logic [4:0] b, logic r = 1'b0);
        @(negedge clk);
        btn = b;
        rst = r;
        if (r) begin
            ex = 320; ey = 432;
        end else if (b[4]) begin
            ex = 632; ey = 392;
        end else begin
            // Opposite buttons: down and right win. This is PR 11's behaviour, unchanged.
            if (b[1]) ey = clamp(ey + STEP, MIN_Y, MAX_Y);
            else if (b[0]) ey = clamp(ey - STEP, MIN_Y, MAX_Y);
            if (b[3]) ex = clamp(ex + STEP, MIN_X, MAX_X);
            else if (b[2]) ex = clamp(ex - STEP, MIN_X, MAX_X);
        end
        @(posedge clk);
        #1 check(what);
    endtask

    initial begin
        #1 check("power-up, before any clock");
        repeat (10) tick("idle: no movement", 5'b00000);

        tick("up", 5'b00001);
        tick("down", 5'b00010);
        tick("left", 5'b00100);
        tick("right", 5'b01000);
        repeat (3) tick("diagonal up-left", 5'b00101);
        repeat (3) tick("diagonal down-right", 5'b01010);
        tick("opposite up and down", 5'b00011);
        tick("opposite left and right", 5'b01100);

        tick("reset", 5'b00000, 1'b1);

        // Walk into each wall tick by tick, and keep pushing to check it holds.
        repeat (120) tick("towards the top wall", 5'b00001);
        if (y !== MIN_Y) fail("did not reach the top wall");
        repeat (90) tick("towards the left wall", 5'b00100);
        if (x !== MIN_X) fail("did not reach the left wall");
        repeat (180) tick("towards the bottom wall", 5'b00010);
        if (y !== MAX_Y) fail("did not reach the bottom wall");
        repeat (320) tick("towards the right wall", 5'b01000);
        if (x !== MAX_X) fail("did not reach the right wall");

        tick("centre button", 5'b10000);
        repeat (3) tick("centre wins over a direction", 5'b10001);
        tick("reset wins over the buttons", 5'b10001, 1'b1);
        tick("idle after reset", 5'b00000);

        $display("PASS position_logic_tb");
        $finish;
    end
endmodule
