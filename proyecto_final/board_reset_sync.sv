// Brings the board's reset request into one clock domain (contract section 1).
// Crossing: async_reset (no clock) -> rst (clk). Instantiate one per domain.
// Starts asserted, so each domain also gets a reset right after configuration.
module board_reset_sync (
    input  logic clk,
    input  logic async_reset,
    output logic rst
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic meta = 1'b1, settled = 1'b1;

    always_ff @(posedge clk) begin
        meta    <= async_reset;
        settled <= meta;
    end

    assign rst = settled;
endmodule
