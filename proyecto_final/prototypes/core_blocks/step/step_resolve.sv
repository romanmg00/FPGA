// Owner: Roman (G2). Pure combinational in game domain after READ2, before COMMIT.
// No crossings; caller supplies coherent heads/targets/codes from one Step.
// ALL ports provisional. Cells packed {cy,cx}. slot=3 means no collection.
// No Arena writes/scoring/publication here; COMMIT owner writes crash code 6.
module step_resolve (
    input logic [12:0] head_p1, head_p2, target_p1, target_p2,
    input logic [3:0] code_p1, code_p2,
    output logic [12:0] new_head_p1, new_head_p2,
    output logic crashed_p1, crashed_p2, head_on,
    output logic [1:0] collected_p1, collected_p2
);
    import game_pkg::*;
    logic reward_p1, reward_p2;
    always_comb begin
        reward_p1 = code_p1 >= CELL_REWARD0 && code_p1 <= CELL_REWARD2;
        reward_p2 = code_p2 >= CELL_REWARD0 && code_p2 <= CELL_REWARD2;
        head_on = (target_p1 == target_p2) ||
                  ((target_p1 == head_p2) && (target_p2 == head_p1));
        crashed_p1 = head_on || (code_p1 != CELL_EMPTY && !reward_p1);
        crashed_p2 = head_on || (code_p2 != CELL_EMPTY && !reward_p2);
        new_head_p1 = crashed_p1 ? head_p1 : target_p1;
        new_head_p2 = crashed_p2 ? head_p2 : target_p2;
        collected_p1 = 2'd3;
        collected_p2 = 2'd3;
        if (!crashed_p1 && reward_p1) collected_p1 = code_p1[1:0];
        if (!crashed_p2 && reward_p2) collected_p2 = code_p2[1:0];
    end
endmodule
