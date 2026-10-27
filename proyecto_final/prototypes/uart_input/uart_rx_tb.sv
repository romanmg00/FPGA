`timescale 1ns/1ps
module uart_rx_tb;
    parameter integer clk_hz = 83333333;
    localparam real clk_period = 1.0e9 / clk_hz;
    localparam real bit_period = 1.0e9 / 115200;
    logic clk = 0;
    logic rst = 1;
    logic rx = 1;
    logic rx_sync;
    logic [7:0] rx_byte;
    logic rx_valid, framing_error;
    logic [2:0] cmd;
    logic cmd_valid;
    integer byte_count = 0, command_count = 0, error_count = 0;
    logic [7:0] expected_bytes [0:16383];
    logic [2:0] expected_commands [0:16383];
    integer expected_byte_count = 0, expected_command_count = 0;
    logic previous_valid = 0;
    integer checks = 0;

    always #(clk_period / 2.0) clk = ~clk;
    uart_sync_2ff u_sync (.clk(clk), .rst(rst), .async_in(rx), .sync_out(rx_sync));
    uart_rx #(.clk_hz(clk_hz)) dut (.*,.rx(rx_sync));
    uart_cmd_decode u_decode (.*);

    function automatic integer decode(input logic [7:0] value);
        case (value)
            "w", "W": decode = 0;
            "d", "D": decode = 1;
            "s", "S": decode = 2;
            "a", "A": decode = 3;
            8'h20, 8'h0d: decode = 4;
            default: decode = -1;
        endcase
    endfunction

    task automatic expect_byte(input logic [7:0] value);
        integer decoded;
        expected_bytes[expected_byte_count] = value;
        expected_byte_count++;
        decoded = decode(value);
        if (decoded >= 0) begin
            expected_commands[expected_command_count] = decoded;
            expected_command_count++;
        end
    endtask

    always @(posedge clk) begin
        #0.001;
        if (!rst) begin
            if (rx_valid && previous_valid) $fatal(1, "rx_valid wider than one cycle");
            if (rx_valid) begin
                if (byte_count >= expected_byte_count || rx_byte !== expected_bytes[byte_count])
                    $fatal(1, "byte %0d expected %h got %h", byte_count, expected_bytes[byte_count], rx_byte);
                byte_count++;
            end
            if (cmd_valid) begin
                if (command_count >= expected_command_count || cmd !== expected_commands[command_count])
                    $fatal(1, "command %0d wrong: %0d", command_count, cmd);
                command_count++;
            end
            if (framing_error) error_count++;
        end
        previous_valid = rx_valid;
    end

    task automatic send_frame(input logic [7:0] value, input real period_ns,
                              input bit good_stop);
        rx = 0; #(period_ns);
        for (integer b = 0; b < 8; b++) begin
            rx = value[b]; #(period_ns);
        end
        rx = good_stop; #(period_ns);
    endtask

    task automatic settle;
        #(bit_period * 2);
        if (byte_count != expected_byte_count || command_count != expected_command_count)
            $fatal(1, "missing output bytes %0d/%0d commands %0d/%0d", byte_count,
                   expected_byte_count, command_count, expected_command_count);
        checks++;
    endtask

    initial begin
        #200; @(negedge clk); rst = 0;
        #(bit_period * 2);
        // Every byte checks LSB order, command aliases and rejection of unknowns.
        // Independent TX times; no reference to the DUT's integer counter.
        if (!$test$plusargs("reset_only")) begin
        for (integer rate = -3; rate <= 3; rate++) begin
            if (rate != -1 && rate != 1) begin
                for (integer phase = 0; phase < 4; phase++) begin
                    #(clk_period * (phase + 0.17) / 4);
                    for (integer value = 0; value < 256; value++) begin
                        expect_byte(value);
                        send_frame(value, bit_period / (1.0 + rate / 100.0), 1);
                    end
                    settle();
                    $display("RX_SWEEP rate=%0d%% phase=%0d bytes=256 PASS", rate, phase);
                end
            end
        end
        end
        // Short false start: low does not survive the half-bit confirmation.
        rx = 0; #(bit_period * 0.2); rx = 1; settle();
        // Bad stop followed by sustained break must produce one error, no byte.
        begin
            integer before_errors;
            before_errors = error_count;
            send_frame(8'h77, bit_period, 0);
            #(bit_period * 30);
            if (error_count != before_errors + 1) $fatal(1, "break rearmed or missed framing error");
            rx = 1; #(bit_period * 2);
            expect_byte(8'h0d); send_frame(8'h0d, bit_period, 1); settle();
        end
        // Reset in each part of a frame; suffix remains low until recovery.
        for (integer position = 0; position < 10; position++) begin
            integer errors_before_reset;
            rx = 0; #(bit_period * (position + 0.2));
            @(negedge clk); rst = 1;
            repeat (4) @(negedge clk);
            errors_before_reset = error_count;
            rst = 0; #(bit_period * 12);
            if (error_count != errors_before_reset)
                $fatal(1, "reset idle-high synchronizer artifact rearmed RX while pin stayed low");
            rx = 1; #(bit_period * 2);
            expect_byte(8'h57); send_frame(8'h57, bit_period, 1); settle();
        end
        // A glitch at the data sampling center can change a byte: no majority vote.
        expect_byte(8'h01);
        rx = 0; #(bit_period); // start
        rx = 0; #(bit_period * 0.35); rx = 1; #(bit_period * 0.30);
        rx = 0; #(bit_period * 0.35);
        #(bit_period * 7); rx = 1; #(bit_period); settle();
        $display("PASS uart_rx_tb bytes=%0d commands=%0d checks=%0d framing_errors=%0d clk_hz=%0d",
                 byte_count, command_count, checks, error_count, clk_hz);
        $finish;
    end
    initial begin #1.0e9; $fatal(1, "RX watchdog"); end
endmodule
