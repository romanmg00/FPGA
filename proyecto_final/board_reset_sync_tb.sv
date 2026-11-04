// Builder's own check of board_reset_sync: starts asserted, and follows the request
// two clocks later in both directions.
`timescale 1ns/1ps
module board_reset_sync_tb;
    logic clk = 1'b0, req = 1'b0, rst;
    board_reset_sync dut (.clk, .async_reset(req), .rst);
    always #5 clk = ~clk;

    task automatic expect_rst(logic want, string what);
        @(posedge clk);
        #1 if (rst !== want) begin
            $display("FAIL %s: rst=%b", what, rst);
            $fatal(1, "board_reset_sync_tb failed");
        end
    endtask

    initial begin
        #1 if (rst !== 1'b1) begin $display("FAIL must start asserted, rst=%b", rst); $fatal(1, "board_reset_sync_tb failed"); end
        expect_rst(1'b1, "first clock after power-up");
        expect_rst(1'b0, "second clock after power-up");
        expect_rst(1'b0, "stays released");
        @(negedge clk) req = 1'b1;
        expect_rst(1'b0, "request, after 1 clock");
        expect_rst(1'b1, "request, after 2 clocks");
        expect_rst(1'b1, "held");
        @(negedge clk) req = 1'b0;
        expect_rst(1'b1, "release, after 1 clock");
        expect_rst(1'b0, "release, after 2 clocks");
        $display("PASS board_reset_sync_tb");
        $finish;
    end
endmodule
