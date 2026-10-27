`timescale 1ns/1ps
module uart_rx #(
    parameter integer clk_hz = 83333333,
    parameter integer baud = 115200
) (
    input logic clk, rst, rx,
    output logic [7:0] rx_byte = 0,
    output logic rx_valid = 0,
    output logic framing_error = 0
);
    localparam integer clocks_per_bit = (clk_hz + baud / 2) / baud;
    localparam integer count_width = $clog2(clocks_per_bit);
    typedef enum logic [2:0] {wait_high, idle, start_bit, data_bits, stop_bit} rx_state;
    rx_state state = wait_high;
    logic [count_width-1:0] count = 2;
    logic [2:0] bit_index = 0;
    logic [7:0] shift_byte = 0;
    always_ff @(posedge clk) begin
        rx_valid <= 0;
        framing_error <= 0;
        if (rst) begin
            state <= wait_high;
            count <= 2;
            bit_index <= 0;
            shift_byte <= 0;
            rx_byte <= 0;
        end else begin
            case (state)
                // Let the two idle-high synchronizer stages refill after reset.
                // Their reset values must not count as observed idle on the pin.
                wait_high: begin
                    if (count != 0) count <= count - 1'b1;
                    else if (rx) state <= idle;
                end
                idle: if (!rx) begin
                    count <= clocks_per_bit / 2 - 1;
                    state <= start_bit;
                end
                start_bit: begin
                    if (count != 0) count <= count - 1'b1;
                    else if (rx) state <= idle;
                    else begin
                        count <= clocks_per_bit - 1;
                        bit_index <= 0;
                        state <= data_bits;
                    end
                end
                data_bits: begin
                    if (count != 0) count <= count - 1'b1;
                    else begin
                        shift_byte[bit_index] <= rx;
                        count <= clocks_per_bit - 1;
                        if (bit_index == 7) state <= stop_bit;
                        else bit_index <= bit_index + 1'b1;
                    end
                end
                stop_bit: begin
                    if (count != 0) count <= count - 1'b1;
                    else if (rx) begin
                        rx_byte <= shift_byte;
                        rx_valid <= 1;
                        state <= idle;
                    end else begin
                        framing_error <= 1;
                        state <= wait_high;
                    end
                end
                default: state <= wait_high;
            endcase
        end
    end
endmodule
