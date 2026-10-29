// Owner: Roman. Provisional feasibility block, not an accepted interface.
// clk_base is the second Wizard output; rst is synchronous active-high there.
// clk_juego is a generated clock, not a CDC data path. No other crossings.
// Hold rst low in normal operation, including CPU reset/Pause; reset consumers
// separately so the clock needed by their synchronous resets keeps running.
module game_clk_div #(
    parameter integer input_hz = 4687500,
    parameter integer target_hz = 60,
    parameter integer half_cycles = (input_hz + target_hz)/(2*target_hz)
) (
    input logic clk_base,
    input logic rst,
    output logic clk_juego
);
    localparam integer count_width = (half_cycles > 1) ? $clog2(half_cycles) : 1;
    logic [count_width-1:0] count = '0;
    logic game_toggle = 1'b0;
    always_ff @(posedge clk_base) begin
        if (rst) begin
            count <= '0;
            game_toggle <= 1'b0;
        end else if (count == half_cycles-1) begin
            count <= '0;
            game_toggle <= ~game_toggle;
        end else count <= count + 1'b1;
    end
    // Vivado defines SYNTHESIS. Behavioral simulation needs no vendor library;
    // the synthesis branch uses the actual global clock distribution resource.
`ifdef SYNTHESIS
    BUFG u_game_buf (.I(game_toggle), .O(clk_juego));
`else
    assign clk_juego = game_toggle;
`endif
endmodule
