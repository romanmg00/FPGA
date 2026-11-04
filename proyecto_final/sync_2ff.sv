// 2-FF synchronizer for one asynchronous, level-type input (contract section 1).
// Crossing: async_in (no clock) -> sync_out (clk). Not for multi-bit buses or
// short pulses: a pulse shorter than one clk period can be missed.
module sync_2ff (
    input  logic clk,
    input  logic rst,
    input  logic async_in,
    output logic sync_out
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic meta = 1'b0, settled = 1'b0;

    always_ff @(posedge clk) begin
        if (rst) begin
            meta    <= 1'b0;
            settled <= 1'b0;
        end else begin
            meta    <= async_in;
            settled <= meta;
        end
    end

    assign sync_out = settled;
endmodule
