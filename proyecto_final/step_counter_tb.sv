// Self-checking testbench for step_counter.
// Checks on which ticks the step pulse appears, counting from when run becomes 1.
module step_counter_tb;

    logic clk, rst, run, step;
    int   errores = 0;

    step_counter dut (.clk(clk), .rst(rst), .run(run), .step(step));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Called on a falling edge (or at t=0): sets the inputs and waits for the next
    // falling edge, so each call spans exactly one rising edge.
    task automatic paso(input logic r_i, input logic run_i);
        rst = r_i;
        run = run_i;
        @(negedge clk);
    endtask

    task automatic revisa(input string caso, input logic step_esp);
        if (step !== step_esp) begin
            $display("ERROR %s: step=%b, se esperaba %b", caso, step, step_esp);
            errores++;
        end
    endtask

    // Runs n ticks with run = 1. After edge i the counter is i (mod 6), so step is 1 after
    // edges 5, 11, 17...; bike_move reads it on edges 6, 12, 18..., and the bike moves
    // 6 ticks after run became 1.
    task automatic corre(input string caso, input int n);
        for (int i = 1; i <= n; i++) begin
            paso(0, 1);
            revisa($sformatf("%s tick %0d", caso, i), (i % 6) == 5);
        end
    endtask

    initial begin
        rst = 1'b1; run = 1'b0;

        // Case 1: reset; no pulses without run
        paso(1, 0); revisa("1 reset", 0);
        repeat (10) begin
            paso(0, 0); revisa("1 sin run", 0);
        end

        // Case 2: the first step comes 6 ticks after run, then every 6
        corre("2", 20);

        // Case 3: run = 0 mid-count restarts; the new round again takes 6
        paso(0, 0); revisa("3 run=0", 0);
        repeat (3) begin
            paso(0, 0); revisa("3 sigue sin run", 0);
        end
        corre("3 ronda nueva", 13);

        // Case 4: rst mid-count restarts even though run stays at 1
        paso(1, 1); revisa("4 rst con run", 0);
        corre("4 tras rst", 12);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
