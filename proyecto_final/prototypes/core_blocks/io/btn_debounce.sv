// Owner Alan; exact contract section 4 ports, clk = clk_pix working default.
// Crossing: five asynchronous active-high pins through independent sync_2ff.
// btn_pulse stays in clk; downstream event transfer to clk_juego UNSELECTED.
// PROVISIONAL parameters/timing: 10 ms stable opposite level on both edges.
// 834600 cycles @83.46 MHz rejects short contact bounce without 60-Hz sampling.
module btn_debounce #(
    parameter integer CLK_HZ = 83460000,
    parameter integer DEBOUNCE_MS = 10
) (
    input logic clk,
    input logic rst,
    input logic [4:0] btn,
    output logic [4:0] btn_pulse
);
    import game_pkg::*;
    localparam integer STABLE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COUNT_W = (STABLE_CYCLES > 1) ? $clog2(STABLE_CYCLES) : 1;
    logic [4:0] btn_sync, pressed;
    for (genvar i = 0; i < 5; i = i + 1) begin : buttons
        logic [COUNT_W-1:0] count;
        sync_2ff sync_inst (.clk(clk), .rst(rst), .async_in(btn[i]), .sync_out(btn_sync[i]));
        always_ff @(posedge clk) begin
            if (rst) begin
                count <= '0;
                pressed[i] <= 1'b0;
                btn_pulse[i] <= 1'b0;
            end else begin
                btn_pulse[i] <= 1'b0;
                if (btn_sync[i] == pressed[i]) count <= '0;
                else if (count == STABLE_CYCLES - 1) begin
                    count <= '0;
                    pressed[i] <= btn_sync[i];
                    btn_pulse[i] <= btn_sync[i];
                end else count <= count + 1'b1;
            end
        end
    end
endmodule
