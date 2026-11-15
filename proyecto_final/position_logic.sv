// Position logic for the two bikes: from the buttons to the position on screen.
// It keeps the role and ports of the handout's position_logic, but the bike now moves on
// its own in rounds instead of following the buttons. Everything runs on clk_juego (~60 Hz).
// See the "position logic" figure in the report.
//
// Flow: buttons -> turn_req -> bike_move -> next_cx/next_cy -> wall check
//       -> advance (move) or crash. step_counter sets how often a step happens.
module position_logic #(
    // P2's start column. Only a testbench changes it, to arrange a same-target crash.
    parameter logic [6:0] P2_START_CX = 7'd59
) (
    input  logic        clk,                    // clk_juego (~60 Hz)
    input  logic        rst,                    // rst_juego, synchronous, active high
    input  logic [4:0]  btn,                    // synchronised buttons: [0] U, [1] D, [2] L, [3] R, [4] centre
    input  logic [3:0]  turn_req2,              // turn requests for bike 2 (from keyboard) [0] U, [1] R, [2] D, [3] L
    output logic [10:0] blkpos1_x,              // top-left corner of the bike 1, in pixels
    output logic [10:0] blkpos1_y,              // top-left corner of the bike 1, in pixels
    output logic [10:0] blkpos2_x,              // top-left corner of the bike 2, in pixels
    output logic [10:0] blkpos2_y,              // top-left corner of the bike 2, in pixels
    output logic [1:0]  heading1, heading2      // bike direction: 0 U, 1 R, 2 D, 3 L (for the sprites)
);

    // ---------------------------------------------------------------
    // Internal signals (source -> destination)
    // ---------------------------------------------------------------
    logic [3:0] turn_req1;                       // reordered buttons -> bike_move
    logic       load;                            // round_fsm -> bike_move: hold the bike at its start cell
    logic       run;                             // round_fsm -> bike_move, u_step_counter: the round is running
    logic       step;                            // u_step_counter -> wall check: a step is due
    logic [6:0] cx1, cy1, cx2, cy2;              // bike_move -> pixel conversion: current cell
    logic [6:0] next_cx1, next_cy1, 
                next_cx2, next_cy2;              // bike_move -> wall check: cell of the next step
    logic       valid1, valid2;                  // wall check: the next cell is inside the arena
    logic       advance1, advance2;              // wall check -> bike_move: move one cell
    logic       crash1, crash2;                  // wall and bikes check -> round_fsm (c): the bike crashed
    logic       crash_done;                      // u_crash_timer -> round_fsm (t): the crash pause is over
    logic       crash;                           // either bike crashed -> round_fsm (c): the bike crashed
    logic       occupied1, occupied2;            //check occupied cells
    // ---------------------------------------------------------------
    // 1. Inputs: the board gives U,D,L,R; bike_move expects U,R,D,L
    // ---------------------------------------------------------------
    
    assign turn_req1 = {btn[2], btn[1], btn[3], btn[0]};
    assign occupied1 = 1'b0;
    assign occupied2 = 1'b0;
    
    // ---------------------------------------------------------------
    // 2. Round control
    // ---------------------------------------------------------------
    
    round_fsm u_round_fsm(
        .clk(clk),
        .rst(rst),
        .s(btn[4]),
        .c(crash),
        .t(crash_done),
        .load(load),
        .run(run)
    );

    step_counter #(
        .STEP_TICKS(120)
    ) u_crash_timer (
        .clk(clk),
        .rst(rst),
        .run(~load && ~run),
        .step(crash_done)
    );    

    // ---------------------------------------------------------------
    // 3. Pace: one step every 6 ticks while run = 1
    // ---------------------------------------------------------------
    step_counter #(
        .STEP_TICKS(6)
    ) u_step_counter (
        .clk(clk),
        .rst(rst),
        .run(run),
        .step(step)
    );

    // ---------------------------------------------------------------
    // 4. The bikes
    // ---------------------------------------------------------------
    bike_move #(
        .START_CX(7'd20),
        .START_CY(7'd27),
        .START_HEADING(2'd1)
    ) u_bike_move1 (
        .clk(clk),
        .rst(rst),
        .load(load),
        .run(run),
        .advance(advance1),
        .turn_req(turn_req1),
        .cx(cx1),
        .cy(cy1),
        .heading(heading1),
        .next_cx(next_cx1),
        .next_cy(next_cy1)
    );

    bike_move #(
        .START_CX(P2_START_CX),
        .START_CY(7'd27),
        .START_HEADING(2'd3)
    ) u_bike_move2 (
        .clk(clk),
        .rst(rst),
        .load(load),
        .run(run),
        .advance(advance2),
        .turn_req(turn_req2),
        .cx(cx2),
        .cy(cy2),
        .heading(heading2),
        .next_cx(next_cx2),
        .next_cy(next_cy2)
    );

    // ---------------------------------------------------------------
    // 5. Wall check: valid cells are cx 1..78, cy 5..48
    // ---------------------------------------------------------------
    assign valid1   = (next_cx1 >= 1 && next_cx1 <= 78 && next_cy1 >= 5 && next_cy1 <= 48);
    assign valid2   = (next_cx2 >= 1 && next_cx2 <= 78 && next_cy2 >= 5 && next_cy2 <= 48);
    assign advance1 = step && !crash1;
    assign advance2 = step && !crash2;
    assign crash1 = step && 
                    (!valid1 || 
                    (next_cx1 == next_cx2 && next_cy1 == next_cy2) || 
                    (next_cx1 == cx2 && next_cy1  == cy2) || 
                    occupied1);
    assign crash2 = step && 
                    (!valid2 || 
                    (next_cx2 == next_cx1 && next_cy2 == next_cy1) || 
                    (next_cx2 == cx1 && next_cy2  == cy1) || 
                    occupied2);
    assign crash = crash1 || crash2;

    // ---------------------------------------------------------------
    // 6. Output: cells to pixels (x16)
    // ---------------------------------------------------------------
    assign blkpos1_x = {cx1, 4'b0000};
    assign blkpos1_y = {cy1, 4'b0000};
    assign blkpos2_x = {cx2, 4'b0000};
    assign blkpos2_y = {cy2, 4'b0000};

endmodule
