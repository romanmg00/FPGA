`timescale 1ns/1ps
module uart_input_path_tb;
    parameter integer clk_hz = 83333333;
    parameter integer real_ratio = 0;
    localparam real clk_period = 1.0e9 / clk_hz;
    localparam real bit_period = 1.0e9 / 115200;
    localparam real game_period = real_ratio ? 1.0e9 / 60 : 100003.7;
    logic clk_pix = 0, clk_game = 0;
    logic rst_pix = 1, rst_game = 1, uart_rx_pin = 1, consume = 1;
    logic [2:0] event_cmd;
    logic event_valid, overflow, framing_error, full, ready;
    logic [2:0] expected [0:255];
    integer expected_count = 0, received_count = 0;
    integer previous_received;
    time first_sent, first_received;

    always #(clk_period / 2) clk_pix = ~clk_pix;
    initial begin #123.7; forever #(game_period / 2) clk_game = ~clk_game; end
    uart_input_path #(.clk_hz(clk_hz)) dut (.*);
    always @(posedge clk_game) begin
        #0.001;
        if (event_valid && !rst_game) begin
            if (received_count >= expected_count || event_cmd !== expected[received_count])
                $fatal(1, "path event %0d got %0d expected %0d of %0d", received_count,
                       event_cmd, expected[received_count], expected_count);
            if (received_count == 0) first_received = $time;
            received_count++;
        end
    end

    task automatic send(input logic [7:0] value);
        uart_rx_pin = 0; #(bit_period);
        for (integer b = 0; b < 8; b++) begin
            uart_rx_pin = value[b]; #(bit_period);
        end
        uart_rx_pin = 1; #(bit_period);
    endtask
    task automatic expect_event(input logic [2:0] value);
        expected[expected_count] = value; expected_count++;
    endtask
    task automatic reset_path;
        @(negedge clk_pix); rst_pix = 1;
        @(negedge clk_game); rst_game = 1;
        repeat (4) @(negedge clk_game);
        expected_count = 0; received_count = 0;
        @(negedge clk_pix); rst_pix = 0;
        repeat (2) @(negedge clk_game);
        rst_game = 0;
        wait (ready);
        #(bit_period * 2);
    endtask
    initial begin
        reset_path();
        first_sent = $time;
        expect_event(0); send("w");
        expect_event(3); send("a");
        expect_event(0); send("W");
        expect_event(1); send("D");
        expect_event(2); send("s");
        expect_event(4); send(8'h0d);
        send(8'h0a); send(8'hff); // ignored
        expect_event(4); send(" ");
        repeat (12) @(negedge clk_game);
        if (received_count != 7 || overflow) $fatal(1, "path delivery count/overflow");
        $display("PATH_ORDER real_ratio=%0d commands=7 first_latency_ns=%0d PASS",
                 real_ratio, first_received-first_sent);
        // Hold service, fill exactly 64, reject newer bytes, then resume in order.
        @(negedge clk_game); consume = 0;
        for (integer i = 0; i < 64; i++) begin
            expect_event(i % 2 == 0 ? 0 : 3);
            send(i % 2 == 0 ? "w" : "a");
        end
        #(bit_period);
        if (!full || overflow) $fatal(1, "full boundary incorrect");
        send(" "); #(bit_period);
        if (!overflow) $fatal(1, "overflow not observed");
        if (real_ratio) begin
            // Real-ratio test resets full storage rather than simulating a 1s drain.
            reset_path();
            expect_event(1); send("d");
            @(negedge clk_game); consume = 1;
            repeat (8) @(negedge clk_game);
            if (received_count != 1 || overflow) $fatal(1, "full/reset recovery");
        end else begin
            @(negedge clk_game); consume = 1;
            repeat (72) @(negedge clk_game);
            if (received_count != 71) $fatal(1, "full drain lost data");
            reset_path();
            expect_event(4); send(8'h0d);
            repeat (8) @(negedge clk_game);
            if (received_count != 1 || overflow) $fatal(1, "reset recovery");
        end
        $display("PASS uart_input_path_tb real_ratio=%0d clk_hz=%0d", real_ratio, clk_hz);
        $finish;
    end
    initial begin #1.0e9; $fatal(1, "path watchdog"); end
endmodule
