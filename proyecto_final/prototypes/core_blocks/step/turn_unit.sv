// Owner: Roman (G1). Provisional ports, game-domain clk; no CDC inside.
// axes: v_valid/v_down (UP=0, DOWN=1), h_valid/h_left (RIGHT=0, LEFT=1).
// Upstream owns ordering/ties, arrival eligibility and coherent input crossing.
// rst > load > clock(axes,apply,launch); apply precedes launch on the same edge.
module turn_unit (
    input logic clk, rst, load,
    input logic [1:0] load_heading,
    input logic v_valid, v_down, h_valid, h_left, apply, launch,
    output logic [1:0] heading, pending
);
    import game_pkg::*;
    logic [1:0] pending_next;
    always_comb begin
        pending_next = pending;
        if (apply) begin
            if (!heading[0] && h_valid)
                pending_next = h_left ? DIR_LEFT : DIR_RIGHT;
            if (heading[0] && v_valid)
                pending_next = v_down ? DIR_DOWN : DIR_UP;
        end
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            heading <= DIR_RIGHT;
            pending <= DIR_RIGHT;
        end else if (load) begin
            heading <= load_heading;
            pending <= load_heading;
        end else begin
            pending <= pending_next;
            if (launch) heading <= pending_next;
        end
    end
endmodule
