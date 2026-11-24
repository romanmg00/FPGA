// Author: Alan (AIF31).
// Self-checking bench for uart_rx behind sync_2ff, as game_top connects them. A transmitter
// written here sends 8N1 frames at 115200 baud and at 2 % and 3 % slower and faster, from
// several phases of clk_pix, back to back and with gaps. Every byte must come out once, whole
// and in order, with rx_valid high for one cycle. Glitches, framing errors, a break and a
// reset in the middle of a byte must give no byte, and the next byte must still be received.
`timescale 1ns/1ps
module uart_rx_tb;

    localparam real PIX_NS = 11.982;          // clk_pix period (83.46 MHz)
    localparam real BIT_NS = 1.0e9 / 115200;  // 8680.6 ns

    logic       clk = 1'b0, rst = 1'b1;
    logic       line = 1'b1;                  // the uart_rx pin; high when idle
    logic       rx;                           // after sync_2ff
    logic [7:0] rx_byte;
    logic       rx_valid;

    sync_2ff u_sync (.clk, .rst, .async_in(line), .sync_out(rx));
    uart_rx dut (.clk, .rst, .rx, .rx_byte, .rx_valid);

    always #(PIX_NS / 2) clk = ~clk;

    logic [7:0] sent [$];                     // bytes that must come out, in order
    int         received = 0;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "uart_rx_tb failed");
    endfunction

    // Every byte out must be the next one sent; rx_valid never lasts two cycles.
    logic valid_last = 1'b0;
    always @(posedge clk) begin
        #0.001;
        if (rx_valid === 1'b1) begin
            if (valid_last) fail("rx_valid high for two cycles in a row");
            if (sent.size() == 0) fail($sformatf("byte %h received, none expected", rx_byte));
            if (rx_byte !== sent[0])
                fail($sformatf("byte %0d: received %h, sent %h", received + 1, rx_byte, sent[0]));
            void'(sent.pop_front());
            received++;
        end
        valid_last = (rx_valid === 1'b1);
    end

    // One 8N1 frame: start bit, 8 data bits LSB first, stop bit. bit_ns sets the baud rate.
    task automatic send_frame(logic [7:0] data, real bit_ns, logic stop = 1'b1);
        line = 1'b0;
        #(bit_ns);
        for (int i = 0; i < 8; i++) begin
            line = data[i];
            #(bit_ns);
        end
        line = stop;
        #(bit_ns);
        line = 1'b1;
    endtask

    // A frame that must be received.
    task automatic send_byte(logic [7:0] data, real bit_ns);
        sent.push_back(data);
        send_frame(data, bit_ns);
    endtask

    // Waits until every byte sent has come out (at most 2 bit times after the last stop bit).
    task automatic drain(string what);
        #(2 * BIT_NS);
        if (sent.size() != 0) fail($sformatf("%s: %0d bytes not received", what, sent.size()));
    endtask

    initial begin
        logic [7:0] b;
        real        rate;
        real        rates [4] = '{0.97, 0.98, 1.02, 1.03};
        int         total;

        #(5 * PIX_NS);
        rst = 1'b0;
        #(BIT_NS);

        // 1. Every byte value, back to back at the nominal rate.
        for (int v = 0; v < 256; v++) send_byte(8'(v), BIT_NS);
        drain("256 values back to back");
        $display("ok   all 256 byte values, back to back at 115200 baud");

        // 2. Transmitter 2 % and 3 % slower and faster, random bytes back to back, each run
        //    from a new phase of clk_pix, plus the bytes with the most edges and none.
        foreach (rates[r]) begin
            rate = rates[r];
            #($urandom_range(0, 1000) * PIX_NS / 1000.0);
            send_byte(8'h55, BIT_NS / rate);
            send_byte(8'hAA, BIT_NS / rate);
            send_byte(8'h00, BIT_NS / rate);
            send_byte(8'hFF, BIT_NS / rate);
            for (int i = 0; i < 60; i++) send_byte(8'($urandom), BIT_NS / rate);
            drain($sformatf("rate x%0.2f", rate));
            $display("ok   transmitter at %0.0f baud: 64 bytes back to back", 115200 * rate);
        end

        // 3. Gaps of 0 to 3 bits between bytes, and a long idle.
        for (int i = 0; i < 40; i++) begin
            send_byte(8'($urandom), BIT_NS);
            #($urandom_range(0, 3000) * BIT_NS / 1000.0);
        end
        #(30 * BIT_NS);
        drain("bytes with gaps");
        $display("ok   40 bytes with gaps of 0 to 3 bits");

        // 4. Glitches: a low pulse of 0.1 and 0.4 bit is not a start bit.
        total = received;
        line = 1'b0; #(0.1 * BIT_NS); line = 1'b1; #(3 * BIT_NS);
        line = 1'b0; #(0.4 * BIT_NS); line = 1'b1; #(3 * BIT_NS);
        if (received != total) fail("a glitch gave a byte");
        send_byte("w", BIT_NS);
        drain("after the glitches");
        $display("ok   glitches of 0.1 and 0.4 bit give no byte; the next byte is received");

        // 5. Framing error: a low stop bit drops the byte. Then the line stays low one more
        //    bit before going high, and the next byte is received.
        total = received;
        send_frame("d", BIT_NS, 1'b0);
        line = 1'b0; #(BIT_NS); line = 1'b1; #(BIT_NS);
        if (received != total) fail("a frame with a low stop bit gave a byte");
        send_byte("s", BIT_NS);
        drain("after a framing error");
        $display("ok   a frame with a low stop bit gives no byte; the next byte is received");

        // 6. Break: the line low for 3 frames gives no byte.
        total = received;
        line = 1'b0; #(30 * BIT_NS); line = 1'b1; #(2 * BIT_NS);
        if (received != total) fail("a break gave a byte");
        send_byte("a", BIT_NS);
        drain("after a break");
        $display("ok   a break of 3 frames gives no byte; the next byte is received");

        // 7. Reset in the middle of FF's data bits (the line is high): the byte is lost and no
        //    other byte comes out of it; the next byte is received.
        total = received;
        fork
            send_frame(8'hFF, BIT_NS);
            begin
                #(3.3 * BIT_NS); rst = 1'b1;
                #(1.2 * BIT_NS); rst = 1'b0;
            end
        join
        #(2 * BIT_NS);
        if (received != total) fail("a byte cut by a reset came out");
        send_byte(8'h0D, BIT_NS);
        drain("after a reset in a byte");
        $display("ok   a reset inside a byte drops it; the next byte is received");

        // 8. Power-up with the line low: no byte until the line goes high and a frame starts.
        total = received;
        rst = 1'b1; line = 1'b0; #(10 * PIX_NS);
        rst = 1'b0; #(12 * BIT_NS);
        line = 1'b1; #(2 * BIT_NS);
        if (received != total) fail("a line low out of reset gave a byte");
        send_byte(8'h20, BIT_NS);
        drain("after a reset with the line low");
        $display("ok   out of reset with the line low, no byte until a real frame");

        $display("%0d bytes received", received);
        $display("PASS uart_rx_tb");
        $finish;
    end

endmodule
