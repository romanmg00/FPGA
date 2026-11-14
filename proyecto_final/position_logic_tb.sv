// Self-checking testbench for position_logic with two bikes: round_fsm, step counter, crash
// timer, both bike_move instances, the wall check and the bike-to-bike crash rules together.
// It drives clk, the buttons and turn_req2 directly, with no clock divider or Clocking Wizard:
// each clock edge is one game tick.
//
// Two DUTs share the same inputs:
//   dut   - the real starts, P1 (20,27) RIGHT and P2 (59,27) LEFT.
//   dut_b - P2 starts at (58,27). With the real starts the two bikes always stand on cells of
//           different parity, so they can never aim at the same cell; the spec asks to test
//           the same-target crash with arranged positions, and this one makes it reachable.
module position_logic_tb;

    // Board buttons, in the board order [0] U, [1] D, [2] L, [3] R, [4] centre
    localparam logic [4:0] B_NADA = 5'b00000, B_U = 5'b00001, B_D = 5'b00010,
                           B_L = 5'b00100, B_R = 5'b01000, B_C = 5'b10000;
    // P2 turn requests, in the bike_move order [0] U, [1] R, [2] D, [3] L
    localparam logic [3:0] K_NADA = 4'b0000, K_U = 4'b0001, K_R = 4'b0010,
                           K_D = 4'b0100, K_L = 4'b1000;
    localparam int STEP = 6;   // ticks per step, as in u_step_counter

    logic        clk, rst;
    logic [4:0]  btn;
    logic [3:0]  turn2;
    logic [10:0] p1x, p1y, p2x, p2y;
    logic [1:0]  h1, h2;
    logic [10:0] b1x, b1y, b2x, b2y;
    logic [1:0]  bh1, bh2;
    int          errores = 0;
    int          choques = 0;

    position_logic dut (
        .clk(clk), .rst(rst), .btn(btn), .turn_req2(turn2),
        .blkpos1_x(p1x), .blkpos1_y(p1y), .blkpos2_x(p2x), .blkpos2_y(p2y),
        .heading1(h1), .heading2(h2)
    );

    position_logic #(.P2_START_CX(7'd58)) dut_b (
        .clk(clk), .rst(rst), .btn(btn), .turn_req2(turn2),
        .blkpos1_x(b1x), .blkpos1_y(b1y), .blkpos2_x(b2x), .blkpos2_y(b2y),
        .heading1(bh1), .heading2(bh2)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Counts the ticks on which dut reports a crash (either bike)
    always @(posedge clk) if (dut.crash) choques++;

    // Called on a falling edge: sets the inputs and waits for n rising edges.
    task automatic ticks(input logic r_i, input logic [4:0] b_i, input logic [3:0] k_i,
                         input int n);
        rst   = r_i;
        btn   = b_i;
        turn2 = k_i;
        repeat (n) @(negedge clk);
    endtask

    // n whole steps (6 ticks each) with the given buttons and P2 request held
    task automatic pasos(input int n, input logic [4:0] b_i, input logic [3:0] k_i);
        ticks(0, b_i, k_i, n * STEP);
    endtask

    // Reset, then Start: leaves both DUTs one tick into a new round, at a step boundary
    task automatic nueva_ronda();
        ticks(1, B_NADA, K_NADA, 2);
        ticks(0, B_NADA, K_NADA, 2);
        ticks(0, B_C,    K_NADA, 1);
    endtask

    // Checks both bikes of dut (cells, x16 in pixels, and headings) and whether the round runs
    task automatic revisa(input string caso,
                          input int x1, input int y1, input logic [1:0] e_h1,
                          input int x2, input int y2, input logic [1:0] e_h2,
                          input logic run_e);
        if (p1x !== x1 * 16 || p1y !== y1 * 16 || h1 !== e_h1 ||
            p2x !== x2 * 16 || p2y !== y2 * 16 || h2 !== e_h2 || dut.run !== run_e) begin
            $display("ERROR %s: P1 (%0d,%0d) h=%0d, P2 (%0d,%0d) h=%0d, run=%b; se esperaba P1 (%0d,%0d) h=%0d, P2 (%0d,%0d) h=%0d, run=%b",
                     caso, p1x / 16, p1y / 16, h1, p2x / 16, p2y / 16, h2, dut.run,
                     x1, y1, e_h1, x2, y2, e_h2, run_e);
            errores++;
        end
    endtask

    // Same check for dut_b (positions only; both bikes go straight there)
    task automatic revisa_b(input string caso, input int x1, input int x2, input logic run_e);
        if (b1x !== x1 * 16 || b1y !== 27 * 16 || b2x !== x2 * 16 || b2y !== 27 * 16 ||
            dut_b.run !== run_e) begin
            $display("ERROR %s: P1 (%0d,%0d), P2 (%0d,%0d), run=%b; se esperaba P1 (%0d,27), P2 (%0d,27), run=%b",
                     caso, b1x / 16, b1y / 16, b2x / 16, b2y / 16, dut_b.run, x1, x2, run_e);
            errores++;
        end
    endtask

    // Call 5 ticks into a step, while step = 1: checks which bikes crash on this step
    task automatic revisa_choque(input string caso, input logic c1, input logic c2);
        if (dut.crash1 !== c1 || dut.crash2 !== c2) begin
            $display("ERROR %s: crash1=%b crash2=%b; se esperaba crash1=%b crash2=%b",
                     caso, dut.crash1, dut.crash2, c1, c2);
            errores++;
        end
    endtask

    initial begin
        rst = 1'b1; btn = B_NADA; turn2 = K_NADA;

        // Case 1: after reset both bikes wait at their starts until Start
        ticks(1, B_NADA, K_NADA, 2);  revisa("1 reset", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 30); revisa("1 sin Start no se mueven", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_R, K_U, 6);        revisa("1 giros sin Start no hacen nada", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 1);

        // Case 2: Start; the first step comes 7 ticks after the press (1 to enter s_run + 6),
        // and both bikes move on the same step, towards each other
        ticks(0, B_C, K_NADA, 1);     revisa("2 Start entra a s_run", 20, 27, 1, 59, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, 5);  revisa("2 aun no hay paso", 20, 27, 1, 59, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, 1);  revisa("2 primer paso", 21, 27, 1, 58, 27, 3, 1);
        pasos(9, B_NADA, K_NADA);     revisa("2 diez pasos en 60 ticks", 30, 27, 1, 49, 27, 3, 1);

        // Case 3: P1's buttons arrive in the right order; P2 keeps going left
        pasos(1, B_L, K_NADA);        revisa("3 BTNL (media vuelta) se ignora", 31, 27, 1, 48, 27, 3, 1);
        pasos(1, B_U, K_NADA);        revisa("3 BTNU gira hacia arriba", 31, 26, 0, 47, 27, 3, 1);
        pasos(1, B_R, K_NADA);        revisa("3 BTNR gira a la derecha", 32, 26, 1, 46, 27, 3, 1);
        pasos(1, B_D, K_NADA);        revisa("3 BTND gira hacia abajo", 32, 27, 2, 45, 27, 3, 1);

        // Case 4: P1 reaches the bottom wall (cy = 48) and its next step is a crash.
        // P2 does not crash, so it completes that last step (spec: the survivor completes it).
        pasos(21, B_NADA, K_NADA);    revisa("4 P1 llega a la ultima celda", 32, 48, 2, 24, 27, 3, 1);
        choques = 0;
        ticks(0, B_NADA, K_NADA, 5);  revisa_choque("4 choca solo P1 (pared)", 1, 0);
        ticks(0, B_NADA, K_NADA, 1);  revisa("4 P1 se queda, P2 completa su paso", 32, 48, 2, 23, 27, 3, 0);
        if (choques !== 1) begin
            $display("ERROR 4: %0d pulsos de crash, se esperaba 1", choques);
            errores++;
        end

        // Case 5: during the ~2 s pause the bikes stay where they are and Start is ignored
        ticks(0, B_C, K_NADA, 100);   revisa("5 pausa con Start sostenido", 32, 48, 2, 23, 27, 3, 0);

        // Case 6: after 120 ticks both return to their starts, but Start must be released first
        ticks(0, B_C, K_NADA, 30);    revisa("6 de vuelta en la salida, sin arrancar", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 2);  revisa("6 soltar Start", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_C, K_NADA, 1);     revisa("6 nuevo Start", 20, 27, 1, 59, 27, 3, 1);
        pasos(1, B_NADA, K_NADA);     revisa("6 avanzan de nuevo", 21, 27, 1, 58, 27, 3, 1);

        // Case 7: reset during a round returns both bikes to their starts and waits
        ticks(1, B_NADA, K_NADA, 1);  revisa("7 reset", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 20); revisa("7 espera Start", 20, 27, 1, 59, 27, 3, 0);

        // Case 8: turn_req2 steers P2 in the U,R,D,L order. P2 goes up one row, then left
        // along row 26, then turns down into the cell where P1's head is (40,27).
        // Only P2 crashes; P1 completes its step to (41,27).
        nueva_ronda();
        pasos(1, B_NADA, K_U);        revisa("8 turn_req2[0] = arriba", 21, 27, 1, 59, 26, 0, 1);
        pasos(1, B_NADA, K_L);        revisa("8 turn_req2[3] = izquierda", 22, 27, 1, 58, 26, 3, 1);
        pasos(1, B_NADA, K_R);        revisa("8 media vuelta de P2 se ignora", 23, 27, 1, 57, 26, 3, 1);
        pasos(17, B_NADA, K_NADA);    revisa("8 P2 justo arriba de P1", 40, 27, 1, 40, 26, 3, 1);
        ticks(0, B_NADA, K_D, 5);     revisa_choque("8 P2 entra a la cabeza de P1: choca solo P2", 0, 1);
        ticks(0, B_NADA, K_D, 1);     revisa("8 P2 se queda, P1 completa su paso", 41, 27, 1, 40, 26, 3, 0);

        // Cases 9 and 10, in one round with both DUTs. Everyone goes straight along row 27.
        nueva_ronda();
        // Case 9 (dut_b): P1 (20,27) and P2 (58,27) both aim at (39,27) on step 19.
        pasos(18, B_NADA, K_NADA);
        revisa_b("9 a una celda de distancia", 38, 40, 1);
        revisa("10 todavia separadas", 38, 27, 1, 41, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, 5);
        if (dut_b.crash1 !== 1'b1 || dut_b.crash2 !== 1'b1) begin
            $display("ERROR 9 mismo destino: crash1=%b crash2=%b; se esperaba 1 y 1",
                     dut_b.crash1, dut_b.crash2);
            errores++;
        end
        ticks(0, B_NADA, K_NADA, 1);
        revisa_b("9 mismo destino: chocan las dos y no avanzan", 38, 40, 0);
        // Case 10 (dut): P1 (39,27) and P2 (40,27) aim at each other's cell on step 20.
        revisa("10 cabezas juntas", 39, 27, 1, 40, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, 5);  revisa_choque("10 intercambio de cabezas: chocan las dos", 1, 1);
        ticks(0, B_NADA, K_NADA, 1);  revisa("10 ninguna avanza", 39, 27, 1, 40, 27, 3, 0);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
