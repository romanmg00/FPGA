// Owner Alan. PROVISIONAL ports. Destination clk (normally clk_pix).
// Crossing: async_in external single-bit level -> sync_out; NOT an event queue
// or a coherent multi-bit bus crossing. rst must already be synchronous to clk.
module sync_2ff (
    input logic clk, rst, async_in,
    output logic sync_out
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic meta, settled;
    always_ff @(posedge clk) begin
        if (rst) begin
            meta <= 1'b0;
            settled <= 1'b0;
        end else begin
            meta <= async_in;
            settled <= meta;
        end
    end
    assign sync_out = settled;
endmodule
