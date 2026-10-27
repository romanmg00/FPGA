`timescale 1ns/1ps
module uart_async_fifo_tb;
    logic wr_clk = 0, rd_clk = 0;
    logic wr_rst = 1, rd_rst = 1;
    logic wr_en = 0, rd_en = 0;
    logic [2:0] wr_data = 0, rd_data;
    logic full, empty, wr_ready, rd_ready, rd_valid, overflow;
    logic [2:0] reference_data [0:65535];
    integer writes = 0, reads = 0, rejected = 0;
    integer total_writes = 0, total_reads = 0;
    integer rng = 32'h256cafe;
    logic previous_wr_gray_valid = 0;
    logic [6:0] previous_wr_gray;
    logic [6:0] gray_delta;

    always #5.3 wr_clk = ~wr_clk;
    initial begin #1.1; forever #8.7 rd_clk = ~rd_clk; end
    uart_async_fifo dut (.*);

    function automatic integer random_next;
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng & 32'h7fffffff;
    endfunction

    always @(posedge wr_clk) begin
        if (wr_rst) begin writes = 0; previous_wr_gray_valid = 0; end
        else begin
            if (wr_en && wr_ready && !full) begin
                reference_data[writes] = wr_data;
                writes++; total_writes++;
            end
            if (wr_en && wr_ready && full) rejected++;
            #0.001;
            gray_delta = dut.wr_gray ^ previous_wr_gray;
            // Icarus 12.0 mis-evaluates $onehot0(a ^ b) for a=b=0;
            // use a direct zero-or-power-of-two check, rejecting X as well.
            if (previous_wr_gray_valid && ((gray_delta & (gray_delta - 1'b1)) !== 7'd0))
                $fatal(1, "write Gray pointer changed multiple bits previous=%b current=%b",
                       previous_wr_gray, dut.wr_gray);
            previous_wr_gray = dut.wr_gray;
            previous_wr_gray_valid = 1;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_rst) reads = 0;
        else begin
            #0.001;
            if (rd_valid) begin
                if (reads >= writes || rd_data !== reference_data[reads])
                    $fatal(1, "FIFO reordered/duplicated read %0d of %0d: %h != %h",
                           reads, writes, rd_data, reference_data[reads]);
                reads++; total_reads++;
            end
        end
    end

    task automatic reset_both(input bit write_first);
        @(negedge wr_clk); wr_en = 0; wr_rst = 1;
        @(negedge rd_clk); rd_en = 0; rd_rst = 1;
        repeat (5) @(negedge rd_clk);
        if (write_first) begin
            @(negedge wr_clk); wr_rst = 0;
            repeat (8) @(negedge wr_clk);
            if (wr_ready) $fatal(1, "write side ready before peer release");
            @(negedge rd_clk); rd_rst = 0;
        end else begin
            @(negedge rd_clk); rd_rst = 0;
            repeat (8) @(negedge rd_clk);
            if (rd_ready) $fatal(1, "read side ready before peer release");
            @(negedge wr_clk); wr_rst = 0;
        end
        wait (wr_ready && rd_ready);
        repeat (4) @(negedge rd_clk);
        if (!empty || full || overflow || rd_valid) $fatal(1, "bad reset state");
    endtask

    task automatic drain;
        @(negedge wr_clk); wr_en = 0;
        @(negedge rd_clk); rd_en = 1;
        repeat (100) @(negedge rd_clk);
        if (!empty || writes != reads) $fatal(1, "drain mismatch %0d/%0d", reads, writes);
        @(negedge rd_clk); rd_en = 0;
    endtask

    initial begin
        reset_both(1);
        // Full capacity, rejected writes, and no overwrite of unread commands.
        for (integer i = 0; i < 80; i++) begin
            @(negedge wr_clk); wr_en = 1; wr_data = i % 5;
        end
        @(negedge wr_clk); wr_en = 0;
        if (!full || !overflow || writes != 64 || rejected != 16)
            $fatal(1, "capacity/full error writes=%0d rejected=%0d", writes, rejected);
        drain();
        if (!overflow) $fatal(1, "overflow was not sticky");
        $display("FIFO_FULL capacity=64 rejected=16 ordered drain PASS");
        // Many wraps and randomized independent read/write service.
        fork
            begin
                for (integer i = 0; i < 12000; i++) begin
                    @(negedge wr_clk); wr_en = random_next() % 4 != 0;
                    wr_data = random_next() % 5;
                end
                @(negedge wr_clk); wr_en = 0;
            end
            begin
                for (integer i = 0; i < 7400; i++) begin
                    @(negedge rd_clk); rd_en = random_next() % 5 != 0;
                end
                @(negedge rd_clk); rd_en = 0;
            end
        join
        drain();
        // Reset nonempty/full storage and release in the opposite order.
        for (integer epoch = 0; epoch < 4; epoch++) begin
            @(negedge wr_clk); wr_en = 1; wr_data = 4;
            repeat (70) @(negedge wr_clk);
            reset_both(epoch % 2 == 0);
            @(negedge rd_clk); rd_en = 1;
            repeat (10) @(negedge rd_clk);
            if (rd_valid || reads != 0) $fatal(1, "ghost command after reset");
            @(negedge rd_clk); rd_en = 0;
            @(negedge wr_clk); wr_en = 1; wr_data = epoch;
            @(negedge wr_clk); wr_en = 0;
            drain();
        end
        $display("PASS uart_async_fifo_tb accepted=%0d read=%0d rejected=%0d seed=0x0256cafe",
                 total_writes, total_reads, rejected);
        $finish;
    end
    initial begin #1000000; $fatal(1, "FIFO watchdog"); end
endmodule
