`timescale 1ns/1ps
// Bring-up wrapper only: command LEDs, no game-state implementation.
module uart_input_board #(
    parameter integer clk_hz = 83333333,
    parameter integer game_half_cycles = 41667,
    parameter integer reset_hold_cycles = 500004
) (
    input logic clk, cpu_resetn, uart_rx_pin,
    output logic [7:0] led
);
    logic clk_input, clk_pix, clk_game_base, clk_game;
    logic cpu_resetn_sync;
    logic reset_hold = 1;
    logic [$clog2(reset_hold_cycles)-1:0] reset_count = 0;
    logic [$clog2(game_half_cycles)-1:0] game_count = 0;
    logic game_toggle = 0;
    logic rst_pix, rst_game;
    logic [2:0] event_cmd;
    logic event_valid, overflow, framing_error, full, ready;
    logic [2:0] last_cmd = 0;
    logic event_toggle = 0, frame_error_sticky = 0;
    // Share one board IBUF; two Wizard-owned IBUFs on E3 conflict in placement.
    // Both Wizards are configured for No_buffer and inherit board_clk.
    IBUF u_board_ibuf (.I(clk), .O(clk_input));
    uart_pixel_clock u_pix_clock (.clk_in1(clk_input), .clk_out1(clk_pix));
    uart_game_clock u_game_clock (.clk_in1(clk_input), .clk_out1(clk_game_base));
    uart_sync_2ff u_button_sync (.clk(clk_game_base), .rst(1'b0),
        .async_in(cpu_resetn), .sync_out(cpu_resetn_sync));
    // Free-running clock: Pause and CPU reset never gate or stop it.
    always_ff @(posedge clk_game_base) begin
        if (game_count == game_half_cycles - 1) begin
            game_count <= 0;
            game_toggle <= ~game_toggle;
        end else game_count <= game_count + 1'b1;
        if (!cpu_resetn_sync) begin
            reset_count <= 0;
            reset_hold <= 1;
        end else if (reset_count != reset_hold_cycles - 1) begin
            reset_count <= reset_count + 1'b1;
            reset_hold <= 1;
        end else reset_hold <= 0;
    end
    BUFG u_game_buf (.I(game_toggle), .O(clk_game));
    uart_sync_2ff u_reset_pix (.clk(clk_pix), .rst(1'b0),
        .async_in(reset_hold), .sync_out(rst_pix));
    uart_sync_2ff u_reset_game (.clk(clk_game), .rst(1'b0),
        .async_in(reset_hold), .sync_out(rst_game));
    uart_input_path #(.clk_hz(clk_hz)) u_path (.*,.consume(1'b1));
    always_ff @(posedge clk_game) begin
        if (rst_game) begin last_cmd <= 0; event_toggle <= 0; end
        else if (event_valid) begin last_cmd <= event_cmd; event_toggle <= ~event_toggle; end
    end
    always_ff @(posedge clk_pix) begin
        if (rst_pix) frame_error_sticky <= 0;
        else if (framing_error) frame_error_sticky <= 1;
    end
    assign led = {full, ready, frame_error_sticky, overflow, event_toggle, last_cmd};
endmodule
