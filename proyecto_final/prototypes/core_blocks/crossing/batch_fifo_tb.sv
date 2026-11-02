// batch_fifo_tb: protocol bench for batch_fifo (the qualified crossing's
// input path). Independent of the game: random 9-bit words, a 100 MHz write
// clock and a ~100 kHz read clock with a fractional period, so write edges
// drift across every read-edge phase, including within 1 ns of it.
//
// Checks:
//   F1 the reader receives exactly the accepted words, in order, once each;
//   F2 rdata is 0 whenever rvalid is low;
//   F3 latency: a word whose pointer update is at time tw is presented at
//      max(e1 + 2 + RD_REG, previous + 1), e1 the first read edge after tw;
//      steady state (one write a few cycles after each read edge n) presents
//      it at n + 3 + RD_REG (n + 4 by default, the model's crossing="qualified");
//   F4 each write-pointer update changes exactly one Gray bit;
//   F5 a burst beyond the free space sets overflow and drops only the
//      words that did not fit.
module batch_fifo_tb;
    parameter integer TICKS_A = 2000;         // steady state: write 3..6 cycles after each read edge
    parameter integer TICKS_B = 4000;         // one write per tick at a random offset
    parameter bit RD_REG = 1'b1;
    localparam real RHALF = 5003.3, TR = 2.0 * RHALF;

    logic wclk = 0, rclk = 0, wrst = 1, rrst = 1, wen = 0;
    logic [8:0] wdata = 0, rdata;
    logic rvalid, overflow;
    always #5 wclk = !wclk;
    always #(RHALF) rclk = !rclk;

    batch_fifo #(.W(9), .AW(3), .RD_REG(RD_REG)) dut (.wclk, .wrst, .wen, .wdata, .overflow, .rclk, .rrst, .rdata, .rvalid);

    integer errors = 0;
    task automatic fail(input string what);
        errors++;
        if (errors <= 20) $error("%s", what);
    endtask
    function automatic integer edge_index(input real t);      // read posedge m is at RHALF + m * TR
        return $rtoi((t - RHALF) / TR + 0.5);
    endfunction
    function automatic integer next_edge(input real t);
        return $rtoi($floor((t - RHALF) / TR)) + 1;
    endfunction

    // --- write side monitor: accepted words and their expected read edge ----
    logic [8:0] exp_data [$];
    integer exp_edge [$];
    integer last_expected = -1, accepted = 0, dropped = 0, near_edge = 0, steady_n3 = 0;
    logic [3:0] prev_wgray = 0;
    bit phase_a = 1;
    always @(posedge wclk) if (!wrst) begin
        if (wen) begin
            if (!dut.full) begin
                automatic real tn = RHALF + next_edge($realtime) * TR;
                automatic integer e = next_edge($realtime) + 2 + RD_REG;
                if (e <= last_expected) e = last_expected + 1;
                exp_data.push_back(wdata);
                exp_edge.push_back(e);
                last_expected = e;
                accepted++;
                if (tn - $realtime < 1.0 || $realtime - (tn - TR) <= 1.0) near_edge++;
            end else dropped++;
        end
        #1;
        if ($countones(dut.wgray ^ prev_wgray) > 1) fail("write pointer changed more than one Gray bit");
        prev_wgray = dut.wgray;
    end

    // --- read side checks (pre-edge values) ---------------------------------
    integer reads = 0;
    always @(posedge rclk) if (!rrst) begin
        automatic integer e = edge_index($realtime);
        if (rvalid) begin
            if (exp_data.size() == 0) fail($sformatf("edge %0d: read with nothing accepted", e));
            else begin
                if (rdata !== exp_data[0]) fail($sformatf("edge %0d: read %h, expected %h", e, rdata, exp_data[0]));
                if (e != exp_edge[0]) fail($sformatf("edge %0d: word %h read, expected at edge %0d", e, rdata, exp_edge[0]));
                void'(exp_data.pop_front());
                void'(exp_edge.pop_front());
                reads++;
            end
        end else begin
            if (rdata !== 9'd0) fail($sformatf("edge %0d: rdata %h while empty", e, rdata));
            if (exp_edge.size() != 0 && exp_edge[0] <= e)
                fail($sformatf("edge %0d: word %h due at %0d not presented", e, exp_data[0], exp_edge[0]));
        end
    end

    task automatic write_one(input logic [8:0] d);
        @(posedge wclk) begin wen <= 1; wdata <= d; end
        @(posedge wclk) wen <= 0;
    endtask

    integer write_edge;
    initial begin
        repeat (3) @(posedge rclk);
        @(negedge wclk) wrst = 0;
        @(negedge rclk) rrst = 0;
        // Phase A: as fast_core's batch_wr, a few cycles after each read edge.
        for (int n = 0; n < TICKS_A; n++) begin
            @(posedge rclk);
            write_edge = edge_index($realtime);
            repeat ($urandom_range(3, 1)) @(posedge wclk);
            write_one($urandom);
            #2;                                // after the monitor has recorded the write
            if (exp_edge[$] == write_edge + 3 + RD_REG) steady_n3++;
            else fail($sformatf("phase A: write after edge %0d expected at %0d", write_edge, exp_edge[$]));
        end
        // Phase B: one write per tick, at a random offset on even ticks and, on
        // odd ticks, on the write edge nearest the next read edge (either side).
        phase_a = 0;
        for (int n = 0; n < TICKS_B; n++) begin
            @(posedge rclk);
            if (n % 2 == 0) begin
                #($urandom_range(1000) * TR / 1001.0);
                write_one($urandom);
            end else begin
                automatic real tn = $realtime + TR;
                automatic real tw = 5.0 + 10.0 * $floor((tn - 5.0) / 10.0 + 0.5);  // nearest wclk posedge
                #(tw - 15.0 - $realtime);      // a negedge; write_one samples wen at tw
                write_one($urandom);
            end
        end
        repeat (6) @(posedge rclk);
        if (exp_data.size() != 0) fail($sformatf("%0d words never read", exp_data.size()));
        if (overflow || dropped != 0) fail("overflow before the burst");
        // Phase C: a burst of 12 consecutive writes into 8 entries.
        @(posedge rclk) #20;
        for (int i = 0; i < 12; i++) begin
            @(posedge wclk) begin wen <= 1; wdata <= 9'h100 | i; end
        end
        @(posedge wclk) wen <= 0;
        repeat (17) @(posedge rclk);
        if (!overflow) fail("burst did not set overflow");
        if (dropped != 4) fail($sformatf("burst dropped %0d words, expected 4", dropped));
        if (exp_data.size() != 0) fail($sformatf("%0d burst words never read", exp_data.size()));
        $display("STATS RD_REG=%0d accepted=%0d read=%0d dropped=%0d steady_at_n+3+RD_REG=%0d writes_within_1ns_of_read_edge=%0d",
            RD_REG, accepted, reads, dropped, steady_n3, near_edge);
        if (errors != 0) $fatal(1, "%0d errors", errors);
        $display("PASS batch_fifo_tb");
        $finish;
    end
endmodule
