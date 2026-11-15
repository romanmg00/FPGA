// Accelerated debounce/divider only; real generated Wizard simulation models.
module core_board_top_tb;
    logic clk=0,cpu_resetn=0;
    always #5 clk=~clk;
    logic [4:0] btn=0;logic [15:0] sw=0,led;
    logic [3:0] vga_r,vga_g,vga_b;logic vga_hs,vga_vs;
    logic [6:0] seg;logic [7:0] an;
    core_board_top #(.debounce_hz(1000),.game_half_cycles(4)) dut(.*);
    task automatic wait_ready;
        wait(dut.ready); repeat(10) @(posedge dut.clk_pix);
    endtask
    task automatic check_heads(input integer x);
        if(dut.u_arena.ram.mem[3476] !== (x==20?4'd3:4'd2) ||
           dut.u_arena.ram.mem[3456+x] !== 4'd3) $fatal(1,"head/trail mismatch");
    endtask
    initial begin
        repeat(1000) @(posedge clk);cpu_resetn=1;
        wait_ready();check_heads(20);
        @(negedge dut.clk_pix);btn[4]=1;
        repeat(100) @(posedge dut.clk_pix);
        check_heads(21);
        if(dut.head!==13'd3477) $fatal(1,"press did not move exactly one Cell");
        @(negedge dut.clk_pix);btn=0;sw[0]=1;
        repeat(100) @(posedge dut.clk_pix);btn[0]=1;
        repeat(100) @(posedge dut.clk_pix);check_heads(21);
        if(dut.tick_fast===6'd0 || ^dut.tick_fast===1'bx) $fatal(1,"test tick crossing stalled");
        cpu_resetn=0;repeat(1000) @(posedge clk);cpu_resetn=1;
        btn=0;sw=0; wait_ready();check_heads(20);
        $display("PASS core_board_top_tb CLEAR press hold pause reset Gray tick");$finish;
    end
    initial begin #3000000;$fatal(1,"timeout");end
endmodule
