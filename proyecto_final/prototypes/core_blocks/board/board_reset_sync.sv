// Alan integration, provisional reset conditioner; external active-high reset
// into each destination independently. Both flops initialize asserted; no
// asynchronous reset pins. CPU reset must be held >= 3 game edges (~50 ms).
module board_reset_sync(input logic clk, async_reset, output logic rst);
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic meta=1, settled=1;
    always_ff @(posedge clk) begin
        meta <= async_reset;
        settled <= meta;
    end
    assign rst=settled;
endmodule
