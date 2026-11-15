// Builder bench, not official owner-independent section 7 verification.
module arena_map_tb;
    // Use XSim default time units consistently with the shared package.
    logic clk=0;
    always #6 clk=~clk;
    logic [12:0] a_addr=0, b_addr=0;
    logic a_we=0;
    logic [3:0] a_wdata=0, a_rdata, b_rdata;
    logic [3:0] expected [0:8191];
    logic [3:0] ea, eb;
    integer checks=0, collisions=0;
    arena_map dut (.*);
    task automatic cycle(input integer aa, bb, input logic we, input logic [3:0] data);
        @(negedge clk);
        a_addr=aa; b_addr=bb; a_we=we; a_wdata=data;
        ea=expected[aa]; eb=expected[bb];
        @(posedge clk); #1;
        if (a_rdata !== ea || b_rdata !== eb)
            $fatal(1,"read mismatch A=%h/%h B=%h/%h",a_rdata,ea,b_rdata,eb);
        if (we) begin
            expected[aa]=data;
            if (aa==bb) collisions++;
        end
        checks++;
    endtask
    initial begin
        // Unknown startup contents are deliberately checked as unknown before
        // first writes. Each row gets all 16 codes, not just EMPTY/WALL.
        for (integer i=0;i<8192;i++) cycle(i,i,1,i%16);
        for (integer i=0;i<8192;i++) cycle(i,8191-i,0,0);
        for (integer i=0;i<8192;i++) cycle(i,i,1,(i+7)%16);
        for (integer i=0;i<8192;i++) cycle(i,8191-i,0,0);
        $display("checks=%0d same-address collisions=%0d; both reads OLD on write",checks,collisions);
        $display("PASS arena_map_tb"); $finish;
    end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
