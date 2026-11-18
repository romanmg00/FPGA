// Author: Alan (AIF31).
// Self-checking bench for seg7_link: clk_juego and clk_pix run unrelated, with several periods
// and phases and then the real ratio. Every tick's 20 bits must reach clk_pix whole and in
// order, one copy per tick, and the output must not change between copies.
`timescale 1ns/1ps
module seg7_link_tb;

    logic       clk_juego = 1'b0, clk_pix = 1'b0;
    logic [5:0] points_p1 = 6'd0, points_p2 = 6'd0;
    logic [1:0] lives_p1 = 2'd0, lives_p2 = 2'd0, view = 2'd0, goal_sel = 2'd0;
    logic [5:0] points_p1_pix, points_p2_pix;
    logic [1:0] lives_p1_pix, lives_p2_pix, view_pix, goal_sel_pix;

    seg7_link dut (
        .clk_juego, .points_p1, .points_p2, .lives_p1, .lives_p2, .view, .goal_sel,
        .clk_pix, .points_p1_pix, .points_p2_pix, .lives_p1_pix, .lives_p2_pix, .view_pix,
        .goal_sel_pix
    );

    localparam real PIX_NS = 11.982;          // clk_pix period (83.46 MHz)
    always #(PIX_NS / 2) clk_pix = ~clk_pix;

    logic [19:0] sent [$];                    // the values of each tick, in order
    int          copies = 0;                  // copies seen on clk_pix

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "seg7_link_tb failed");
    endfunction

    function automatic logic [19:0] bundle_in();
        return {points_p1, points_p2, lives_p1, lives_p2, view, goal_sel};
    endfunction
    function automatic logic [19:0] bundle_out();
        return {points_p1_pix, points_p2_pix, lives_p1_pix, lives_p2_pix, view_pix, goal_sel_pix};
    endfunction

    // Every clk_pix edge: on a copy (new_tick, the synchronized toggle changed) the output must
    // be the next tick's values; on any other edge it must not change.
    always @(posedge clk_pix) begin
        logic        copy;
        logic [19:0] last_out;
        copy   = dut.new_tick;
        last_out = bundle_out();
        #0.001;
        if (copy) begin
            if (copies >= sent.size())
                fail($sformatf("copy %0d with only %0d ticks sent", copies + 1, sent.size()));
            if (bundle_out() !== sent[copies])
                fail($sformatf("copy %0d gave %h, the tick sent %h", copies + 1, bundle_out(), sent[copies]));
            copies++;
        end
        else if (bundle_out() !== last_out)
            fail($sformatf("the output changed from %h to %h without a copy", last_out, bundle_out()));
    end

    // New values on clk_juego, as score_unit, seg7_view and the switches change them.
    task automatic new_values(int pattern, int i);
        logic [19:0] v;
        case (pattern)
            0: v = 20'($urandom);
            1: v = (i % 2) ? 20'hFFFFF : 20'h00000;    // every bit changes on every tick
            default: v = 20'(i);                       // a count: shows a lost or repeated tick
        endcase
        {points_p1, points_p2, lives_p1, lives_p2, view, goal_sel} = v;
    endtask

    // n ticks of clk_juego with this period, starting after a phase offset. The values change
    // after the falling edge and are recorded at the rising edge, where seg7_link loads them.
    task automatic run(string name, real period_ns, real offset_ns, int n, int pattern);
        int first = sent.size();
        #(offset_ns);
        for (int i = 0; i < n; i++) begin
            sent.push_back(bundle_in());
            clk_juego = 1'b1;
            #(period_ns / 2);
            clk_juego = 1'b0;
            new_values(pattern, i);
            #(period_ns / 2);
        end
        #(10 * PIX_NS);
        if (copies != sent.size())
            fail($sformatf("%s: %0d ticks sent, %0d copies", name, sent.size(), copies));
        $display("ok   %s: %0d ticks, each copied once, whole and in order", name, sent.size() - first);
    endtask

    initial begin
        #(3 * PIX_NS);
        if (copies != 0) fail("a copy before any tick");

        // clk_juego periods of 6.53, 9.37 and 31.77 clk_pix cycles, at unrelated phases.
        run("random values, 6.53 cycles",   6.53 * PIX_NS, 0.0,  400, 0);
        run("random values, 9.37 cycles",   9.37 * PIX_NS, 3.1,  400, 0);
        run("all bits flip, 9.37 cycles",   9.37 * PIX_NS, 7.7,  200, 1);
        run("tick count, 31.77 cycles",    31.77 * PIX_NS, 1.9,  300, 2);

        // The real ratio: clk_juego = clk_pix / 1,390,932 (N = 695,466, ADR 0006).
        run("real ratio, 1,390,932 cycles", 1390932.0 * PIX_NS, 4.4, 3, 0);

        $display("PASS seg7_link_tb");
        $finish;
    end

endmodule
