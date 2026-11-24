// Author: Alan (AIF31).
// Bytes from P2's web page to commands, one bit each, in turn_req2's order: cmd[0] Up (W),
// cmd[1] Right (D), cmd[2] Down (S), cmd[3] Left (A), cmd[4] Start (Space or Enter).
// Enter is sent as one CR byte (ADR 0013). Upper and lower case are both accepted; any other
// byte, LF included, is not a command and gives 0.
module uart_decode (
    input  logic [7:0] rx_byte,     // from uart_rx
    output logic [4:0] cmd
);

    always_comb
    begin
        case (rx_byte)
            8'h77:   cmd = 5'b00001;    // w: Up
            8'h57:   cmd = 5'b00001;    // W: Up
            8'h64:   cmd = 5'b00010;    // d: Right
            8'h44:   cmd = 5'b00010;    // D: Right
            8'h73:   cmd = 5'b00100;    // s: Down
            8'h53:   cmd = 5'b00100;    // S: Down
            8'h61:   cmd = 5'b01000;    // a: Left
            8'h41:   cmd = 5'b01000;    // A: Left
            8'h20:   cmd = 5'b10000;    // Space: Start
            8'h0D:   cmd = 5'b10000;    // Enter (CR): Start
            default: cmd = 5'b00000;    // not a command
        endcase
    end

endmodule
