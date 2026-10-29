// Alan's feasibility bench; digital latency only, no metastability model.
module sync_2ff_tb;
    logic clk=0, rst=1, async_in=0, sync_out;
    always #5 clk=!clk;
    sync_2ff dut (.*);
    task automatic edge_check(input logic expected);
        @(posedge clk); #1;
        if(sync_out!==expected) $fatal(1,"sync latency/reset");
    endtask
    initial begin
        edge_check(0); @(negedge clk); rst=0;
        #2; async_in=1; edge_check(0); edge_check(1);
        @(negedge clk); #2; async_in=0; edge_check(1); edge_check(0);
        @(negedge clk); async_in=1; edge_check(0);
        @(negedge clk); rst=1; edge_check(0); edge_check(0);
        $display("PASS sync_2ff_tb"); $finish;
    end
    initial begin #1000; $fatal(1,"timeout"); end
endmodule
