// Alan's feasibility bench. Both pause policies and default 180-tick period.
module seg7_page_tb;
    logic clk_juego=0, rst=1, new_match=0, pause=0, waiting=0;
    logic [1:0] goal_sel=0;
    logic page_lives, page_goal, frozen_page, default_page;
    always #5 clk_juego=!clk_juego;
    seg7_page #(.VIEW_TICKS(3)) dut (.*);
    seg7_page #(.VIEW_TICKS(3),.RUN_DURING_PAUSE(0)) frozen
        (.clk_juego(clk_juego),.rst(rst),.new_match(new_match),.pause(pause),.waiting(1'b0),.goal_sel(2'b0),.page_lives(frozen_page),.page_goal());
    seg7_page defaults (.clk_juego(clk_juego),.rst(rst),.new_match(new_match),.pause(pause),.waiting(1'b0),.goal_sel(2'b0),.page_lives(default_page),.page_goal());
    task automatic tick;
        @(posedge clk_juego); #1; @(negedge clk_juego);
    endtask
    initial begin
        tick(); rst=0;
        for(integer i=1;i<=6;i=i+1) begin
            tick();
            if(page_lives !== ((i/3)%2) || frozen_page !== ((i/3)%2)) $fatal(1,"period");
        end
        pause=1;
        repeat(3) tick();
        if(page_lives!==1 || frozen_page!==0) $fatal(1,"pause policies");
        new_match=1; tick(); new_match=0;
        if(page_lives!==0 || frozen_page!==0) $fatal(1,"new match during pause");
        for(integer i=1;i<=360;i=i+1) begin
            tick();
            if(default_page !== ((i/180)%2)) $fatal(1,"default 180 ticks");
        end
        pause=0; repeat(3) tick();
        if(frozen_page!==1) $fatal(1,"resume");
        rst=1; tick();
        if(page_lives!==0 || frozen_page!==0 || default_page!==0 || page_goal!==0) $fatal(1,"reset");
        // Waiting for a new Match: Points -> Lives -> Goal -> Points, 3 ticks each.
        rst=0; waiting=1;
        for(integer i=1;i<=9;i=i+1) begin
            tick();
            if({page_goal,page_lives} !== (i/3==1 ? 2'b01 : i/3==2 ? 2'b10 : 2'b00)) $fatal(1,"waiting cycle at %0d",i);
        end
        // A goal switch change while waiting jumps to Goal and restarts its time.
        tick(); goal_sel=2'd2; tick();
        if(page_goal!==1 || page_lives!==0) $fatal(1,"goal change jump");
        tick(); tick();
        if(page_goal!==1) $fatal(1,"goal page keeps its full time");
        tick();
        if(page_goal!==0 || page_lives!==0) $fatal(1,"goal -> points");
        // Not waiting: a change does not jump, and Goal is never shown.
        waiting=0; goal_sel=2'd3; tick();
        if(page_goal!==0) $fatal(1,"no jump while playing");
        for(integer i=1;i<=9;i=i+1) begin tick(); if(page_goal!==0) $fatal(1,"goal page while playing"); end
        // new_match restarts on Points even from the Goal page.
        waiting=1; goal_sel=2'd1; tick();
        if(page_goal!==1) $fatal(1,"jump before new match");
        new_match=1; tick(); new_match=0;
        if(page_goal!==0 || page_lives!==0) $fatal(1,"new match restarts on Points");
        $display("PASS seg7_page_tb"); $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
