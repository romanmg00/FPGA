// Alan builder bench. Independent expected geometry uses pixels, HUD and wall
// rows of contract section 1, not DUT clear comparator or model.clear_word.
module arena_ctrl_tb;
    // Use XSim default time units consistently with the shared package.
    logic clk=0;
    always #6 clk=~clk;
    logic rst=1, cmd_valid=0;
    logic [1:0] cmd_op=0;
    logic [12:0] old_p1=0,old_p2=0,target_p1=0,target_p2=0;
    logic survive_p1=0,survive_p2=0,busy,done;
    logic [3:0] code_p1,code_p2,b_rdata;
    logic [12:0] b_addr=0;
    logic [3:0] expected [0:8191];
    logic [3:0] golden [0:8191];
    logic [3:0] before_b;
    integer ticks=0, collisions=0, writes=0, reads=0;
    logic monitor=0, follow_writer=0;
    arena_ctrl dut (.*);
    function automatic logic [3:0] cleared(input integer addr);
        integer px,py;
        begin
            px=(addr%128)*16; py=(addr/128)*16;
            cleared=(px>=16 && px<1280-16 && py>=64+16 && py<800-16) ? 4'd0 : 4'd1;
        end
    endfunction
    // Port B is always reading, including every write. Follow writer mode
    // forces a collision on EVERY service write; scan mode covers other cells.
    always @(negedge clk) begin
        if (follow_writer) b_addr=dut.a_addr;
    end
    always @(posedge clk) begin
        ticks=ticks+1;
        if (monitor) begin
            before_b=expected[b_addr];
            if (dut.a_we) begin
                writes=writes+1;
                if (b_addr==dut.a_addr) collisions=collisions+1;
                expected[dut.a_addr]=dut.a_wdata;
            end
            #1;
            if (b_rdata !== before_b) $fatal(1,"continuous port B mismatch at %0d",b_addr);
            reads=reads+1;
        end
    end
    task automatic issue(input logic [1:0] op, input integer want);
        integer start_tick;
        begin
            @(negedge clk); cmd_op=op; cmd_valid=1;
            @(posedge clk); #2; start_tick=ticks;
            if (!busy) $fatal(1,"no busy after accept");
            @(negedge clk); cmd_valid=0;
            // Change arguments while busy to prove capture; inject a request
            // while busy to prove it cannot replace the command.
            old_p1=8191; old_p2=8190; target_p1=8189; target_p2=8188;
            survive_p1=0; survive_p2=0; cmd_op=0; cmd_valid=1;
            while (!done) begin @(posedge clk); #2; end
            if (ticks-start_tick != want) $fatal(1,"op %0d cycles %0d expected %0d",op,ticks-start_tick,want);
            if (busy) $fatal(1,"busy on completion");
            $display("op=%0d acceptance-to-done=%0d cycles",op,ticks-start_tick);
            @(negedge clk); cmd_valid=0;
            @(posedge clk); #2;
            if (done || busy) $fatal(1,"done not pulse or busy request replayed");
        end
    endtask
    task automatic scan;
        begin
            follow_writer=0;
            for (integer i=0;i<8192;i++) begin
                @(negedge clk); b_addr=i;
                @(posedge clk); #2;
                if (b_rdata !== golden[i]) $fatal(1,"scan %0d",i);
            end
        end
    endtask
    task automatic check_cell(input integer addr,input logic [3:0] value);
        begin
            follow_writer=0;
            @(negedge clk); b_addr=addr;
            @(posedge clk); #2;
            if(b_rdata !== value) $fatal(1,"cell %0d got %0d want %0d",addr,b_rdata,value);
        end
    endtask
    task automatic commit_case(input logic s1,s2,input integer base);
        begin
            old_p1=base; target_p1=base+1; old_p2=base+10; target_p2=base+11;
            survive_p1=s1; survive_p2=s2; follow_writer=1;
            issue(3,2+int'(s1)+int'(s2));
            golden[base]=s1?2:6; golden[base+10]=s2?4:6;
            if(s1) golden[base+1]=3;
            if(s2) golden[base+11]=5;
            check_cell(base,s1?2:6); check_cell(base+1,s1?3:0);
            check_cell(base+10,s2?4:6); check_cell(base+11,s2?5:0);
            target_p1=base; target_p2=base+11;
            issue(2,3);
            if (code_p1 !== (s1?4'd2:4'd6) || code_p2 !== (s2?4'd5:4'd0))
                $fatal(1,"READ2 wrong");
            scan();
        end
    endtask
    initial begin
        repeat(2) @(negedge clk);
        rst=0; follow_writer=1;
        // First clear has unknown old words; then scan independently derived
        // image before enabling the continuously updated memory scoreboard.
        issue(1,8192);
        for(integer i=0;i<8192;i++) begin expected[i]=cleared(i); golden[i]=cleared(i); end
        monitor=1; scan();
        // Second clear proves every write including same-address old B data.
        follow_writer=1; issue(1,8192); scan();
        commit_case(1,1,1300);
        commit_case(0,1,1428);
        commit_case(1,0,1556);
        commit_case(0,0,1684);
        target_p1=1301; target_p2=1301; issue(2,3);
        if(code_p1!==3 || code_p2!==3) $fatal(1,"same target READ2");
        target_p1=0; target_p2=8191; issue(2,3);
        if(code_p1!==1 || code_p2!==1) $fatal(1,"boundary READ2");
        // A later crash overwrites actual known head codes, never targets.
        old_p1=1301; old_p2=1311; target_p1=1302; target_p2=1312;
        survive_p1=0; survive_p2=0; follow_writer=1; issue(3,2);
        golden[1301]=6; golden[1311]=6;
        check_cell(1301,6); check_cell(1311,6);
        check_cell(1302,0); check_cell(1312,0); scan();
        // Reset in flight aborts without memory reset. A fresh CLEAR recovers.
        @(negedge clk); cmd_valid=1; cmd_op=1;
        @(negedge clk); cmd_valid=0;
        repeat(5) @(negedge clk);
        rst=1;
        @(posedge clk); #2;
        if(busy || done || dut.a_we) $fatal(1,"reset did not abort");
        @(negedge clk); rst=0;
        follow_writer=1; issue(1,8192);
        for(integer i=0;i<8192;i++) begin
            if(expected[i]!==cleared(i)) $fatal(1,"recovery clear");
            golden[i]=cleared(i);
        end
        scan();
        $display("continuous B checks=%0d writes=%0d collisions=%0d",reads,writes,collisions);
        $display("PASS arena_ctrl_tb"); $finish;
    end
    initial begin #3000000; $fatal(1,"timeout"); end
endmodule
