// Builder's own check of position_logic; not the official bench of contract section 7.
`timescale 1ns/1ps
module position_logic_tb;
    logic clk = 1'b0, rst = 1'b0;
    logic [4:0] btn = 5'b0;
    logic [10:0] x, y;
    int errors = 0;
    position_logic dut (.clk, .rst, .btn, .blkpos_x(x), .blkpos_y(y));
    always #5 clk = ~clk;

    task automatic expect_pos(string what, int ex, int ey);
        if (x !== 11'(ex) || y !== 11'(ey)) begin
            $display("FAIL %s: got (%0d,%0d), expected (%0d,%0d)", what, x, y, ex, ey);
            errors++;
        end
    endtask
    task automatic ticks(int n);
        repeat (n) @(posedge clk);
        #1;
    endtask
    task automatic press(logic [4:0] b, int n);
        @(negedge clk) btn = b;
        ticks(n);
        @(negedge clk) btn = 5'b0;
        #1;
    endtask
    task automatic do_reset();
        @(negedge clk) rst = 1'b1;
        ticks(1);
        @(negedge clk) rst = 1'b0;
        #1;
    endtask

    initial begin
        #1 expect_pos("power-up", 320, 432);
        press(5'b00001, 1); expect_pos("up 4 px", 320, 428);
        press(5'b00010, 1); expect_pos("down 4 px", 320, 432);
        press(5'b00100, 1); expect_pos("left 4 px", 316, 432);
        press(5'b01000, 1); expect_pos("right 4 px", 320, 432);
        press(5'b00101, 2); expect_pos("diagonal", 312, 424);
        do_reset();         expect_pos("reset", 320, 432);
        press(5'b00001, 400); expect_pos("top wall", 320, 80);
        press(5'b00100, 400); expect_pos("left wall", 16, 80);
        press(5'b00010, 400); expect_pos("bottom wall", 16, 768);
        press(5'b01000, 400); expect_pos("right wall", 1248, 768);
        press(5'b10000, 1); expect_pos("centre button", 632, 392);
        press(5'b10001, 3); expect_pos("centre wins over a direction", 632, 392);
        @(negedge clk) begin rst = 1'b1; btn = 5'b10001; end
        ticks(1); expect_pos("reset wins over the buttons", 320, 432);
        @(negedge clk) begin rst = 1'b0; btn = 5'b0; end
        if (errors == 0) $display("PASS position_logic_tb");
        else $fatal(1, "position_logic_tb: %0d errors", errors);
        $finish;
    end
endmodule
