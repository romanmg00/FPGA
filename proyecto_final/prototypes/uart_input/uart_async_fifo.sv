`timescale 1ns/1ps
// Experiment contract: coordinated assertion of wr_rst AND rd_rst, both clocks
// free-running; hold reset for >=3 slow edges. One-sided live reset is invalid.
module uart_async_fifo #(
    parameter integer data_width = 3,
    parameter integer address_width = 6
) (
    input logic wr_clk, wr_rst, wr_en,
    input logic [data_width-1:0] wr_data,
    output logic full = 0, wr_ready,
    input logic rd_clk, rd_rst, rd_en,
    output logic [data_width-1:0] rd_data = 0,
    output logic empty = 1, rd_ready, rd_valid = 0,
    output logic overflow = 0
);
    localparam integer depth = 1 << address_width;
    (* ram_style = "distributed" *) logic [data_width-1:0] memory [0:depth-1];
    logic [address_width:0] wr_bin = 0, wr_gray = 0;
    logic [address_width:0] rd_bin = 0, rd_gray = 0;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [address_width:0] rd_gray_sync1 = 0, rd_gray_sync2 = 0;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [address_width:0] wr_gray_sync1 = 0, wr_gray_sync2 = 0;
    logic wr_up = 0, rd_up = 0;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic rd_up_sync1 = 0, rd_up_sync2 = 0;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic wr_up_sync1 = 0, wr_up_sync2 = 0;
    logic [address_width:0] wr_next, wr_gray_next, rd_next, rd_gray_next;

    assign wr_ready = wr_up && rd_up_sync2 && !wr_rst;
    assign rd_ready = rd_up && wr_up_sync2 && !rd_rst;
    assign wr_next = wr_bin + {{address_width{1'b0}}, (wr_en && wr_ready && !full)};
    assign rd_next = rd_bin + {{address_width{1'b0}}, (rd_en && rd_ready && !empty)};
    assign wr_gray_next = (wr_next >> 1) ^ wr_next;
    assign rd_gray_next = (rd_next >> 1) ^ rd_next;

    always_ff @(posedge wr_clk) begin
        if (wr_rst) begin
            wr_bin <= 0; wr_gray <= 0; full <= 0; overflow <= 0;
            rd_gray_sync1 <= 0; rd_gray_sync2 <= 0;
            wr_up <= 0; rd_up_sync1 <= 0; rd_up_sync2 <= 0;
        end else begin
            wr_up <= 1;
            rd_up_sync1 <= rd_up; rd_up_sync2 <= rd_up_sync1;
            rd_gray_sync1 <= rd_gray; rd_gray_sync2 <= rd_gray_sync1;
            if (wr_ready) begin
                wr_bin <= wr_next; wr_gray <= wr_gray_next;
                full <= (wr_gray_next == {~rd_gray_sync2[address_width:address_width-1], rd_gray_sync2[address_width-2:0]});
                if (wr_en && full) overflow <= 1;
            end
        end
    end
    always_ff @(posedge wr_clk) begin
        if (!wr_rst && wr_en && wr_ready && !full)
            memory[wr_bin[address_width-1:0]] <= wr_data;
    end
    always_ff @(posedge rd_clk) begin
        rd_valid <= 0;
        if (rd_rst) begin
            rd_bin <= 0; rd_gray <= 0; empty <= 1; rd_data <= 0;
            wr_gray_sync1 <= 0; wr_gray_sync2 <= 0;
            rd_up <= 0; wr_up_sync1 <= 0; wr_up_sync2 <= 0;
        end else begin
            rd_up <= 1;
            wr_up_sync1 <= wr_up; wr_up_sync2 <= wr_up_sync1;
            wr_gray_sync1 <= wr_gray; wr_gray_sync2 <= wr_gray_sync1;
            if (rd_ready) begin
                rd_bin <= rd_next; rd_gray <= rd_gray_next;
                empty <= (rd_gray_next == wr_gray_sync2);
                if (rd_en && !empty) begin
                    rd_data <= memory[rd_bin[address_width-1:0]];
                    rd_valid <= 1;
                end
            end
        end
    end
endmodule
