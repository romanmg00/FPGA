// Author: Alan (AIF31).
// Self-checking bench for uart_decode: all 256 byte values against the command each key of
// P2's web page sends (ADR 0013). Only W A S D in either case, Space and CR are commands.
module uart_decode_tb;

    logic [7:0] rx_byte;
    logic [4:0] cmd;

    uart_decode dut (.rx_byte, .cmd);

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "uart_decode_tb failed");
    endfunction

    // The command for a byte, written from the keys: bit 0 Up, 1 Right, 2 Down, 3 Left, 4 Start.
    function automatic logic [4:0] want(logic [7:0] c);
        if (c == "w" || c == "W") return 5'b00001;
        if (c == "d" || c == "D") return 5'b00010;
        if (c == "s" || c == "S") return 5'b00100;
        if (c == "a" || c == "A") return 5'b01000;
        if (c == " " || c == 8'd13) return 5'b10000;    // Space, Enter as CR
        return 5'b00000;
    endfunction

    initial begin
        int commands = 0;
        for (int v = 0; v < 256; v++) begin
            rx_byte = 8'(v);
            #1;
            if (cmd !== want(rx_byte))
                fail($sformatf("byte %h gives %b, expected %b", rx_byte, cmd, want(rx_byte)));
            if (cmd != 5'b00000) commands++;
        end
        if (commands != 10) fail($sformatf("%0d bytes are commands, expected 10", commands));
        rx_byte = 8'h0A;                                    // LF: a terminal's Enter may add it
        #1;
        if (cmd !== 5'b00000) fail("LF must not be a command");
        $display("ok   256 bytes: W A S D in both cases, Space and CR are commands; LF is not");
        $display("PASS uart_decode_tb");
        $finish;
    end

endmodule
