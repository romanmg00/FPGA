// Self-checking testbench for round_fsm.
// s_wait and s_release give the same outputs (load=1, run=0), so they are told apart
// by how they react to the button: that is why the cases follow complete sequences.
module round_fsm_tb;

    logic clk;
    logic rst, s, c, t;
    logic load, run;
    int   errores = 0;

    round_fsm dut (
        .clk(clk),
        .rst(rst),
        .s(s),
        .c(c),
        .t(t),
        .load(load),
        .run(run)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Changes the inputs on a falling edge and waits for the next one, so the rising
    // edge in between has updated the state. Each call therefore spans two rising edges.
    task automatic paso(input logic r_i, input logic s_i, input logic c_i, input logic t_i);
        @(negedge clk);
        rst = r_i;
        s   = s_i;
        c   = c_i;
        t   = t_i;
        @(negedge clk);
    endtask

    task automatic revisa(input string caso, input logic load_esp, input logic run_esp);
        if (load !== load_esp || run !== run_esp) begin
            $display("ERROR %s: load=%b run=%b, se esperaba load=%b run=%b",
                     caso, load, run, load_esp, run_esp);
            errores++;
        end
    endtask

    initial begin
        rst = 1'b1;
        s   = 1'b0;
        c   = 1'b0;
        t   = 1'b0;

        // Case 1: normal start
        paso(1, 0, 0, 0); revisa("1 reset", 1, 0);
        paso(0, 0, 0, 0); revisa("1 a s_wait", 1, 0);
        paso(0, 0, 0, 0); revisa("1 sigue en s_wait", 1, 0);
        paso(0, 1, 0, 0); revisa("1 Start arranca", 0, 1);
        paso(0, 0, 0, 0); revisa("1 soltar no detiene", 0, 1);

        // Case 2: button held through reset
        paso(1, 1, 0, 0); revisa("2 reset con boton", 1, 0);
        repeat (5) begin
            paso(0, 1, 0, 0); revisa("2 boton sostenido no arranca", 1, 0);
        end
        paso(0, 0, 0, 0); revisa("2 soltar", 1, 0);
        paso(0, 1, 0, 0); revisa("2 picar arranca", 0, 1);

        // Case 3: crash; it stays even when c returns to 0
        paso(0, 0, 1, 0); revisa("3 choque", 0, 0);
        paso(0, 0, 0, 0); revisa("3 sigue en s_crash", 0, 0);

        // Case 4: Start is ignored during the crash while t=0
        repeat (5) begin
            paso(0, 1, 0, 0); revisa("4 espera en s_crash", 0, 0);
        end

        // Case 5: the crash ends with the button held; it must not start by itself
        paso(0, 1, 0, 1); revisa("5 fin del choque", 1, 0);
        repeat (5) begin
            paso(0, 1, 0, 0); revisa("5 boton sostenido no arranca", 1, 0);
        end

        // Case 6: release and press again
        paso(0, 0, 0, 0); revisa("6 soltar", 1, 0);
        paso(0, 1, 0, 0); revisa("6 picar arranca", 0, 1);

        // Case 7: s and t are ignored in s_run; reset returns to waiting
        paso(0, 1, 0, 1); revisa("7 s_run ignora s y t", 0, 1);
        paso(1, 0, 0, 0); revisa("7 reset desde s_run", 1, 0);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
