// Author: Roman (romanmg00): Rounds, Steps, Turns, both Bikes, the wall and Bike-to-Bike Crashes
// Changes by Alan (AIF31): Crashes into Trails and heads (#40), both Bikes stop in a Crash (#39),
// Rewards taken and a Goal ends the Round (G4)
// Flow: buttons -> bike_move (next Cell) -> wall, Bike and
// Arena checks -> advance, or Crash.
module position_logic #(
    parameter int STEP_TICKS = 8,               // ticks per Step (ADR 0010)
    parameter logic [6:0] P2_START_CX = 7'd59   // P2's start column
) (
    input  logic        clk,                    // clk_juego
    input  logic        rst,
    input  logic [4:0]  btn,                    // [0] Up, [1] Down, [2] Left, [3] Right, [4] Start
    input  logic [3:0]  turn_req2,              // [0] Up, [1] Right, [2] Down, [3] Left
    input  logic        pause,
    input  logic        match_over,
    output logic [10:0] blkpos1_x,              // Cell x 16
    output logic [10:0] blkpos1_y,
    output logic [10:0] blkpos2_x,
    output logic [10:0] blkpos2_y,
    output logic [1:0]  heading1, heading2,     // 0 Up, 1 Right, 2 Down, 3 Left
    output logic        crash1, crash2,
    output logic        crash_done,             // Crash pause
    output logic [1:0]  reward1, reward2,       // Reward taken in this Step: 0 none, 1 slot 0, 2 slot 1, 3 slot 2
    // Arena
    output logic        load,                   // Bikes at their start
    output logic        step,                   // the Step taken; in a Crash Step no Bike moves
    input  logic [3:0]  code1_u, code1_r, code1_d, code1_l,   // Bikes: codes of the Cells up, right, down and left
    input  logic [3:0]  code2_u, code2_r, code2_d, code2_l,   
    input  logic        codes_valid           
);

    logic [3:0] turn_req1;
    logic       run;
    logic       step_due;
    logic [3:0] code_next1, code_next2;          // code of the next Cell
    logic [6:0] cx1, cy1, cx2, cy2;
    logic [6:0] next_cx1, next_cy1,
                next_cx2, next_cy2;
    logic       valid1, valid2;                  // next Cell inside the walls
    logic       advance1, advance2;
    logic       crash;                           // either Bike
    logic       occupied1, occupied2;            // next Cell not free

    // The board buttons are Up, Down, Left, Right; bike_move wants the Heading order Up, Right, Down, Left.
    assign turn_req1 = {btn[2], btn[1], btn[3], btn[0]};

    // Round: wait for Start (load = 1), run, Crash pause, wait for Start's release.
    // After the Match's last Crash, t stays 0, so round_fsm stays in the Crash.
    // A Match won on the Goal with no Crash also stops the Round there (match_over).
    round_fsm u_round_fsm(
        .clk(clk),
        .rst(rst),
        .s(btn[4]),
        .c(crash || match_over),
        .t(crash_done && !match_over),
        .load(load),
        .run(run)
    );

    // Crash pause: counts only while neither load nor run (round_fsm's s_crash); 120 ticks = 2 s.
    step_counter #(
        .STEP_TICKS(120)
    ) u_crash_timer (
        .clk(clk),
        .rst(rst),
        .pause(pause),
        .run(~load && ~run),
        .step(crash_done)
    );

    // Pace: one Step every STEP_TICKS ticks while the Round runs.
    step_counter #(
        .STEP_TICKS(STEP_TICKS)
    ) u_step_counter (
        .clk(clk),
        .rst(rst),
        .pause(pause),
        .run(run),
        .step(step_due)
    );

    // A Step needs the codes of the current heads. They arrive 4 ticks after the last Step,
    // so at 6 or 8 ticks per Step it never waits; if it does, the Pending Turn is kept.
    assign step = step_due && codes_valid;

    // P1 starts at (20, 27) facing right, P2 at (P2_START_CX, 27) facing left.
    // Turns are taken only while the Round runs and not in Pause.
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

    // The next Cell's code is the neighbour on the side the Bike moves
    always_comb begin
        if (next_cy1 != cy1)
            code_next1 = (next_cy1 < cy1) ? code1_u : code1_d; // up or down
        else
            code_next1 = (next_cx1 > cx1) ? code1_r : code1_l; // right or left
        if (next_cy2 != cy2)
            code_next2 = (next_cy2 < cy2) ? code2_u : code2_d; // up or down
        else
            code_next2 = (next_cx2 > cx2) ? code2_r : code2_l; // right or left
    end

    // Free Cells are 0 (EMPTY) and 8-10 (Rewards); any other code is a Crash:
    //   1 a wall, 2 P1's Trail, 3 P1's head, 4 P2's Trail, 5 P2's head,
    //   6 reserved for CRASH, 7 reserved, 11-15 never written.
    assign occupied1 = !(code_next1 == 4'd0 || code_next1 == 4'd8 || code_next1 == 4'd9 || code_next1 == 4'd10); // not a free cell
    assign occupied2 = !(code_next2 == 4'd0 || code_next2 == 4'd8 || code_next2 == 4'd9 || code_next2 == 4'd10); // same

    // Inside the walls: cx 1-78, cy 5-48 (cy 0-3 is the HUD, cy 4 and 49 and cx 0 and 79 the walls).
    assign valid1   = (next_cx1 >= 1 && next_cx1 <= 78 && next_cy1 >= 5 && next_cy1 <= 48);
    assign valid2   = (next_cx2 >= 1 && next_cx2 <= 78 && next_cy2 >= 5 && next_cy2 <= 48);

    // A Crash stops both Bikes: the one that did not crash stays in its Cell too (ADR 0011).
    assign advance1 = step && !crash;
    assign advance2 = step && !crash;

    // A Crash is either Bike into a wall, into the other Bike, or into a Trail or head.
    assign crash1 = step &&
                    (!valid1 ||                                         // into a wall
                    (next_cx1 == next_cx2 && next_cy1 == next_cy2) ||   // both into the same Cell
                    (next_cx1 == cx2 && next_cy1  == cy2) ||            // into the other Bike's Cell
                    occupied1);                                         // into a Trail or head
    assign crash2 = step &&
                    (!valid2 ||
                    (next_cx2 == next_cx1 && next_cy2 == next_cy1) ||
                    (next_cx2 == cx1 && next_cy2  == cy1) ||
                    occupied2);
    assign crash = crash1 || crash2;

    // A Bike that moves into a Reward takes it: codes 8, 9, 10 are slots 0, 1, 2.
    // No Reward is taken in a Crash Step.
    always_comb begin
        reward1 = 2'd0;
        reward2 = 2'd0;
        if (advance1)
            case (code_next1)
                4'd8:    reward1 = 2'd1;
                4'd9:    reward1 = 2'd2;
                4'd10:   reward1 = 2'd3;
                default: reward1 = 2'd0;
            endcase
        if (advance2)
            case (code_next2)
                4'd8:    reward2 = 2'd1;
                4'd9:    reward2 = 2'd2;
                4'd10:   reward2 = 2'd3;
                default: reward2 = 2'd0;
            endcase
    end

    // Cells to pixels: x 16 is 4 zero bits on the right.
    assign blkpos1_x = {cx1, 4'b0000}; 
    assign blkpos1_y = {cy1, 4'b0000};
    assign blkpos2_x = {cx2, 4'b0000};
    assign blkpos2_y = {cy2, 4'b0000};

endmodule
