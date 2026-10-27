`timescale 1ns/1ps
module uart_sync_2ff #(
    parameter logic reset_value = 1'b1
) (
    input logic clk, rst, async_in,
    output logic sync_out
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic stage1 = reset_value;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic stage2 = reset_value;
    always_ff @(posedge clk) begin
        if (rst) begin stage1 <= reset_value; stage2 <= reset_value; end
        else begin stage1 <= async_in; stage2 <= stage1; end
    end
    assign sync_out = stage2;
endmodule
