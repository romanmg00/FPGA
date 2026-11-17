// Carries the drawn bike positions and headings from clk_juego to clk_pix (X1, issue #30).
// clk_juego side: pos_tgl flips on every clk_juego tick (bike_glide may change the values on
// any tick, and copying unchanged values is harmless).
// clk_pix side: pos_tgl goes through sync_2ff; when it changes, the values are copied to
// "pending"; at curr_y == 800 (vertical blanking) pending moves to the registers drawcon reads,
// so a whole frame is drawn with the same positions (no tearing).
module pos_link (
    // clk_juego side
    input  logic        clk_juego,
    input  logic        rst_juego,
    input  logic [10:0] glide1_x, glide1_y,        // bike_glide: drawn position of bike 1
    input  logic [10:0] glide2_x, glide2_y,        // bike_glide: drawn position of bike 2
    input  logic [1:0]  heading1, heading2,        // position_logic: bike directions

    // clk_pix side
    input  logic        clk_pix,
    input  logic        rst_pix,
    input  logic [10:0] curr_y,                    // vga_out: current row
    output logic [10:0] draw1_x, draw1_y,          // -> drawcon: position of bike 1 for this frame
    output logic [10:0] draw2_x, draw2_y,          // -> drawcon: position of bike 2 for this frame
    output logic [1:0]  draw_heading1, draw_heading2 // -> drawcon: directions for this frame
);

    // ---------------------------------------------------------------
    // 1. clk_juego side: the toggle
    // ---------------------------------------------------------------
    logic pos_tgl;                                  // flips every clk_juego tick
    always_ff @(posedge clk_juego) begin
        if(rst_juego)
            pos_tgl <= 1'b0;
        else
            pos_tgl <= ~pos_tgl;
    end

    // ---------------------------------------------------------------
    // 2. Crossing: pos_tgl -> clk_pix
    // ---------------------------------------------------------------
    logic tgl_sync;                                 // pos_tgl after sync_2ff (clk_pix)
    sync_2ff u_sync_2ff (
        .clk(clk_pix),
        .rst(rst_pix),
        .async_in(pos_tgl),
        .sync_out(tgl_sync)
    );

    // ---------------------------------------------------------------
    // 3. clk_pix side: detect the change
    // ---------------------------------------------------------------
    logic tgl_prev;                                 // tgl_sync one clk_pix cycle ago
    logic new_values;                               // 1 for one cycle when tgl_sync changed

    always_ff @(posedge clk_pix) begin
        if(rst_pix)
            tgl_prev <= 1'b0;
        else
            tgl_prev <= tgl_sync;
    end
    assign new_values = tgl_sync ^ tgl_prev;


    // ---------------------------------------------------------------
    // 4. clk_pix side: pending copy
    // ---------------------------------------------------------------
    logic [10:0] pend1_x, pend1_y, pend2_x, pend2_y;
    logic [1:0]  pend_heading1, pend_heading2;

    always_ff @(posedge clk_pix) begin
        if(new_values) begin
            pend1_x <= glide1_x;
            pend1_y <= glide1_y;
            pend2_x <= glide2_x;
            pend2_y <= glide2_y;
            pend_heading1 <= heading1;
            pend_heading2 <= heading2;
        end
    end

    // ---------------------------------------------------------------
    // 5. clk_pix side: values for this frame
    // ---------------------------------------------------------------
    always_ff @(posedge clk_pix) begin
        if(rst_pix) begin
            draw1_x <= 11'b0;
            draw1_y <= 11'b0;
            draw2_x <= 11'b0;
            draw2_y <= 11'b0;
            draw_heading1 <= 2'b0;
            draw_heading2 <= 2'b0;
        end
        else if(curr_y == 800) begin                // first row after the 800 visible rows (vertical blanking)
            draw1_x <= pend1_x;
            draw1_y <= pend1_y;
            draw2_x <= pend2_x;
            draw2_y <= pend2_y;
            draw_heading1 <= pend_heading1;
            draw_heading2 <= pend_heading2;
        end
    end

endmodule
