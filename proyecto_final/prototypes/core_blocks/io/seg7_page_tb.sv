// Alan's feasibility bench. Both pause policies and default 180-tick period.
module seg7_page_tb;
    logic clk_juego=0, rst=1, new_match=0, pause=0;
    logic page_lives, frozen_page, default_page;
    always #5 clk_juego=!clk_juego;
    seg7_page #(.VIEW_TICKS(3)) dut (.*);
    seg7_page #(.VIEW_TICKS(3),.RUN_DURING_PAUSE(0)) frozen
        (.clk_juego(clk_juego),.rst(rst),.new_match(new_match),.pause(pause),.page_lives(frozen_page));
    seg7_page defaults (.clk_juego(clk_juego),.rst(rst),.new_match(new_match),.pause(pause),.page_lives(default_page));
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
        if(page_lives!==0 || frozen_page!==0 || default_page!==0) $fatal(1,"reset");
        $display("PASS seg7_page_tb"); $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
