// Author: Roman (romanmg00), in a bench file Alan (AIF31) started for the moving block (#12).
// Changes by Alan (AIF31): Arena codes (#40), Crash Step checks (ADR 0011, #39), Rewards taken
// and the Goal ending a Round (G4, cases 14-16).
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
// Both share pause (SW0) and match_over too. Cases 11-13 check them: pause holds the step count,
// the turns and the crash pause; match_over keeps round_fsm in s_crash until a reset.
module position_logic_tb;

    // Board buttons, in the board order [0] U, [1] D, [2] L, [3] R, [4] centre
    localparam logic [4:0] B_NADA = 5'b00000, B_U = 5'b00001, B_D = 5'b00010,
                           B_L = 5'b00100, B_R = 5'b01000, B_C = 5'b10000;
    // P2 turn requests, in the bike_move order [0] U, [1] R, [2] D, [3] L
    localparam logic [3:0] K_NADA = 4'b0000, K_U = 4'b0001, K_R = 4'b0010,
                           K_D = 4'b0100, K_L = 4'b1000;
    // Ticks per step. Read from u_step_counter at the start of the test, so changing
    // STEP_TICKS in position_logic needs no change here.
    int          STEP;

    logic        clk, rst;
    logic [4:0]  btn;
    logic [3:0]  turn2;
    logic        pause, mo;       // SW0 and match_over, shared by both DUTs
    logic        c1, c2, cd;      // dut's crash1, crash2 and crash_done ports
    logic [1:0]  w1, w2;          // dut's reward1 and reward2 ports
    logic [3:0]  c1r = 4'd0, c2l = 4'd0;   // codes of the Cells right of P1 and left of P2
    logic [10:0] p1x, p1y, p2x, p2y;
    logic [1:0]  h1, h2;
    logic [10:0] b1x, b1y, b2x, b2y;
    logic [1:0]  bh1, bh2;
    int          errores = 0;
    int          choques = 0;

    position_logic dut (
        .clk(clk), .rst(rst), .btn(btn), .turn_req2(turn2),
        .pause(pause), .match_over(mo),
        .blkpos1_x(p1x), .blkpos1_y(p1y), .blkpos2_x(p2x), .blkpos2_y(p2y),
        .heading1(h1), .heading2(h2),
        .crash1(c1), .crash2(c2), .crash_done(cd), .reward1(w1), .reward2(w2),
        // Arena codes empty and valid (the bikes behave as before the Arena), except the Cells
        // ahead of the bikes on their starting row in cases 14-15
        .load(), .step(),
        .code1_u(4'd0), .code1_r(c1r), .code1_d(4'd0), .code1_l(4'd0),
        .code2_u(4'd0), .code2_r(4'd0), .code2_d(4'd0), .code2_l(c2l),
        .codes_valid(1'b1)
    );

    position_logic #(.P2_START_CX(7'd58)) dut_b (
        .clk(clk), .rst(rst), .btn(btn), .turn_req2(turn2),
        .pause(pause), .match_over(mo),
        .blkpos1_x(b1x), .blkpos1_y(b1y), .blkpos2_x(b2x), .blkpos2_y(b2y),
        .heading1(bh1), .heading2(bh2),
        .crash1(), .crash2(), .crash_done(), .reward1(), .reward2(),
        // Arena codes all empty and valid: the bikes behave as before the Arena
        .load(), .step(),
        .code1_u(4'd0), .code1_r(4'd0), .code1_d(4'd0), .code1_l(4'd0),
        .code2_u(4'd0), .code2_r(4'd0), .code2_d(4'd0), .code2_l(4'd0),
        .codes_valid(1'b1)
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

    // n whole steps (STEP ticks each) with the given buttons and P2 request held
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

    // Call STEP - 1 ticks into a step, while step = 1: checks which bikes crash on this step,
    // on dut's crash1 and crash2 ports
    task automatic revisa_choque(input string caso, input logic e_c1, input logic e_c2);
        if (c1 !== e_c1 || c2 !== e_c2) begin
            $display("ERROR %s: crash1=%b crash2=%b; se esperaba crash1=%b crash2=%b",
                     caso, c1, c2, e_c1, e_c2);
            errores++;
        end
    endtask

    initial begin
        rst = 1'b1; btn = B_NADA; turn2 = K_NADA; pause = 1'b0; mo = 1'b0;
        STEP = dut.u_step_counter.STEP_TICKS;
        $display("STEP_TICKS = %0d", STEP);

        // Case 1: after reset both bikes wait at their starts until Start
        ticks(1, B_NADA, K_NADA, 2);  revisa("1 reset", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 30); revisa("1 sin Start no se mueven", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_R, K_U, STEP);        revisa("1 giros sin Start no hacen nada", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 1);

        // Case 2: Start; the first step comes STEP + 1 ticks after the press (1 to enter s_run + STEP),
        // and both bikes move on the same step, towards each other
        ticks(0, B_C, K_NADA, 1);     revisa("2 Start entra a s_run", 20, 27, 1, 59, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, STEP - 1);  revisa("2 aun no hay paso", 20, 27, 1, 59, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, 1);  revisa("2 primer paso", 21, 27, 1, 58, 27, 3, 1);
        pasos(9, B_NADA, K_NADA);     revisa("2 diez pasos", 30, 27, 1, 49, 27, 3, 1);

        // Case 3: P1's buttons arrive in the right order; P2 keeps going left
        pasos(1, B_L, K_NADA);        revisa("3 BTNL (media vuelta) se ignora", 31, 27, 1, 48, 27, 3, 1);
        pasos(1, B_U, K_NADA);        revisa("3 BTNU gira hacia arriba", 31, 26, 0, 47, 27, 3, 1);
        pasos(1, B_R, K_NADA);        revisa("3 BTNR gira a la derecha", 32, 26, 1, 46, 27, 3, 1);
        pasos(1, B_D, K_NADA);        revisa("3 BTND gira hacia abajo", 32, 27, 2, 45, 27, 3, 1);

        // Case 4: P1 reaches the bottom wall (cy = 48) and its next step is a crash.
        // P2 does not crash, but a crash stops both bikes, so P2 stays too (ADR 0011).
        pasos(21, B_NADA, K_NADA);    revisa("4 P1 llega a la ultima celda", 32, 48, 2, 24, 27, 3, 1);
        choques = 0;
        ticks(0, B_NADA, K_NADA, STEP - 1);  revisa_choque("4 choca solo P1 (pared)", 1, 0);
        ticks(0, B_NADA, K_NADA, 1);  revisa("4 P1 se queda y P2 tambien", 32, 48, 2, 24, 27, 3, 0);
        if (choques !== 1) begin
            $display("ERROR 4: %0d pulsos de crash, se esperaba 1", choques);
            errores++;
        end

        // Case 5: during the ~2 s pause the bikes stay where they are and Start is ignored
        ticks(0, B_C, K_NADA, 100);   revisa("5 pausa con Start sostenido", 32, 48, 2, 24, 27, 3, 0);

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
        // Only P2 crashes; P1 stays at (40,27) too (ADR 0011).
        nueva_ronda();
        pasos(1, B_NADA, K_U);        revisa("8 turn_req2[0] = arriba", 21, 27, 1, 59, 26, 0, 1);
        pasos(1, B_NADA, K_L);        revisa("8 turn_req2[3] = izquierda", 22, 27, 1, 58, 26, 3, 1);
        pasos(1, B_NADA, K_R);        revisa("8 media vuelta de P2 se ignora", 23, 27, 1, 57, 26, 3, 1);
        pasos(17, B_NADA, K_NADA);    revisa("8 P2 justo arriba de P1", 40, 27, 1, 40, 26, 3, 1);
        ticks(0, B_NADA, K_D, STEP - 1);     revisa_choque("8 P2 entra a la cabeza de P1: choca solo P2", 0, 1);
        ticks(0, B_NADA, K_D, 1);     revisa("8 P2 se queda y P1 tambien", 40, 27, 1, 40, 26, 3, 0);

        // Cases 9 and 10, in one round with both DUTs. Everyone goes straight along row 27.
        nueva_ronda();
        // Case 9 (dut_b): P1 (20,27) and P2 (58,27) both aim at (39,27) on step 19.
        pasos(18, B_NADA, K_NADA);
        revisa_b("9 a una celda de distancia", 38, 40, 1);
        revisa("10 todavia separadas", 38, 27, 1, 41, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, STEP - 1);
        if (dut_b.crash1 !== 1'b1 || dut_b.crash2 !== 1'b1) begin
            $display("ERROR 9 mismo destino: crash1=%b crash2=%b; se esperaba 1 y 1",
                     dut_b.crash1, dut_b.crash2);
            errores++;
        end
        ticks(0, B_NADA, K_NADA, 1);
        revisa_b("9 mismo destino: chocan las dos y no avanzan", 38, 40, 0);
        // Case 10 (dut): P1 (39,27) and P2 (40,27) aim at each other's cell on step 20.
        revisa("10 cabezas juntas", 39, 27, 1, 40, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, STEP - 1);  revisa_choque("10 intercambio de cabezas: chocan las dos", 1, 1);
        ticks(0, B_NADA, K_NADA, 1);  revisa("10 ninguna avanza", 39, 27, 1, 40, 27, 3, 0);

        // Case 11: pause mid-step. No steps and no turns while paused, and the round keeps
        // running (run = 1). Without pause the step comes after the rest of the count, not
        // a whole new STEP, and the turns pressed during the pause were not kept.
        nueva_ronda();
        pasos(2, B_NADA, K_NADA);     revisa("11 antes de la pausa", 22, 27, 1, 57, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, STEP / 2);
        pause = 1'b1;
        ticks(0, B_U, K_D, 5 * STEP); revisa("11 en pausa no hay pasos", 22, 27, 1, 57, 27, 3, 1);
        if (c1 !== 1'b0 || c2 !== 1'b0) begin
            $display("ERROR 11: crash en pausa");
            errores++;
        end
        pause = 1'b0;
        ticks(0, B_NADA, K_NADA, STEP - 1 - STEP / 2);
                                      revisa("11 sin pausa: aun no hay paso", 22, 27, 1, 57, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, 1);  revisa("11 paso sin los giros de la pausa", 23, 27, 1, 56, 27, 3, 1);

        // Case 12: pause during the crash pause holds the 2 s count. The crash edge is E; without
        // pause the bikes are back at their starts 121 ticks after E (case 6).
        pasos(15, B_NADA, K_NADA);    revisa("12 cabezas juntas", 38, 27, 1, 41, 27, 3, 1);
        pasos(1, B_NADA, K_NADA);     revisa("12 cabezas juntas", 39, 27, 1, 40, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, STEP - 1);  revisa_choque("12 chocan las dos", 1, 1);
        ticks(0, B_NADA, K_NADA, 1);  revisa("12 choque (E)", 39, 27, 1, 40, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 60); revisa("12 E+60", 39, 27, 1, 40, 27, 3, 0);
        pause = 1'b1;
        ticks(0, B_C, K_NADA, 300);   revisa("12 en pausa la pausa de choque no avanza", 39, 27, 1, 40, 27, 3, 0);
        pause = 1'b0;
        ticks(0, B_NADA, K_NADA, 55); revisa("12 E+115 sin contar la pausa", 39, 27, 1, 40, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 10); revisa("12 E+125: de vuelta en la salida", 20, 27, 1, 59, 27, 3, 0);

        // Case 13: match_over keeps round_fsm in s_crash: no new round after 2 s, and Start
        // is ignored, until a reset (the restart from match_fsm) begins a new match.
        nueva_ronda();
        pasos(19, B_NADA, K_NADA);    revisa("13 cabezas juntas", 39, 27, 1, 40, 27, 3, 1);
        ticks(0, B_NADA, K_NADA, STEP - 1);  revisa_choque("13 chocan las dos", 1, 1);
        mo = 1'b1;
        ticks(0, B_NADA, K_NADA, 1);  revisa("13 choque final", 39, 27, 1, 40, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 200);
        if (cd !== 1'b0) begin
            $display("ERROR 13: crash_done=%b en E+200, se esperaba 0", cd);
            errores++;
        end
        ticks(0, B_NADA, K_NADA, 39); // E+239: the timer's second pulse
        if (cd !== 1'b1) begin
            $display("ERROR 13: crash_done=%b en E+239, se esperaba 1 (el temporizador sigue)", cd);
            errores++;
        end
        ticks(0, B_C, K_NADA, 300);   revisa("13 partida terminada: no hay ronda nueva", 39, 27, 1, 40, 27, 3, 0);
        mo = 1'b0;
        ticks(1, B_NADA, K_NADA, 1);  revisa("13 restart: a la salida", 20, 27, 1, 59, 27, 3, 0);
        ticks(0, B_NADA, K_NADA, 2);
        ticks(0, B_C, K_NADA, 1);     revisa("13 Start de la partida nueva", 20, 27, 1, 59, 27, 3, 1);
        pasos(1, B_NADA, K_NADA);     revisa("13 avanzan de nuevo", 21, 27, 1, 58, 27, 3, 1);

        // Case 14: a bike that moves into a Reward reports its slot on the step tick (codes 8,
        // 9, 10 are slots 0, 1, 2: reward 1, 2, 3); nothing on the other ticks.
        nueva_ronda();
        c1r = 4'd9; c2l = 4'd10;
        ticks(0, B_NADA, K_NADA, STEP - 2);
        if (w1 !== 2'd0 || w2 !== 2'd0) begin
            $display("ERROR 14: reward1=%0d reward2=%0d before the step", w1, w2);
            errores++;
        end
        ticks(0, B_NADA, K_NADA, 1);
        if (w1 !== 2'd2 || w2 !== 2'd3) begin
            $display("ERROR 14: reward1=%0d reward2=%0d on the step, se esperaba 2 y 3", w1, w2);
            errores++;
        end
        c1r = 4'd8; c2l = 4'd0;
        #1;
        if (w1 !== 2'd1 || w2 !== 2'd0) begin
            $display("ERROR 14: reward1=%0d reward2=%0d with codes 8 and 0, se esperaba 1 y 0", w1, w2);
            errores++;
        end
        ticks(0, B_NADA, K_NADA, 1);  revisa("14 entran a los premios", 21, 27, 1, 58, 27, 3, 1);
        if (w1 !== 2'd0 || w2 !== 2'd0) begin
            $display("ERROR 14: reward1=%0d reward2=%0d after the step", w1, w2);
            errores++;
        end

        // Case 15: a Crash Step takes no Reward (ADR 0011): P2 crashes into a Trail (code 4)
        // while a Reward is ahead of P1; neither moves and reward1 stays 0.
        c1r = 4'd10; c2l = 4'd4;
        ticks(0, B_NADA, K_NADA, STEP - 1);  revisa_choque("15 choca solo P2", 0, 1);
        if (w1 !== 2'd0 || w2 !== 2'd0) begin
            $display("ERROR 15: reward1=%0d reward2=%0d in a Crash Step, se esperaba 0", w1, w2);
            errores++;
        end
        ticks(0, B_NADA, K_NADA, 1);  revisa("15 nadie se mueve", 21, 27, 1, 58, 27, 3, 0);
        c1r = 4'd0; c2l = 4'd0;

        // Case 16: match_over while the round runs (a Goal with no Crash) stops it like a Crash:
        // no more steps, no crash pulse, and round_fsm stays out of the round until a reset.
        nueva_ronda();
        pasos(2, B_NADA, K_NADA);     revisa("16 dos pasos", 22, 27, 1, 57, 27, 3, 1);
        choques = 0;
        mo = 1'b1;
        ticks(0, B_NADA, K_NADA, 1);  revisa("16 meta: la ronda se detiene", 22, 27, 1, 57, 27, 3, 0);
        ticks(0, B_C, K_NADA, 300);   revisa("16 sigue detenida, Start no hace nada", 22, 27, 1, 57, 27, 3, 0);
        if (choques !== 0) begin
            $display("ERROR 16: %0d pulsos de crash despues de la meta", choques);
            errores++;
        end
        mo = 1'b0;
        ticks(1, B_NADA, K_NADA, 1);  revisa("16 restart: a la salida", 20, 27, 1, 59, 27, 3, 0);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
