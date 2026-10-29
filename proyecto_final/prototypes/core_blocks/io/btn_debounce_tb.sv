// Alan's feasibility bench, not Roman's official contract bench. clk_pix scaled.
module btn_debounce_tb;
    logic clk = 0, rst = 1;
    logic [4:0] btn = 0, btn_pulse, previous = 0;
    integer pulses [0:4];
    always #5 clk = !clk;
    // Ten stable samples instead of 834600. Synchronizer remains two stages.
    btn_debounce #(.CLK_HZ(1000), .DEBOUNCE_MS(10)) dut (.*);
    always @(negedge clk) begin
        if (rst) previous = 0;
        else begin
            if ((previous & btn_pulse) != 0) $fatal(1,"pulse wider than one cycle");
            for (integer i=0; i<5; i=i+1)
                if (btn_pulse[i]) pulses[i] = pulses[i]+1;
            previous = btn_pulse;
        end
    end
    task automatic cycles(input integer n);
        repeat(n) @(negedge clk);
        #1;
    endtask
    task automatic check_counts(input integer u,d,l,r,c);
        if (pulses[0]!=u || pulses[1]!=d || pulses[2]!=l || pulses[3]!=r || pulses[4]!=c)
            $fatal(1,"counts %0d %0d %0d %0d %0d",pulses[0],pulses[1],pulses[2],pulses[3],pulses[4]);
    endtask
    initial begin
        for(integer i=0;i<5;i=i+1) pulses[i]=0;
        cycles(3); rst=0; cycles(3);
        // Short excursions, then a settled press and long hold.
        btn=1; cycles(2); btn=0; cycles(3); btn=1; cycles(4); btn=0; cycles(2);
        check_counts(0,0,0,0,0);
        btn=1; cycles(16); check_counts(1,0,0,0,0);
        cycles(50); check_counts(1,0,0,0,0);
        btn=0; cycles(3); btn=1; cycles(2); btn=0; cycles(4); btn=1; cycles(2);
        btn=0; cycles(16); check_counts(1,0,0,0,0);
        // All independent channels must preserve simultaneous presses.
        btn=5'b11111; cycles(16); check_counts(2,1,1,1,1);
        cycles(20); check_counts(2,1,1,1,1);
        btn=0; cycles(16); check_counts(2,1,1,1,1);
        btn=5'b10000; cycles(16); check_counts(2,1,1,1,2);
        // Reset during held press: requalifies once after reset by design.
        rst=1; cycles(3); if(btn_pulse!==0) $fatal(1,"reset pulses");
        rst=0; cycles(16); check_counts(2,1,1,1,3);
        $display("PASS btn_debounce_tb"); $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
