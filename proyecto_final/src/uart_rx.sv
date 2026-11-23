// Author: Alan (AIF31).
// UART receiver for P2's web page: 115200 baud, 8N1 (1 start bit, 8 data bits LSB first,
// 1 stop bit, no parity), on clk_pix. One bit lasts 83,455,882 / 115,200 = 724.4 cycles of
// clk_pix, so this counts 724 per bit. Each bit is read once, in its middle: the start bit
// 362 cycles after its falling edge, then every 724 cycles. A start bit that is high again at
// its middle was a glitch and is ignored; a byte whose stop bit is low is dropped. A start bit
// must begin with a fall from high, so a line held low (a break, or after a framing error)
// gives no bytes until it goes high again.
module uart_rx (
    input  logic       clk,         // clk_pix
    input  logic       rst,         // rst_pix
    input  logic       rx,          // uart_rx pin after sync_2ff; high when idle
    output logic [7:0] rx_byte,     // the last byte received
    output logic       rx_valid     // 1 for one cycle when rx_byte is a new byte
);

    logic [1:0] state;              // 0 idle, 1 start bit, 2 data bits, 3 stop bit
    logic [9:0] count;              // cycles left until the middle of the bit
    logic [2:0] bit_num;            // data bit being read, 0-7
    logic [7:0] data;               // data bits read so far, shifted in from the left
    logic       rx_last;            // rx one cycle earlier, to find the fall of a start bit

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
                2'd0: begin                         // idle: wait for a start bit
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
                        data    <= {rx, data[7:1]}; // LSB first: after 8 bits, bit 0 is data[0]
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
