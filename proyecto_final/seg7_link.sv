// Carries the Scoreboard values from clk_juego to clk_pix, where seg7_driver scans the digits.
// Each tick, clk_juego loads the 20 bits and flips a toggle; clk_pix synchronizes the toggle and
// copies the 20 bits when it sees it change. The bits have then been still for 2-3 clk_pix
// cycles and stay so for the rest of the tick, so they arrive whole (the arena_ctrl answer
// pattern). No reset: the toggle path must not fake or lose a change, and the values follow
// sources that are reset.
module seg7_link (
    input  logic       clk_juego,                   // ~60 Hz
    input  logic [5:0] points_p1, points_p2,        // from score_unit
    input  logic [1:0] lives_p1, lives_p2,          // from score_unit
    input  logic [1:0] view,                        // from seg7_view
    input  logic [1:0] goal_sel,                    // {SW15, SW14} on clk_juego
    input  logic       clk_pix,                     // 83.46 MHz
    output logic [5:0] points_p1_pix, points_p2_pix,
    output logic [1:0] lives_p1_pix, lives_p2_pix,
    output logic [1:0] view_pix,
    output logic [1:0] goal_sel_pix
);

    logic [19:0] send_q = 20'd0;     // clk_juego: the values of this tick
    logic        tgl_q = 1'b0;       // clk_juego: flips every tick; never reset
    logic        tgl_sync;           // clk_pix: tgl_q after sync_2ff
    logic        tgl_seen = 1'b0;    // clk_pix: tgl_sync one cycle earlier; never reset
    logic [19:0] show_q = 20'd0;     // clk_pix: the copy seg7_driver reads

    always_ff @(posedge clk_juego)
    begin
        send_q <= {points_p1, points_p2, lives_p1, lives_p2, view, goal_sel};
        tgl_q  <= ~tgl_q;
    end

    sync_2ff u_sync (.clk(clk_pix), .rst(1'b0), .async_in(tgl_q), .sync_out(tgl_sync));

    // Copy once per toggle change, that is once per tick.
    always_ff @(posedge clk_pix)
    begin
        tgl_seen <= tgl_sync;
        if (tgl_sync != tgl_seen)
            show_q <= send_q;
    end

    assign {points_p1_pix, points_p2_pix, lives_p1_pix, lives_p2_pix, view_pix, goal_sel_pix} = show_q;

endmodule
