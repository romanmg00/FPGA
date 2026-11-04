// Builder's own check of sync_2ff: two clocks of delay, and rst clears both stages.
`timescale 1ns/1ps
module sync_2ff_tb;
    logic clk = 1'b0, rst = 1'b0, in = 1'b0, out;
    sync_2ff dut (.clk, .rst, .async_in(in), .sync_out(out));
    always #5 clk = ~clk;

    task automatic expect_out(logic want, string what);
        @(posedge clk);
        #1 if (out !== want) begin
            $display("FAIL %s: sync_out=%b", what, out);
            $fatal(1, "sync_2ff_tb failed");
        end
    endtask

    initial begin
        #1 if (out !== 1'b0) begin $display("FAIL starts at %b", out); $fatal(1, "sync_2ff_tb failed"); end
        @(negedge clk) in = 1'b1;
        expect_out(1'b0, "after 1 clock, still low");
        expect_out(1'b1, "after 2 clocks, high");
        @(negedge clk) in = 1'b0;
        expect_out(1'b1, "falling, after 1 clock, still high");
        expect_out(1'b0, "falling, after 2 clocks, low");
        @(negedge clk) in = 1'b1;
        expect_out(1'b0, "rising again, after 1 clock");
        expect_out(1'b1, "rising again, after 2 clocks");
        @(negedge clk) rst = 1'b1;
        expect_out(1'b0, "rst clears at once");
        expect_out(1'b0, "rst holds it low");
        @(negedge clk) rst = 1'b0;
        expect_out(1'b0, "after rst, first stage was cleared too");
        expect_out(1'b1, "after rst, the input arrives");
        $display("PASS sync_2ff_tb");
        $finish;
    end
endmodule
