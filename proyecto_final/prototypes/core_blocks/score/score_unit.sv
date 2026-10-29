// Owner: Alan (G5). Domain: clk = clk_juego (~60 Hz, ADR 0002).
// ALL ports, widths, result codes and priorities are PROVISIONAL (contract pending).
// No internal CDC: goal_sel must already be synchronized; Step outcome inputs
// must be coherent game-domain signals. Display outputs need external CDC.
// rst > new_match > step_outcome; no Round reset. Caller gates strobe during
// Pause/preparation and before first Match. Terminal result holds until new_match.
// Collection validity/slot comes from resolver; slot 3 is invalid (ignored).
// Crashed+collected is outside legal resolver traffic, but follows model addition.
module score_unit (
    input logic clk, rst, new_match, step_outcome,
    input logic [1:0] goal_sel,
    input logic crashed_p1, crashed_p2,
    input logic collected_valid_p1, collected_valid_p2,
    input logic [1:0] collected_slot_p1, collected_slot_p2,
    output logic [5:0] points_p1, points_p2,
    output logic [1:0] lives_p1, lives_p2,
    output logic [5:0] points_goal,
    output logic [1:0] result
);
    import game_pkg::*;
    // Maximum legal final-Step total: 39 + 3 + 3 = 45; 6 bits hold 0..63.
    // Lives 0..3 need 2 bits. Goal 40 also needs 6 bits.
    localparam logic [1:0] RESULT_NONE=2'd0, RESULT_P1=2'd1,
                           RESULT_P2=2'd2, RESULT_DRAW=2'd3;
    logic [5:0] next_points_p1, next_points_p2;
    logic [1:0] next_lives_p1, next_lives_p2, next_result;
    function automatic logic [5:0] reward(input logic valid, input logic [1:0] slot);
        reward = 6'd0;
        if (valid) begin
            case (slot)
                2'd0: reward = 6'(REWARD_PTS0);
                2'd1: reward = 6'(REWARD_PTS1);
                2'd2: reward = 6'(REWARD_PTS2);
                default: reward = 6'd0;
            endcase
        end
    endfunction
    function automatic logic [1:0] higher(input logic [5:0] p1, p2);
        if (p1 == p2) higher = RESULT_DRAW;
        else if (p1 > p2) higher = RESULT_P1;
        else higher = RESULT_P2;
    endfunction
    always_comb begin
        next_points_p1 = points_p1 + reward(collected_valid_p1, collected_slot_p1);
        next_points_p2 = points_p2 + reward(collected_valid_p2, collected_slot_p2);
        next_lives_p1 = lives_p1;
        next_lives_p2 = lives_p2;
        if (crashed_p1) next_lives_p1 = lives_p1 - 2'd1;
        else if (crashed_p2) next_points_p1 = next_points_p1 + 6'(SURVIVAL_BONUS);
        if (crashed_p2) next_lives_p2 = lives_p2 - 2'd1;
        else if (crashed_p1) next_points_p2 = next_points_p2 + 6'(SURVIVAL_BONUS);
        next_result = RESULT_NONE;
        if ((next_points_p1 >= points_goal) && (next_points_p2 >= points_goal))
            next_result = higher(next_points_p1, next_points_p2);
        else if (next_points_p1 >= points_goal) next_result = RESULT_P1;
        else if (next_points_p2 >= points_goal) next_result = RESULT_P2;
        else if ((next_lives_p1 == 0) && (next_lives_p2 == 0))
            next_result = higher(next_points_p1, next_points_p2);
        else if (next_lives_p1 == 0) next_result = RESULT_P2;
        else if (next_lives_p2 == 0) next_result = RESULT_P1;
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            points_p1 <= 0; points_p2 <= 0;
            // Idle shows Points 00 and Lives 03, as the model's idle Scoreboard (Hardware Map).
            lives_p1 <= 2'(LIVES_START); lives_p2 <= 2'(LIVES_START);
            points_goal <= 6'd10; result <= RESULT_NONE;
        end else if (new_match) begin
            points_p1 <= 0; points_p2 <= 0;
            lives_p1 <= 2'(LIVES_START); lives_p2 <= 2'(LIVES_START);
            result <= RESULT_NONE;
            case (goal_sel)
                2'd0: points_goal <= 6'd10;
                2'd1: points_goal <= 6'd20;
                2'd2: points_goal <= 6'd30;
                2'd3: points_goal <= 6'd40;
            endcase
        end else if (step_outcome && result == RESULT_NONE) begin
            points_p1 <= next_points_p1; points_p2 <= next_points_p2;
            lives_p1 <= next_lives_p1; lives_p2 <= next_lives_p2;
            result <= next_result;
        end
    end
endmodule
