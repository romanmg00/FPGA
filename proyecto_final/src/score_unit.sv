// Author: Alan (AIF31).
module score_unit (
    input  logic       clk,                    // clk_juego
    input  logic       rst,
    input  logic       new_match,
    input  logic       waiting,
    input  logic [1:0] goal_sel,               // {SW15, SW14}: Points Goal 10, 20, 30, 40
    input  logic       crash1, crash2,
    input  logic [1:0] reward1, reward2,       // 0 none, 1-2 a +1 slot, 3 the +3 slot
    output logic [5:0] points_p1, points_p2,   // at most 39 + 3 + 3 = 45
    output logic [1:0] lives_p1, lives_p2,
    output logic [1:0] result,                 // 0 Match on, 1 P1 wins, 2 P2 wins, 3 Draw
    output logic       match_over
);

    logic [5:0] goal;                          // this Match's Points Goal
    logic [5:0] reward_points_p1, reward_points_p2;
    logic [5:0] next_points_p1, next_points_p2;
    logic [1:0] next_lives_p1, next_lives_p2;
    logic       reached_p1, reached_p2;        // at or over the Goal after this Step
    logic [1:0] next_result;

    // Rewards, Crashes and the Survival Bonus.
    always_comb
    begin
        case (reward1)
            2'd0:    reward_points_p1 = 6'd0;
            2'd3:    reward_points_p1 = 6'd3;  // slot 2
            default: reward_points_p1 = 6'd1;  // slots 0 and 1
        endcase
        case (reward2)
            2'd0:    reward_points_p2 = 6'd0;
            2'd3:    reward_points_p2 = 6'd3;
            default: reward_points_p2 = 6'd1;
        endcase
        next_lives_p1  = crash1 ? lives_p1 - 2'd1 : lives_p1;
        next_lives_p2  = crash2 ? lives_p2 - 2'd1 : lives_p2;
        next_points_p1 = points_p1 + reward_points_p1 + ((crash2 && !crash1) ? 6'd3 : 6'd0);  // Survival Bonus
        next_points_p2 = points_p2 + reward_points_p2 + ((crash1 && !crash2) ? 6'd3 : 6'd0);
        reached_p1     = (next_points_p1 >= goal);
        reached_p2     = (next_points_p2 >= goal);
        // The Goal first; both at once, or both out of Lives at once: more Points wins.
        if ((reached_p1 && reached_p2) ||
            (!reached_p1 && !reached_p2 && next_lives_p1 == 2'd0 && next_lives_p2 == 2'd0))
        begin
            if (next_points_p1 > next_points_p2)
                next_result = 2'd1;            // P1 wins
            else if (next_points_p2 > next_points_p1)
                next_result = 2'd2;            // P2 wins
            else
                next_result = 2'd3;            // Draw
        end
        else if (reached_p1)
            next_result = 2'd1;                // P1 wins
        else if (reached_p2)
            next_result = 2'd2;                // P2 wins
        else if (next_lives_p1 == 2'd0)
            next_result = 2'd2;                // P2 wins
        else if (next_lives_p2 == 2'd0)
            next_result = 2'd1;                // P1 wins
        else
            next_result = 2'd0;                // the Match goes on
    end

    // A Step with a Crash or a Reward updates Points, Lives and the result.
    always_ff @(posedge clk)
    begin
        if (rst || new_match)
        begin
            points_p1 <= 6'd0;
            points_p2 <= 6'd0;
            lives_p1  <= 2'd3;
            lives_p2  <= 2'd3;
            result    <= 2'd0;
        end
        else if ((crash1 || crash2 || reward1 != 2'd0 || reward2 != 2'd0) && result == 2'd0)
        begin
            points_p1 <= next_points_p1;
            points_p2 <= next_points_p2;
            lives_p1  <= next_lives_p1;
            lives_p2  <= next_lives_p2;
            result    <= next_result;
        end
    end

    // The Goal follows {SW15, SW14} only while waiting, so it keeps the tick Start was accepted.
    always_ff @(posedge clk)
    begin
        if (rst)
            goal <= 6'd10;
        else if (waiting)
            case (goal_sel)
                2'd0: goal <= 6'd10;
                2'd1: goal <= 6'd20;
                2'd2: goal <= 6'd30;
                2'd3: goal <= 6'd40;
            endcase
    end

    assign match_over = (result != 2'd0);

endmodule
