// Self-checking testbench for step_counter.
// Checks on which ticks the step pulse appears, counting from when run becomes 1.
module step_counter_tb;

    logic clk, rst, run, step;
    int   errores = 0;
    int   N;      // STEP_TICKS of the DUT, read at the start of the test

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

    // Runs n ticks with run = 1. After edge i the counter is i (mod N), so step is 1 after
    // edges N-1, 2N-1...; bike_move reads it on edges N, 2N..., and the bike moves
    // N ticks after run became 1.
    task automatic corre(input string caso, input int n);
        for (int i = 1; i <= n; i++) begin
            paso(0, 1);
            revisa($sformatf("%s tick %0d", caso, i), (i % N) == N - 1);
        end
    endtask

    initial begin
        rst = 1'b1; run = 1'b0;
        N = dut.STEP_TICKS;
        $display("STEP_TICKS = %0d", N);

        // Case 1: reset; no pulses without run
        paso(1, 0); revisa("1 reset", 0);
        repeat (10) begin
            paso(0, 0); revisa("1 sin run", 0);
        end

        // Case 2: the first step comes N ticks after run, then every N
        corre("2", 3 * N + 2);

        // Case 3: run = 0 mid-count restarts; the new round again takes N
        paso(0, 0); revisa("3 run=0", 0);
        repeat (3) begin
            paso(0, 0); revisa("3 sigue sin run", 0);
        end
        corre("3 ronda nueva", 2 * N + 1);

        // Case 4: rst mid-count restarts even though run stays at 1
        paso(1, 1); revisa("4 rst con run", 0);
        corre("4 tras rst", 2 * N);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
