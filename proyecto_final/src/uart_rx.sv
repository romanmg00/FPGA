// Author: Alan (AIF31).
// UART receiver for P2's web page on clk_pix: 115200 baud, 8N1, LSB first.
// 724 cycles per bit (83,455,882 / 115,200 = 724.4), read once in its middle.
module uart_rx (
    input  logic       clk,         // clk_pix
    input  logic       rst,         // rst_pix
    input  logic       rx,          // after sync_2ff; high when idle
    output logic [7:0] rx_byte,
    output logic       rx_valid     // 1 cycle per new byte
);

    logic [1:0] state;              // 0 idle, 1 start bit, 2 data bits, 3 stop bit
    logic [9:0] count;              // cycles to the middle of the bit
    logic [2:0] bit_num;
    logic [7:0] data;               // shifted in from the left
    logic       rx_last;

    always_ff @(posedge clk) begin
        rx_valid <= 1'b0;
        rx_last  <= rx;
        if (rst) begin
            rx_last <= 1'b0;                // after a reset, rx must be high before a start bit
            state   <= 2'd0;
            count   <= 10'd0;
            bit_num <= 3'd0;
            rx_byte <= 8'd0;
        end else begin
            case (state)
                2'd0: begin                         // idle
                    if (rx_last && !rx) begin
                        count <= 10'd361;           // half a bit: the middle of the start bit
                        state <= 2'd1;
                    end
                end
                2'd1: begin                         // start bit
                    if (count != 10'd0)
                        count <= count - 1'b1;
                    else if (rx)
                        state <= 2'd0;              // high again: a glitch, not a start bit
                    else begin
                        count   <= 10'd723;         // a whole bit: the middle of data bit 0
                        bit_num <= 3'd0;
                        state   <= 2'd2;
                    end
                end
                2'd2: begin                         // data bits
                    if (count != 10'd0)
                        count <= count - 1'b1;
                    else begin
                        data    <= {rx, data[7:1]}; // LSB first
                        count   <= 10'd723;
                        bit_num <= bit_num + 1'b1;
                        if (bit_num == 3'd7)
                            state <= 2'd3;
                    end
                end
                2'd3: begin                         // stop bit
                    if (count != 10'd0)
                        count <= count - 1'b1;
                    else begin
                        if (rx) begin               // a low stop bit is a framing error: drop the byte
                            rx_byte  <= data;
                            rx_valid <= 1'b1;
                        end
                        state <= 2'd0;
                    end
                end
            endcase
        end
    end

endmodule
