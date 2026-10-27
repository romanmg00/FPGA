`timescale 1ns/1ps
module uart_input_path #(
    parameter integer clk_hz = 83333333
) (
    input logic clk_pix, clk_game, rst_pix, rst_game,
    input logic uart_rx_pin, consume,
    output logic [2:0] event_cmd,
    output logic event_valid, overflow, framing_error, full, ready
);
    logic rx_sync, rx_valid, cmd_valid, empty, rd_ready;
    logic [7:0] rx_byte;
    logic [2:0] cmd;
    uart_sync_2ff u_rx_sync (.clk(clk_pix), .rst(rst_pix),
                           .async_in(uart_rx_pin), .sync_out(rx_sync));
    uart_rx #(.clk_hz(clk_hz)) u_rx (.clk(clk_pix), .rst(rst_pix),
        .rx(rx_sync), .rx_byte(rx_byte), .rx_valid(rx_valid), .framing_error(framing_error));
    uart_cmd_decode u_decode (.clk(clk_pix), .rst(rst_pix), .rx_valid(rx_valid),
        .rx_byte(rx_byte), .cmd(cmd), .cmd_valid(cmd_valid));
    uart_async_fifo u_fifo (.wr_clk(clk_pix), .wr_rst(rst_pix), .wr_en(cmd_valid),
        .wr_data(cmd), .full(full), .wr_ready(ready), .rd_clk(clk_game),
        .rd_rst(rst_game), .rd_en(consume), .rd_data(event_cmd), .empty(empty),
        .rd_ready(rd_ready), .rd_valid(event_valid), .overflow(overflow));
endmodule
