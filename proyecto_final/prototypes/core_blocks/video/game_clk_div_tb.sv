`timescale 1ns/1ps
// Roman's candidate; builder-owned independent checks. No data CDC.
module game_clk_div_tb;
    logic clk_base = 0;
    logic rst = 1;
    logic clk_juego;
    logic clk_small;
    logic clk_one;
    integer age = 0;
    integer resets = 0;
    integer rises = 0;
    integer falls = 0;
    integer last_rise = 0;
    logic previous = 0;
    localparam integer expected_half = 39063; // round(4687500 / 120)
    game_clk_div dut (.*);
    game_clk_div #(.input_hz(600), .target_hz(60)) u_small (
        .clk_base(clk_base), .rst(rst), .clk_juego(clk_small));
    game_clk_div #(.input_hz(120), .target_hz(60)) one (
        .clk_base(clk_base), .rst(rst), .clk_juego(clk_one));
    always #5 clk_base = ~clk_base;
    task automatic cycle(input logic reset_value);
        @(negedge clk_base);
        rst = reset_value;
        #1;
        if (clk_juego !== previous) $fatal(1,"Reset was asynchronous");
        @(posedge clk_base); #1;
        if (rst) begin
            age = 0;
            resets = resets + 1;
        end else age = age + 1;
        if (clk_juego !== ((age/expected_half)%2 != 0))
            $fatal(1,"Nominal period/duty/reset mismatch age=%0d",age);
        if (clk_small !== ((age/5)%2 != 0)) $fatal(1,"Parameterized divisor mismatch");
        if (clk_one !== (age%2 != 0)) $fatal(1,"half_cycles=1 mismatch");
        if (!rst && clk_juego && !previous) begin
            if (last_rise != 0 && age-last_rise != 2*expected_half)
                $fatal(1,"Rise period mismatch");
            last_rise = age;
            rises = rises + 1;
        end
        if (!rst && !clk_juego && previous) falls = falls + 1;
        if (rst) last_rise = 0;
        previous = clk_juego;
    endtask
    initial begin
        repeat (3) cycle(1);
        repeat (6*expected_half+17) cycle(0);
        cycle(1); // reset during low half, partial count
        repeat (expected_half+13) cycle(0);
        cycle(1); // reset during high half
        repeat (4*expected_half) cycle(0);
        if (rises < 6 || falls < 5 || resets != 5) $fatal(1,"Coverage incomplete");
        $display("PASS game_clk_div_tb half_cycles=%0d period_cycles=%0d rises=%0d falls=%0d resets=%0d",expected_half,2*expected_half,rises,falls,resets);
        $finish;
    end
endmodule
