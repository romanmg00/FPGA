// Owner: Roman (G1/G2). Pure combinational, no crossings.
// All ports provisional. Packed Cell = {cy[5:0],cx[6:0]}; unsigned wrap.
module next_cell (
    input logic [12:0] head,
    input logic [1:0] heading,
    output logic [12:0] target
);
    import game_pkg::*;
    always_comb begin
        target = head;
        case (heading)
            DIR_UP: target[12:7] = head[12:7] - 6'd1;
            DIR_RIGHT: target[6:0] = head[6:0] + 7'd1;
            DIR_DOWN: target[12:7] = head[12:7] + 6'd1;
            DIR_LEFT: target[6:0] = head[6:0] - 7'd1;
        endcase
    end
endmodule
