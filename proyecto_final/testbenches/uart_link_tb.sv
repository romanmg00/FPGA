// Author: Alan (AIF31).
// Self-checking bench for uart_link: clk_pix at 83.46 MHz and clk_juego unrelated to it, at
// short periods of 9.37 and 31.77 clk_pix cycles and then the real ratio. Checks (ADR 0013):
// - a command sent while the mailbox is empty reaches clk_juego once, unchanged, for exactly
//   2 ticks, within 4 ticks, and commands keep their order;
// - a command sent while the last one is still in flight is dropped, and nothing else is;
// - a byte that is not a command (cmd = 0), or cmd without cmd_valid, sends nothing and does
//   not block the next command;
// - during rst_juego nothing comes out, and after it the next command goes through.
`timescale 1ns/1ps
module uart_link_tb;

    localparam real PIX_NS = 11.982;          // clk_pix period (83.46 MHz)

    logic       clk_pix = 1'b0, clk_juego = 1'b0, rst_juego = 1'b0;
    logic [4:0] cmd = 5'd0;
    logic       cmd_valid = 1'b0;
    logic [4:0] cmd_juego;

    uart_link dut (.clk_pix, .cmd, .cmd_valid, .clk_juego, .rst_juego, .cmd_juego);

    always #(PIX_NS / 2) clk_pix = ~clk_pix;

    real juego_ns = 9.37 * PIX_NS;            // clk_juego period; changed between parts
    always #(juego_ns / 2) clk_juego = ~clk_juego;

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "uart_link_tb failed");
    endfunction

    int ticks = 0;
    always @(posedge clk_juego) ticks++;

    // Commands the mailbox took (it was empty), with the tick they were sent in.
    logic [4:0] taken [$];
    int         taken_tick [$];
    int         dropped = 0;                  // commands sent while one was in flight
    always @(posedge clk_pix) begin
        if (cmd_valid && cmd != 5'd0) begin
            if (dut.empty) begin
                taken.push_back(cmd);
                taken_tick.push_back(ticks);
            end
            else dropped++;
        end
    end

    // On clk_juego: each run of a non-zero cmd_juego is the next command taken, lasts exactly
    // 2 ticks and starts at most 4 ticks after it was sent. Commands are 3 ticks apart at
    // least, so two runs never touch.
    logic [4:0] out_last = 5'd0;
    int         run_len = 0;
    int         delivered = 0;
    always @(posedge clk_juego) begin
        #0.001;
        if (cmd_juego !== 5'd0 && cmd_juego === out_last) run_len++;
        else begin
            if (out_last !== 5'd0 && run_len != 2)
                fail($sformatf("command %b lasted %0d ticks, expected 2", out_last, run_len));
            if (cmd_juego !== 5'd0) begin
                if (out_last !== 5'd0) fail($sformatf("command %b right after %b", cmd_juego, out_last));
                if (taken.size() == 0) fail($sformatf("command %b out, none taken", cmd_juego));
                if (cmd_juego !== taken[0])
                    fail($sformatf("command %0d out as %b, taken as %b", delivered + 1, cmd_juego, taken[0]));
                if (ticks - taken_tick[0] > 4)
                    fail($sformatf("command %b out %0d ticks after it was sent", cmd_juego, ticks - taken_tick[0]));
                void'(taken.pop_front());
                void'(taken_tick.pop_front());
                delivered++;
            end
            run_len = 1;
        end
        out_last = cmd_juego;
    end

    // One byte from uart_decode: cmd with cmd_valid for one clk_pix cycle.
    task automatic send(logic [4:0] c);
        @(negedge clk_pix);
        cmd = c;
        cmd_valid = 1'b1;
        @(negedge clk_pix);
        cmd_valid = 1'b0;
        cmd = 5'($urandom);                   // cmd without cmd_valid must be ignored
    endtask

    task automatic wait_ticks(int n);
        repeat (n) @(posedge clk_juego);
    endtask

    // Waits until every command taken is out and its 2 ticks are over.
    task automatic drain(string what);
        wait_ticks(6);
        if (taken.size() != 0) fail($sformatf("%s: %0d commands taken but not out", what, taken.size()));
    endtask

    function automatic logic [4:0] one_command();
        return 5'b00001 << $urandom_range(0, 4);
    endfunction

    // n commands, each sent once the last one is out (5 ticks apart): every one must be taken.
    task automatic spaced(string what, int n);
        int dropped_start = dropped;
        for (int i = 0; i < n; i++) begin
            send(one_command());
            wait_ticks(5);
            #($urandom_range(0, 1000) * juego_ns / 1000.0);
        end
        drain(what);
        if (dropped != dropped_start) fail($sformatf("%s: %0d commands dropped", what, dropped - dropped_start));
        $display("ok   %s: %0d commands, each out once for 2 ticks, in order", what, n);
    endtask

    // Bursts: a second command a few clk_pix cycles to 1.9 ticks after the first is dropped
    // (the mailbox stays full for at least 2 ticks).
    task automatic bursts(string what, int n);
        int dropped_start = dropped;
        for (int i = 0; i < n; i++) begin
            send(one_command());
            #($urandom_range(1, 1900) * juego_ns / 1000.0);
            send(one_command());
            wait_ticks(6);
        end
        drain(what);
        if (dropped - dropped_start != n)
            fail($sformatf("%s: %0d of %0d second commands dropped", what, dropped - dropped_start, n));
        $display("ok   %s: the first of each pair out, the second dropped (%0d pairs)", what, n);
    endtask

    initial begin
        int out;

        wait_ticks(4);
        if (cmd_juego !== 5'd0) fail("a command out of power-up");

        // 1. Every command, spaced, at two short periods and at unrelated phases.
        spaced("9.37 cycles", 200);
        juego_ns = 31.77 * PIX_NS;
        wait_ticks(2);
        spaced("31.77 cycles", 200);

        // 2. Bursts: only the first of each pair is taken.
        bursts("31.77 cycles", 100);

        // 3. Bytes that are not commands: nothing out, and the next command is taken at once.
        out = delivered;
        send(5'd0);
        send(5'b00100);
        drain("not a command, then Down");
        if (delivered != out + 1) fail("a byte that is not a command blocked the next one");
        $display("ok   a byte that is not a command sends nothing and blocks nothing");

        // 4. rst_juego: a command sent during it does not come out; the next one does.
        @(negedge clk_juego);
        rst_juego = 1'b1;
        out = delivered;
        send(5'b10000);
        wait_ticks(6);
        if (cmd_juego !== 5'd0) fail("a command out during rst_juego");
        if (taken.size() != 1) fail("the command sent during rst_juego was not taken");
        void'(taken.pop_front());
        void'(taken_tick.pop_front());
        @(negedge clk_juego);
        rst_juego = 1'b0;
        wait_ticks(2);
        if (delivered != out) fail("a command sent during rst_juego came out after it");
        send(5'b01000);
        drain("after rst_juego");
        if (delivered != out + 1) fail("no command out after rst_juego");
        $display("ok   rst_juego: the command sent during it is answered and dropped; the next one goes through");

        // 5. The real ratio: clk_juego = clk_pix / 1,390,932 (N = 695,466, ADR 0006).
        juego_ns = 1390932.0 * PIX_NS;
        wait_ticks(1);
        bursts("real ratio", 1);

        $display("%0d commands out, %0d dropped", delivered, dropped);
        $display("PASS uart_link_tb");
        $finish;
    end

endmodule
