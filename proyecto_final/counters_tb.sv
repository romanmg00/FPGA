module counters_tb ();

    reg clk, rst;
    wire [9:0] count;

    counters uut ( .clk(clk), .rst(rst), .count(count));

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #10 rst = 1'b0;
    end

    always #5 clk = ~clk;

endmodule
