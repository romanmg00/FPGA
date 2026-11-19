// Author: Roman (romanmg00).
// Testbench for counters: runs about one frame and prints the time each time the frame wraps
// (hcnt 1679, vcnt 827). Not self-checking; build_game_top.tcl does not run it.
module counters_tb ();

    reg clk, rst;
    wire [10:0] hcnt;
    wire [9:0] vcnt;

    counters uut ( .clk(clk), .rst(rst), .hcnt(hcnt), .vcnt(vcnt));

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #10 rst = 1'b0;
        #42000000 $finish;
    end

    always #5 clk = ~clk;

    always @(posedge clk)
        if (vcnt == 10'd827 && hcnt == 11'd1679) $display("vuelta en t=%0t", $time);
endmodule
