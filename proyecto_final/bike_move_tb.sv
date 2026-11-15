// Self-checking testbench for bike_move.
// The pending turn is not a port, so it is observed through (next_cx, next_cy):
// the cell the bike would move to on the next advance.
// Headings: 0 UP, 1 RIGHT, 2 DOWN, 3 LEFT. turn_req: [0] UP, [1] RIGHT, [2] DOWN, [3] LEFT.
module bike_move_tb;

    localparam logic [1:0] UP = 2'd0, RIGHT = 2'd1, DOWN = 2'd2, LEFT = 2'd3;
    localparam logic [3:0] B_NADA = 4'b0000, B_UP = 4'b0001, B_RIGHT = 4'b0010,
                           B_DOWN = 4'b0100, B_LEFT = 4'b1000;

    logic       clk;
    logic       rst, load, run, advance;
    logic [3:0] turn_req;
    logic [6:0] cx, cy, next_cx, next_cy;
    logic [1:0] heading;
    // Second bike (P2), only to check the parameters
    logic [6:0] cx2, cy2, next_cx2, next_cy2;
    logic [1:0] heading2;
    int         errores = 0;

    // P1: default values, (20, 27) heading right
    bike_move dut (
        .clk(clk), .rst(rst), .load(load), .run(run), .advance(advance),
        .turn_req(turn_req),
        .cx(cx), .cy(cy), .heading(heading), .next_cx(next_cx), .next_cy(next_cy)
    );

    // P2: (59, 27) heading left
    bike_move #(.START_CX(7'd59), .START_CY(7'd27), .START_HEADING(2'd3)) dut2 (
        .clk(clk), .rst(rst), .load(load), .run(1'b0), .advance(1'b0),
        .turn_req(4'b0000),
        .cx(cx2), .cy(cy2), .heading(heading2), .next_cx(next_cx2), .next_cy(next_cy2)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Called on a falling edge (or at t=0): sets the inputs and waits for the next
    // falling edge, so each call spans exactly one rising edge.
    task automatic paso(input logic r_i, input logic l_i, input logic run_i,
                        input logic adv_i, input logic [3:0] req_i);
        rst      = r_i;
        load     = l_i;
        run      = run_i;
        advance  = adv_i;
        turn_req = req_i;
        @(negedge clk);
    endtask

    // Checks the cell, the heading and the next cell (which shows the pending turn)
    task automatic revisa(input string caso,
                          input logic [6:0] cx_e, input logic [6:0] cy_e, input logic [1:0] h_e,
                          input logic [6:0] ncx_e, input logic [6:0] ncy_e);
        if (cx !== cx_e || cy !== cy_e || heading !== h_e ||
            next_cx !== ncx_e || next_cy !== ncy_e) begin
            $display("ERROR %s: (%0d,%0d) h=%0d next=(%0d,%0d); se esperaba (%0d,%0d) h=%0d next=(%0d,%0d)",
                     caso, cx, cy, heading, next_cx, next_cy,
                     cx_e, cy_e, h_e, ncx_e, ncy_e);
            errores++;
        end
    endtask

    initial begin
        rst = 1'b1; load = 1'b0; run = 1'b0; advance = 1'b0; turn_req = B_NADA;

        // Case 1: reset puts each bike at its start cell
        paso(1, 0, 0, 0, B_NADA); revisa("1 reset P1", 20, 27, RIGHT, 21, 27);
        if (cx2 !== 59 || cy2 !== 27 || heading2 !== LEFT || next_cx2 !== 58 || next_cy2 !== 27) begin
            $display("ERROR 1 reset P2: (%0d,%0d) h=%0d next=(%0d,%0d)",
                     cx2, cy2, heading2, next_cx2, next_cy2);
            errores++;
        end

        // Case 2: without turns, each advance moves one cell in the current direction
        paso(0, 0, 1, 0, B_NADA); revisa("2 sin advance no se mueve", 20, 27, RIGHT, 21, 27);
        paso(0, 0, 1, 1, B_NADA); revisa("2 primer advance", 21, 27, RIGHT, 22, 27);
        paso(0, 0, 1, 1, B_NADA); revisa("2 segundo advance", 22, 27, RIGHT, 23, 27);

        // Case 3: a 90-degree turn is stored and applied on the advance
        paso(0, 0, 1, 0, B_UP);   revisa("3 UP queda pendiente", 22, 27, RIGHT, 22, 26);
        paso(0, 0, 1, 1, B_NADA); revisa("3 advance gira a UP", 22, 26, UP, 22, 25);

        // Case 4: a 180-degree turn is rejected
        paso(0, 0, 1, 0, B_DOWN); revisa("4 DOWN contra UP se ignora", 22, 26, UP, 22, 25);
        paso(0, 0, 1, 1, B_NADA); revisa("4 sigue hacia arriba", 22, 25, UP, 22, 24);

        // Case 5: requesting the current direction does not cancel a pending turn
        paso(0, 0, 1, 0, B_RIGHT); revisa("5 RIGHT pendiente", 22, 25, UP, 23, 25);
        paso(0, 0, 1, 0, B_UP);    revisa("5 UP (igual a heading) no lo cancela", 22, 25, UP, 23, 25);
        paso(0, 0, 1, 1, B_NADA);  revisa("5 advance gira a RIGHT", 23, 25, RIGHT, 24, 25);

        // Case 6: UP then LEFT before the advance; the bike must not reverse
        paso(0, 0, 1, 0, B_UP);   revisa("6 UP pendiente", 23, 25, RIGHT, 23, 24);
        paso(0, 0, 1, 0, B_LEFT); revisa("6 LEFT contra heading RIGHT se ignora", 23, 25, RIGHT, 23, 24);
        paso(0, 0, 1, 1, B_NADA); revisa("6 advance gira a UP", 23, 24, UP, 23, 23);

        // Case 7: press and release between two advances; the turn is not forgotten
        paso(0, 0, 1, 0, B_RIGHT); revisa("7 RIGHT pendiente", 23, 24, UP, 24, 24);
        repeat (4) begin
            paso(0, 0, 1, 0, B_NADA); revisa("7 boton suelto, sigue pendiente", 23, 24, UP, 24, 24);
        end
        paso(0, 0, 1, 1, B_NADA);  revisa("7 advance gira a RIGHT", 24, 24, RIGHT, 25, 24);

        // Case 8: two buttons together; UP wins over DOWN
        paso(0, 0, 1, 0, B_UP | B_DOWN); revisa("8 UP+DOWN gana UP", 24, 24, RIGHT, 24, 23);
        paso(0, 0, 1, 1, B_NADA);        revisa("8 advance gira a UP", 24, 23, UP, 24, 22);

        // Case 9: turns are ignored without run
        paso(0, 0, 0, 0, B_LEFT); revisa("9 LEFT sin run se ignora", 24, 23, UP, 24, 22);
        paso(0, 0, 1, 1, B_NADA); revisa("9 advance sigue a UP", 24, 22, UP, 24, 21);

        // Case 10: load returns to the start cell and clears the pending turn
        paso(0, 0, 1, 0, B_LEFT); revisa("10 LEFT pendiente", 24, 22, UP, 23, 22);
        paso(0, 1, 0, 0, B_NADA); revisa("10 load", 20, 27, RIGHT, 21, 27);

        // Case 11: advance and a turn on the same tick; advance wins and the turn is stored on the next tick
        paso(0, 0, 1, 1, B_UP); revisa("11 advance y UP juntos", 21, 27, RIGHT, 22, 27);
        paso(0, 0, 1, 0, B_UP); revisa("11 UP sostenido entra", 21, 27, RIGHT, 21, 26);

        // Case 12: rst wins over advance
        paso(1, 0, 1, 1, B_NADA); revisa("12 rst con advance", 20, 27, RIGHT, 21, 27);

        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
