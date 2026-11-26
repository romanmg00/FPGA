// Author: Alan (AIF31).
module seg7_link (
    input  logic       clk_juego,                   // ~60 Hz
    input  logic [5:0] points_p1, points_p2,        // from score_unit
    input  logic [1:0] lives_p1, lives_p2,          // from score_unit
    input  logic [1:0] view,                        // from seg7_view
    input  logic [1:0] goal_sel,                    // {SW15, SW14} on clk_juego
    input  logic       waiting_start,               // Bikes at their starts, waiting for Start
    input  logic [1:0] result,                      // from score_unit: 0 Match on, 1 P1 wins, 2 P2 wins, 3 Draw
    input  logic [1:0] crashed,                     // {P2, P1} crashed, until the Crash pause ends
    input  logic       clk_pix,                     // 83.46 MHz
    output logic [5:0] points_p1_pix, points_p2_pix,
    output logic [1:0] lives_p1_pix, lives_p2_pix,
    output logic [1:0] view_pix,
    output logic [1:0] goal_sel_pix,
    output logic       waiting_start_pix,
    output logic [1:0] result_pix,
    output logic [1:0] crashed_pix
);

    logic [24:0] values_juego = 25'd0;      // clk_juego: the values of this tick
    logic        tick_toggle = 1'b0;        // clk_juego: flips every tick; never reset
    logic        tick_toggle_pix;           // clk_pix: tick_toggle after sync_2ff
    logic        tick_toggle_last = 1'b0;   // clk_pix: tick_toggle_pix one cycle earlier; never reset
    logic        new_tick;                  // clk_pix: the toggle changed, a new tick arrived
    logic [24:0] values_pix = 25'd0;        // clk_pix: the copy seg7_driver and hud_layer read

    always_ff @(posedge clk_juego)
    begin
        values_juego <= {points_p1, points_p2, lives_p1, lives_p2, view, goal_sel, waiting_start, result, crashed};
        tick_toggle  <= ~tick_toggle;
    end

    sync_2ff u_sync_toggle (
        .clk(clk_pix), .rst(1'b0), .async_in(tick_toggle), .sync_out(tick_toggle_pix)
    );

    // Copy once per toggle change, that is once per tick.
    assign new_tick = (tick_toggle_pix != tick_toggle_last);

    always_ff @(posedge clk_pix)
    begin
        tick_toggle_last <= tick_toggle_pix;
        if (new_tick)
            values_pix <= values_juego;
    end

    assign {points_p1_pix, points_p2_pix, lives_p1_pix, lives_p2_pix, view_pix, goal_sel_pix,
            waiting_start_pix, result_pix, crashed_pix} = values_pix;

endmodule
