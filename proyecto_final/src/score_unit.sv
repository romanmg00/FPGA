// Author: Alan (AIF31).
module score_unit (
    input  logic       clk,                    // clk_juego
    input  logic       rst,                    // rst_juego
    input  logic       new_match,             
    input  logic       crash1, crash2,         
    output logic [5:0] points_p1, points_p2,   
    output logic [1:0] lives_p1, lives_p2,     
    output logic [1:0] result,                 // 0 Match on, 1 P1 wins, 2 P2 wins, 3 Draw
    output logic       match_over              
);

    logic [5:0] next_points_p1, next_points_p2;
    logic [1:0] next_lives_p1, next_lives_p2;
    logic [1:0] next_result;

    // The values after this Step: Crashes, then the Survival Bonus, then who won.
    always_comb
    begin
        next_lives_p1  = crash1 ? lives_p1 - 2'd1 : lives_p1;
        next_lives_p2  = crash2 ? lives_p2 - 2'd1 : lives_p2;
        next_points_p1 = (crash2 && !crash1) ? points_p1 + 6'd3 : points_p1;   // Survival Bonus
        next_points_p2 = (crash1 && !crash2) ? points_p2 + 6'd3 : points_p2;
        if (next_lives_p1 == 2'd0 && next_lives_p2 == 2'd0)
        begin
            if (next_points_p1 > next_points_p2)
                next_result = 2'd1;            // P1 wins
            else if (next_points_p2 > next_points_p1)
                next_result = 2'd2;            // P2 wins
            else
                next_result = 2'd3;            // Draw
        end
        else if (next_lives_p1 == 2'd0)
            next_result = 2'd2;                // P2 wins
        else if (next_lives_p2 == 2'd0)
            next_result = 2'd1;                // P1 wins
        else
            next_result = 2'd0;                // the Match goes on
    end

    // Priority: reset or a new Match, then a Crash Step while the Match is on. After a result
    // nothing changes until the next Match, so the final values stay on the Scoreboard.
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
        else if ((crash1 || crash2) && result == 2'd0)
        begin
            points_p1 <= next_points_p1;
            points_p2 <= next_points_p2;
            lives_p1  <= next_lives_p1;
            lives_p2  <= next_lives_p2;
            result    <= next_result;
        end
    end

    assign match_over = (result != 2'd0);

endmodule
