// Self-checking testbench for step_counter.
// Checks on which ticks the step pulse appears, counting from when run becomes 1,
// and that pause holds the count (no step while paused) instead of restarting it.
module step_counter_tb;

    logic clk, rst, run, pause, step;
    int   errores = 0;
    int   N;      // STEP_TICKS of the DUT, read at the start of the test
    int   K;      // ticks counted before pausing in case 5

    step_counter dut (.clk(clk), .rst(rst), .pause(pause), .run(run), .step(step));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Called on a falling edge (or at t=0): sets the inputs and waits for the next
    // falling edge, so each call spans exactly one rising edge.
    task automatic paso(input logic r_i, input logic run_i, input logic pause_i);
        rst   = r_i;
        run   = run_i;
        pause = pause_i;
        @(negedge clk);
    endtask

    task automatic revisa(input string caso, input logic step_esp);
        if (step !== step_esp) begin
            $display("ERROR %s: step=%b, se esperaba %b", caso, step, step_esp);
            errores++;
        end
    endtask

    task automatic revisa_cuenta(input string caso, input int cuenta_esp);
        if (int'(dut.counter) !== cuenta_esp) begin
            $display("ERROR %s: counter=%0d, se esperaba %0d", caso, dut.counter, cuenta_esp);
            errores++;
        end
    endtask

    // Runs n ticks with run = 1 and pause = 0, starting from counter = c0. After edge i the
    // counter is (c0 + i) mod N, so step is 1 when that is N-1; bike_move reads it on the
    // next edge. With c0 = 0 the bike moves N ticks after run became 1.
    task automatic corre_desde(input string caso, input int c0, input int n);
        for (int i = 1; i <= n; i++) begin
            paso(0, 1, 0);
            revisa($sformatf("%s tick %0d", caso, i), ((c0 + i) % N) == N - 1);
        end
    endtask

    task automatic corre(input string caso, input int n);
        corre_desde(caso, 0, n);
    endtask

    // Holds pause = 1 for n ticks with run = 1: no step, and the count stays at cuenta_esp.
    task automatic pausa(input string caso, input int n, input int cuenta_esp);
        for (int i = 1; i <= n; i++) begin
            paso(0, 1, 1);
            revisa($sformatf("%s pausa tick %0d", caso, i), 0);
            revisa_cuenta($sformatf("%s pausa tick %0d", caso, i), cuenta_esp);
        end
    endtask

    initial begin
        rst = 1'b1; run = 1'b0; pause = 1'b0;
        N = dut.STEP_TICKS;
        K = N / 2;
        $display("STEP_TICKS = %0d", N);

        // Case 1: reset; no pulses without run
        paso(1, 0, 0); revisa("1 reset", 0);
        repeat (10) begin
            paso(0, 0, 0); revisa("1 sin run", 0);
        end

        // Case 2: the first step comes N ticks after run, then every N
        corre("2", 3 * N + 2);

        // Case 3: run = 0 mid-count restarts; the new round again takes N
        paso(0, 0, 0); revisa("3 run=0", 0);
        repeat (3) begin
            paso(0, 0, 0); revisa("3 sigue sin run", 0);
        end
        corre("3 ronda nueva", 2 * N + 1);

        // Case 4: rst mid-count restarts even though run stays at 1
        paso(1, 1, 0); revisa("4 rst con run", 0);
        corre("4 tras rst", 2 * N);

        // Case 5: pause mid-count holds the count; after it the step comes N-1-K ticks
        // later (not N, which would mean the count restarted), then every N.
        paso(1, 1, 0);
        corre("5 antes", K);
        pausa("5", 2 * N, K);
        corre_desde("5 despues", K, 2 * N);

        // Case 6: pause while counter == LAST: step drops at once and stays 0 although the
        // count holds LAST; when pause drops, step comes back before the edge (the delayed
        // step is taken once) and the count wraps to 0.
        paso(1, 1, 0);
        corre("6 antes", N - 1);
        pausa("6", 5, N - 1);
        rst = 1'b0; run = 1'b1; pause = 1'b0;
        #1 revisa("6 al quitar pausa", 1);
        @(negedge clk);
        revisa("6 tras el paso", 0); revisa_cuenta("6 tras el paso", 0);
        corre("6 despues", 2 * N);

        // Case 7: rst wins over pause
        paso(1, 1, 0);
        corre("7 antes", K);
        pausa("7", 3, K);
        paso(1, 1, 1); revisa("7 rst en pausa", 0); revisa_cuenta("7 rst en pausa", 0);
        corre("7 tras rst", 2 * N);

        // Case 8: run = 0 wins over pause (the round ended while paused)
        paso(1, 1, 0);
        corre("8 antes", K);
        pausa("8", 3, K);
        paso(0, 0, 1); revisa("8 run=0 en pausa", 0); revisa_cuenta("8 run=0 en pausa", 0);
        corre("8 ronda nueva", 2 * N);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
