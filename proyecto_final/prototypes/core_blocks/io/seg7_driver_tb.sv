// Alan's feasibility bench; decode physical outputs, no internal DUT signals.
module seg7_driver_tb;
    logic clk_pix=0, rst=1, page_lives=0, page_goal=0;
    logic [1:0] goal_sel=0;
    logic [5:0] points_p1=0, points_p2=0;
    logic [1:0] lives_p1=0, lives_p2=0;
    logic [6:0] seg;
    logic [7:0] an;
    always #5 clk_pix=!clk_pix;
    // Two cycles/slot, 16 cycles/frame; same divider as physical scan.
    seg7_driver #(.CLK_HZ(16000),.DIGIT_HZ(1000)) dut (.*);
    function automatic [7:0] decode(input logic [6:0] s);
        case(s)
            7'h40:decode="0"; 7'h79:decode="1"; 7'h24:decode="2";
            7'h30:decode="3"; 7'h19:decode="4"; 7'h12:decode="5";
            7'h02:decode="6"; 7'h78:decode="7"; 7'h00:decode="8";
            7'h10:decode="9"; 7'h0c:decode="P"; 7'h47:decode="L";
            7'h42:decode="G"; 7'h08:decode="A"; 7'h7f:decode=" ";
            default:decode="?";
        endcase
    endfunction
    task automatic tick;
        logic [7:0] active;
        @(posedge clk_pix); #1;
        active = ~an;
        if ($isunknown({an,seg}) || ((active & (active-8'd1)) != 0) || active==0)
            $fatal(1,"not exactly one active-low anode");
    endtask
    task automatic frame_check(input logic [63:0] expected);
        logic [63:0] observed;
        // Ignore partial old frame; then collect 8 slots at 2 cycles each.
        while(an!=8'h7f) tick();
        while(an!=8'hfe) tick();
        observed='0;
        for(integer d=0;d<8;d=d+1) begin
            if(an !== ~(8'b1<<d)) $fatal(1,"scan order");
            observed[d*8+:8]=decode(seg);
            tick();
            if(an !== ~(8'b1<<d) || decode(seg)!==observed[d*8+:8]) $fatal(1,"slot width");
            tick();
        end
        if(observed!==expected) $fatal(1,"got %s expected %s",observed,expected);
    endtask
    initial begin
        repeat(3) tick(); @(negedge clk_pix); rst=0;
        frame_check("P200P100");
        @(negedge clk_pix); points_p1=9; points_p2=10;
        frame_check("P210P109");
        @(negedge clk_pix); points_p1=45; points_p2=0;
        frame_check("P200P145");
        @(negedge clk_pix); points_p1=10; points_p2=45;
        frame_check("P245P110");
        @(negedge clk_pix); page_lives=1; lives_p1=3; lives_p2=0;
        frame_check("L200L103");
        @(negedge clk_pix); lives_p1=1; lives_p2=2;
        frame_check("L202L101");
        @(negedge clk_pix); page_lives=0; points_p1=9; points_p2=9;
        frame_check("P209P109");
        @(negedge clk_pix); page_goal=1; goal_sel=1;
        frame_check("G0AL  20");
        @(negedge clk_pix); goal_sel=3;
        frame_check("G0AL  40");
        @(negedge clk_pix); goal_sel=0;
        frame_check("G0AL  10");
        @(negedge clk_pix); page_goal=0;
        frame_check("P209P109");
        $display("PASS seg7_driver_tb"); $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
