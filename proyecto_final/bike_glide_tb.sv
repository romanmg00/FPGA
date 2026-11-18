// Author: Alan (AIF31).
// Self-checking bench for bike_glide, with STEPS = 6 and STEPS = 8 side by side. Each clk
// edge is one game tick. pos changes just after an edge, as position_logic's registers do.
// Expected offsets are written from ADR 0010 (16 px over STEPS ticks, rounded), not read
// from the design.
module bike_glide_tb;
    logic clk = 1'b0, rst = 1'b1;
    logic [10:0] px = 11'd320, py = 11'd432;
    logic [10:0] d6x, d6y, d8x, d8y;

    bike_glide #(.STEPS(6)) dut6 (.clk, .rst, .pos_x(px), .pos_y(py), .draw_x(d6x), .draw_y(d6y));
    bike_glide #(.STEPS(8)) dut8 (.clk, .rst, .pos_x(px), .pos_y(py), .draw_x(d8x), .draw_y(d8y));
    always #5 clk = ~clk;

    localparam int OFF6 [0:6] = '{0, 3, 5, 8, 11, 13, 16};
    localparam int OFF8 [0:8] = '{0, 2, 4, 6, 8, 10, 12, 14, 16};

    function automatic void fail(string msg);
        $display("FAIL %s", msg);
        $fatal(1, "bike_glide_tb failed");
    endfunction

    task automatic tick();
        @(posedge clk);
        #1;
    endtask

    task automatic expect6(string what, int x, int y);
        if (d6x !== 11'(x) || d6y !== 11'(y))
            fail($sformatf("STEPS=6 %s: drawn (%0d,%0d), expected (%0d,%0d)", what, d6x, d6y, x, y));
    endtask

    task automatic expect8(string what, int x, int y);
        if (d8x !== 11'(x) || d8y !== 11'(y))
            fail($sformatf("STEPS=8 %s: drawn (%0d,%0d), expected (%0d,%0d)", what, d8x, d8y, x, y));
    endtask

    // One Step of (dx, dy) Cells for the STEPS=6 instance, then the slide tick by tick.
    task automatic step6(string what, int dx, int dy);
        int x0 = px, y0 = py;
        px = 11'(x0 + 16 * dx);
        py = 11'(y0 + 16 * dy);
        expect6({what, ", Step edge"}, x0, y0);  // still the old Cell until the next edge
        for (int t = 1; t <= 6; t++) begin
            tick();
            expect6($sformatf("%s, tick %0d", what, t), x0 + dx * OFF6[t], y0 + dy * OFF6[t]);
        end
    endtask

    initial begin
        repeat (2) tick();
        expect6("in reset", 320, 432);
        expect8("in reset", 320, 432);
        rst = 1'b0;
        repeat (3) tick();
        expect6("standing", 320, 432);

        // Steps right, up, left and down, back to back: the slide never stops between them.
        step6("right", 1, 0);
        step6("right again", 1, 0);
        step6("up", 0, -1);
        step6("left", -1, 0);
        step6("down", 0, 1);
        repeat (4) tick();
        expect6("standing after the Steps", 336, 432);

        // STEPS = 8: 2 px per tick.
        rst = 1'b1; px = 11'd320; py = 11'd432; tick(); tick(); rst = 1'b0; tick();
        px = 11'd336;
        for (int t = 1; t <= 8; t++) begin
            tick();
            expect8($sformatf("right, tick %0d", t), 320 + OFF8[t], 432);
        end

        // A jump of more than one Cell is drawn at once.
        px = 11'd944; py = 11'd432;
        tick();
        expect6("jump to the start", 944, 432);
        expect8("jump to the start", 944, 432);

        // Reset in the middle of a slide shows the current position.
        px = 11'd928; tick(); tick();
        rst = 1'b1; tick();
        expect6("reset mid-slide", 928, 432);
        expect8("reset mid-slide", 928, 432);

        $display("PASS bike_glide_tb");
        $finish;
    end
endmodule
