// Position logic of one bike (P1): from the buttons to the position on screen.
// It keeps the role and ports of the handout's position_logic, but the bike now moves on
// its own in rounds instead of following the buttons. Everything runs on clk_juego (~60 Hz).
// See the "position logic" figure in the report.
//
// Flow: buttons -> turn_req -> bike_move -> next_cx/next_cy -> wall check
//       -> advance (move) or crash. step_counter sets how often a step happens.
module position_logic (
    input  logic        clk,        // clk_juego (~60 Hz)
    input  logic        rst,        // rst_juego, synchronous, active high
    input  logic [4:0]  btn,        // synchronised buttons: [0] U, [1] D, [2] L, [3] R, [4] centre
    output logic [10:0] blkpos_x,   // top-left corner of the bike, in pixels
    output logic [10:0] blkpos_y,
    output logic [1:0]  heading     // bike direction: 0 U, 1 R, 2 D, 3 L (for the sprites)
);

    // ---------------------------------------------------------------
    // Internal signals (source -> destination)
    // ---------------------------------------------------------------
    logic [3:0] turn_req;            // reordered buttons -> bike_move
    logic       load;                // round_fsm -> bike_move: hold the bike at its start cell
    logic       run;                 // round_fsm -> bike_move, u_step_counter: the round is running
    logic       step;                // u_step_counter -> wall check: a step is due
    logic [6:0] cx, cy;              // bike_move -> pixel conversion: current cell
    logic [6:0] next_cx, next_cy;    // bike_move -> wall check: cell of the next step
    logic       valid;               // wall check: the next cell is inside the arena
    logic       advance;             // wall check -> bike_move: move one cell
    logic       crash;               // wall check -> round_fsm (c): the bike crashed
    logic       crash_done;          // u_crash_timer -> round_fsm (t): the crash pause is over

    // ---------------------------------------------------------------
    // 1. Inputs: the board gives U,D,L,R; bike_move expects U,R,D,L
    // ---------------------------------------------------------------
    assign turn_req = {btn[2], btn[1], btn[3], btn[0]};

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
    // 4. The bike
    // ---------------------------------------------------------------
    bike_move #(
        .START_CX(7'd20),
        .START_CY(7'd27),
        .START_HEADING(2'd1)
    ) u_bike_move (
        .clk(clk),
        .rst(rst),
        .load(load),
        .run(run),
        .advance(advance),
        .turn_req(turn_req),
        .cx(cx),
        .cy(cy),
        .heading(heading),
        .next_cx(next_cx),
        .next_cy(next_cy)
    );

    // ---------------------------------------------------------------
    // 5. Wall check: valid cells are cx 1..78, cy 5..48
    // ---------------------------------------------------------------
    assign valid   = (next_cx >= 1 && next_cx <= 78 && next_cy >= 5 && next_cy <= 48);
    assign advance = step && valid;
    assign crash   = step && !valid;

    // ---------------------------------------------------------------
    // 6. Output: cells to pixels (x16)
    // ---------------------------------------------------------------
    assign blkpos_x = {cx, 4'b0000};
    assign blkpos_y = {cy, 4'b0000};

endmodule
