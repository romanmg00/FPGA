// Owner: Roman (G2). Provisional feasibility wrapper ONLY, fast-domain clk.
// No CDC. Register-in/register-out resolver tests ADR 0003 item 1 fallback;
// does not select the fallback or include BRAM/service/crossing latency.
module step_resolve_reg (
    input logic clk, rst,
    input logic [12:0] head_p1, head_p2, target_p1, target_p2,
    input logic [3:0] code_p1, code_p2,
    output logic [12:0] new_head_p1, new_head_p2,
    output logic crashed_p1, crashed_p2, head_on,
    output logic [1:0] collected_p1, collected_p2
);
    import game_pkg::*;
    logic [12:0] h1, h2, t1, t2, n1, n2;
    logic [3:0] c1, c2;
    logic cr1, cr2, ho;
    logic [1:0] co1, co2;
    step_resolve resolve(h1,h2,t1,t2,c1,c2,n1,n2,cr1,cr2,ho,co1,co2);
    always_ff @(posedge clk) begin
        if (rst) begin
            h1 <= '0; h2 <= '0; t1 <= '0; t2 <= '0; c1 <= '0; c2 <= '0;
            new_head_p1 <= '0; new_head_p2 <= '0;
            crashed_p1 <= 0; crashed_p2 <= 0; head_on <= 0;
            collected_p1 <= 3; collected_p2 <= 3;
        end else begin
            h1 <= head_p1; h2 <= head_p2; t1 <= target_p1; t2 <= target_p2;
            c1 <= code_p1; c2 <= code_p2;
            new_head_p1 <= n1; new_head_p2 <= n2;
            crashed_p1 <= cr1; crashed_p2 <= cr2; head_on <= ho;
            collected_p1 <= co1; collected_p2 <= co2;
        end
    end
endmodule
