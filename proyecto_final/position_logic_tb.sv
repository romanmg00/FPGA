// Self-checking testbench for position_logic: round_fsm, step counter, crash timer, bike_move
// and the wall check together. It drives clk and the buttons directly, with no clock divider
// or Clocking Wizard: each clock edge is one game tick.
module position_logic_tb;

    localparam logic [4:0] B_NADA = 5'b00000, B_U = 5'b00001, B_D = 5'b00010,
                           B_L = 5'b00100, B_R = 5'b01000, B_C = 5'b10000;

    logic        clk, rst;
    logic [4:0]  btn;
    logic [10:0] blkpos_x, blkpos_y;
    logic [1:0]  heading;
    int          errores = 0;
    int          choques = 0;

    position_logic dut (
        .clk(clk), .rst(rst), .btn(btn),
        .blkpos_x(blkpos_x), .blkpos_y(blkpos_y), .heading(heading)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Counts the ticks on which the wall check reports a crash
    always @(posedge clk) if (dut.crash) choques++;

    // Called on a falling edge: sets the inputs and waits for n rising edges.
    task automatic ticks(input logic r_i, input logic [4:0] b_i, input int n);
        rst = r_i;
        btn = b_i;
        repeat (n) @(negedge clk);
    endtask

    // Checks the cell (x16 in pixels), the heading and whether the round is running
    task automatic revisa(input string caso, input int cx_e, input int cy_e,
                          input logic [1:0] h_e, input logic run_e);
        if (blkpos_x !== cx_e * 16 || blkpos_y !== cy_e * 16 || heading !== h_e ||
            dut.run !== run_e) begin
            $display("ERROR %s: celda (%0d,%0d) h=%0d run=%b; se esperaba (%0d,%0d) h=%0d run=%b",
                     caso, blkpos_x / 16, blkpos_y / 16, heading, dut.run,
                     cx_e, cy_e, h_e, run_e);
            errores++;
        end
    endtask

    initial begin
        rst = 1'b1; btn = B_NADA;

        // Case 1: after reset the bike waits at (20,27) = pixel (320,432) until Start
        ticks(1, B_NADA, 2);  revisa("1 reset", 20, 27, 1, 0);
        ticks(0, B_NADA, 30); revisa("1 sin Start no se mueve", 20, 27, 1, 0);
        ticks(0, B_R, 6);     revisa("1 botones sin Start no hacen nada", 20, 27, 1, 0);
        ticks(0, B_NADA, 1);

        // Case 2: Start; the first step comes 7 ticks after the press (1 to enter s_run + 6)
        ticks(0, B_C, 1);     revisa("2 Start entra a s_run", 20, 27, 1, 1);
        ticks(0, B_NADA, 5);  revisa("2 aun no hay paso", 20, 27, 1, 1);
        ticks(0, B_NADA, 1);  revisa("2 primer paso", 21, 27, 1, 1);
        ticks(0, B_NADA, 54); revisa("2 diez pasos en 60 ticks", 30, 27, 1, 1);

        // Case 3: the buttons arrive in the right order
        ticks(0, B_L, 6);     revisa("3 BTNL (media vuelta) se ignora", 31, 27, 1, 1);
        ticks(0, B_U, 6);     revisa("3 BTNU gira hacia arriba", 31, 26, 0, 1);
        ticks(0, B_R, 6);     revisa("3 BTNR gira a la derecha", 32, 26, 1, 1);
        ticks(0, B_D, 6);     revisa("3 BTND gira hacia abajo", 32, 27, 2, 1);

        // Case 4: it reaches the bottom wall (cy = 48) and the next step is a crash
        ticks(0, B_NADA, 6 * 21); revisa("4 llega a la ultima celda", 32, 48, 2, 1);
        ticks(0, B_NADA, 6);      revisa("4 choca: la ronda se detiene", 32, 48, 2, 0);
        if (choques !== 1) begin
            $display("ERROR 4: %0d pulsos de crash, se esperaba 1", choques);
            errores++;
        end

        // Case 5: during the ~2 s pause the bike stays at the wall and Start is ignored
        ticks(0, B_C, 100);   revisa("5 pausa con Start sostenido", 32, 48, 2, 0);

        // Case 6: after 120 ticks it returns to the start cell, but Start must be released first
        ticks(0, B_C, 30);    revisa("6 de vuelta en la salida, sin arrancar", 20, 27, 1, 0);
        ticks(0, B_NADA, 2);  revisa("6 soltar Start", 20, 27, 1, 0);
        ticks(0, B_C, 1);     revisa("6 nuevo Start", 20, 27, 1, 1);
        ticks(0, B_NADA, 6);  revisa("6 avanza de nuevo", 21, 27, 1, 1);

        // Case 7: reset during a round returns to the start cell and waits
        ticks(1, B_NADA, 1);  revisa("7 reset", 20, 27, 1, 0);
        ticks(0, B_NADA, 20); revisa("7 espera Start", 20, 27, 1, 0);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
