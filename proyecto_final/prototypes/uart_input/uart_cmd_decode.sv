`timescale 1ns/1ps
module uart_cmd_decode (
    input logic clk, rst, rx_valid,
    input logic [7:0] rx_byte,
    output logic [2:0] cmd = 0,
    output logic cmd_valid = 0
);
    always_ff @(posedge clk) begin
        cmd_valid <= 0;
        if (rst) cmd <= 0;
        else if (rx_valid) begin
            cmd_valid <= 1;
            case (rx_byte)
                "w", "W": cmd <= 0;
                "d", "D": cmd <= 1;
                "s", "S": cmd <= 2;
                "a", "A": cmd <= 3;
                8'h20, 8'h0d: cmd <= 4;
                default: cmd_valid <= 0;
            endcase
        end
    end
endmodule
