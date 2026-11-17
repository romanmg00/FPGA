// Author: Roman (romanmg00). Changes by Alan (AIF31): Arena codes and Crashes into Trails (#40),
// both Bikes stop in a Crash Step (ADR 0011, #39).
// Position logic for the two bikes: from the buttons to the position on screen.
// It keeps the role and ports of the handout's position_logic, but the bike now moves on
// its own in rounds instead of following the buttons. Everything runs on clk_juego (~60 Hz).
// See the "position logic" figure in the report.
//
// Flow: buttons -> turn_req -> bike_move -> next_cx/next_cy -> wall, bikes and Arena check
//       -> advance (move) or crash. step_counter sets how often a step happens.
// The Arena (arena_link in game_top) gives the codes of the 4 neighbour Cells of each head;
// the code of the next Cell decides whether it is occupied (contract section 3).
module position_logic #(
    // Ticks of clk_juego per step. game_top passes the same value to bike_glide (ADR 0010).
    parameter int STEP_TICKS = 8,
    // P2's start column. Only a testbench changes it, to arrange a same-target crash.
    parameter logic [6:0] P2_START_CX = 7'd59
) (
    input  logic        clk,                    // clk_juego (~60 Hz)
    input  logic        rst,                    // rst_juego, synchronous, active high
    input  logic [4:0]  btn,                    // synchronised buttons: [0] U, [1] D, [2] L, [3] R, [4] centre
    input  logic [3:0]  turn_req2,              // turn requests for bike 2 (from keyboard) [0] U, [1] R, [2] D, [3] L
    input  logic        pause,                  // SW0 (synchronised): no steps, no turns, the crash pause holds
    input  logic        match_over,             // score_unit: the match ended, round_fsm stays in s_crash
    output logic [10:0] blkpos1_x,              // top-left corner of the bike 1, in pixels
    output logic [10:0] blkpos1_y,              // top-left corner of the bike 1, in pixels
    output logic [10:0] blkpos2_x,              // top-left corner of the bike 2, in pixels
    output logic [10:0] blkpos2_y,              // top-left corner of the bike 2, in pixels
    output logic [1:0]  heading1, heading2,     // bike direction: 0 U, 1 R, 2 D, 3 L (for the sprites)
    output logic        crash1, crash2,         // crash check -> round_fsm (c), score_unit: the bike crashed on this step
    output logic        crash_done,             // u_crash_timer -> round_fsm (t), match_fsm: the crash pause is over
    // Arena (arena_link): load and step go out; the neighbour codes of each head come back
    output logic        load,                   // Bikes at their starts; its rise prepares the Arena
    output logic        step,                   // the Step taken: the Bikes move at this edge
    input  logic [3:0]  code1_u, code1_r, code1_d, code1_l,   // neighbours of bike 1's head
    input  logic [3:0]  code2_u, code2_r, code2_d, code2_l,   // neighbours of bike 2's head
    input  logic        codes_valid             // 1 when the codes are those of the current heads
);

    // ---------------------------------------------------------------
    // Internal signals (source -> destination)
    // ---------------------------------------------------------------
    logic [3:0] turn_req1;                       // reordered buttons -> bike_move
    logic       run;                             // round_fsm -> bike_move, u_step_counter: the round is running
    logic       step_due;                        // u_step_counter -> step: a step is due
    logic [3:0] code_next1, code_next2;          // Arena code of the cell of the next step
    logic [6:0] cx1, cy1, cx2, cy2;              // bike_move -> pixel conversion: current cell
    logic [6:0] next_cx1, next_cy1, 
                next_cx2, next_cy2;              // bike_move -> wall check: cell of the next step
    logic       valid1, valid2;                  // wall check: the next cell is inside the arena
    logic       advance1, advance2;              // wall check -> bike_move: move one cell
    logic       crash;                           // either bike crashed -> round_fsm (c): the bike crashed
    logic       occupied1, occupied2;            // the cell of the next step is a wall, trail or head
    // ---------------------------------------------------------------
    // 1. Inputs: the board gives U,D,L,R; bike_move expects U,R,D,L
    // ---------------------------------------------------------------
    
    assign turn_req1 = {btn[2], btn[1], btn[3], btn[0]};
    
    // ---------------------------------------------------------------
    // 2. Round control
    // ---------------------------------------------------------------
    
    round_fsm u_round_fsm(
        .clk(clk),
        .rst(rst),
        .s(btn[4]),
        .c(crash),
        .t(crash_done && !match_over),
        .load(load),
        .run(run)
    );

    step_counter #(
        .STEP_TICKS(120)
    ) u_crash_timer (
        .clk(clk),
        .rst(rst),
        .pause(pause),
        .run(~load && ~run),
        .step(crash_done)
    );    

    // ---------------------------------------------------------------
    // 3. Pace: one step every STEP_TICKS ticks while run = 1
    // ---------------------------------------------------------------
    step_counter #(
        .STEP_TICKS(STEP_TICKS)
    ) u_step_counter (
        .clk(clk),
        .rst(rst),
        .pause(pause),
        .run(run),
        .step(step_due)
    );

    // A step is taken only with the codes of the current heads. They arrive 4 ticks after the
    // previous step, so with 6 or 8 ticks per step this always holds; if not, the step waits
    // for the next period and the pending turn is kept.
    assign step = step_due && codes_valid;

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
        .run(run && !pause),
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
        .run(run && !pause),
        .advance(advance2),
        .turn_req(turn_req2),
        .cx(cx2),
        .cy(cy2),
        .heading(heading2),
        .next_cx(next_cx2),
        .next_cy(next_cy2)
    );

    // ---------------------------------------------------------------
    // 5. Wall, bikes and Arena check: valid cells are cx 1..78, cy 5..48
    // ---------------------------------------------------------------
    // The next cell's code is the neighbour in the direction of the move: compare the next cell
    // with the current one. Only 0 (empty) and 8-10 (Rewards) are free; anything else blocks.
    always_comb begin
        if (next_cy1 != cy1)
            code_next1 = (next_cy1 < cy1) ? code1_u : code1_d;
        else
            code_next1 = (next_cx1 > cx1) ? code1_r : code1_l;
        if (next_cy2 != cy2)
            code_next2 = (next_cy2 < cy2) ? code2_u : code2_d;
        else
            code_next2 = (next_cx2 > cx2) ? code2_r : code2_l;
    end
    assign occupied1 = !(code_next1 == 4'd0 || code_next1 == 4'd8 || code_next1 == 4'd9 || code_next1 == 4'd10);
    assign occupied2 = !(code_next2 == 4'd0 || code_next2 == 4'd8 || code_next2 == 4'd9 || code_next2 == 4'd10);

    assign valid1   = (next_cx1 >= 1 && next_cx1 <= 78 && next_cy1 >= 5 && next_cy1 <= 48);
    assign valid2   = (next_cx2 >= 1 && next_cx2 <= 78 && next_cy2 >= 5 && next_cy2 <= 48);
    // A crash stops both bikes: the one that did not crash stays in its cell too (ADR 0011)
    assign advance1 = step && !crash;
    assign advance2 = step && !crash;
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
