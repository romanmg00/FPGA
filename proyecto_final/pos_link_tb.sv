// Self-checking testbench for pos_link (X1, issue #30).
// clk_pix and clk_juego run with unrelated periods, so the clk_juego edges drift across the
// frame. curr_y comes from a small row counter: ROW_CYC clk_pix cycles per row, 828 rows per
// frame (as vga_out), so one frame is close to one clk_juego period, as on the board.
// Every clk_juego tick drives a new random set of the 6 inputs (48 bits).
// Checks:
//   1. draw* changes only at the end of a clk_pix edge where curr_y was 800 (no tearing).
//   2. Every draw* value is a whole set that the inputs really had (no mixed bits).
//   3. At the end of row 800, draw* is the newest set, or the one before if the newest arrived
//      less than MARGIN clk_pix cycles earlier (the sync_2ff delay).
//   4. One copy into pending per clk_juego tick: rising and falling toggles both count.
//   5. rst_pix clears draw*, and the outputs come back with fresh values after it.
module pos_link_tb;

    localparam int ROW_CYC  = 4;          // clk_pix cycles per row (shortened)
    localparam int ROWS     = 828;        // rows per frame, as vga_out
    localparam int PIX_HALF = 5;          // clk_pix period 10
    localparam int JUE_HALF = 16573;      // clk_juego period 33146, a frame is 33120
    localparam int MARGIN   = 8;          // clk_pix cycles allowed for the crossing
    localparam int TICKS    = 400;        // clk_juego ticks to run

    logic        clk_pix = 1'b0, clk_juego = 1'b0;
    logic        rst_pix, rst_juego;
    logic [10:0] g1x, g1y, g2x, g2y;
    logic [1:0]  h1, h2;
    logic [10:0] curr_y;
    logic [10:0] d1x, d1y, d2x, d2y;
    logic [1:0]  dh1, dh2;

    pos_link dut (
        .clk_juego(clk_juego), .rst_juego(rst_juego),
        .glide1_x(g1x), .glide1_y(g1y), .glide2_x(g2x), .glide2_y(g2y),
        .heading1(h1), .heading2(h2),
        .clk_pix(clk_pix), .rst_pix(rst_pix), .curr_y(curr_y),
        .draw1_x(d1x), .draw1_y(d1y), .draw2_x(d2x), .draw2_y(d2y),
        .draw_heading1(dh1), .draw_heading2(dh2)
    );

    always #PIX_HALF clk_pix   = ~clk_pix;
    always #JUE_HALF clk_juego = ~clk_juego;

    int errores = 0;

    // rst_pix seen by at least one clk_pix edge (the reset is synchronous). Declared before the
    // checks below use it: XSim rejects a use before the declaration (VRFC 10-3380).
    bit rst_seen = 1'b0;
    always @(posedge clk_pix) rst_seen <= rst_pix;
    function automatic void fail(input string msg);
        if (errores < 20) $display("ERROR t=%0t: %s", $time, msg);
        errores++;
    endfunction

    // ---------------------------------------------------------------
    // Fake vga_out: curr_y counts rows of ROW_CYC cycles
    // ---------------------------------------------------------------
    // A plain always, not always_ff: the initial block below also sets curr_y, and XSim rejects
    // an always_ff variable with a second driver (VRFC 10-3818).
    int col = 0;
    always @(posedge clk_pix) begin
        if (col == ROW_CYC - 1) begin
            col    <= 0;
            curr_y <= (curr_y == ROWS - 1) ? 11'd0 : curr_y + 11'd1;
        end else begin
            col <= col + 1;
        end
    end

    // ---------------------------------------------------------------
    // Inputs: a new random set on every clk_juego tick; history of sets and their times
    // ---------------------------------------------------------------
    logic [47:0] sets[$];                 // every set the inputs had, in order
    longint      set_time[$];             // time each set appeared
    bit          seen[logic [47:0]];      // quick lookup for check 2
    int          ticks = 0;
    bit          drive = 1'b0;

    function automatic logic [47:0] pack(input logic [10:0] a, b, c, d, input logic [1:0] e, f);
        return {a, b, c, d, e, f};
    endfunction

    always @(posedge clk_juego) if (drive) begin
        logic [47:0] s;
        s = {$urandom, $urandom};
        {g1x, g1y, g2x, g2y, h1, h2} <= s;
        sets.push_back(s); set_time.push_back($time); seen[s] = 1'b1;
        ticks++;
    end

    // ---------------------------------------------------------------
    // Checks 1-3, sampled on the falling edge of clk_pix
    // ---------------------------------------------------------------
    logic [47:0] last_draw;
    logic [10:0] last_y;
    bit          checking = 1'b0;         // off during and right after a reset
    int          frames_checked = 0;

    always @(negedge clk_pix) begin
        logic [47:0] now_draw;
        now_draw = pack(d1x, d1y, d2x, d2y, dh1, dh2);
        if (rst_seen) begin
            if (now_draw !== 48'd0) fail("draw* no es 0 durante rst_pix");
        end else if (checking) begin
            // 1. only at curr_y == 800
            if (now_draw !== last_draw && last_y !== 11'd800)
                fail($sformatf("draw* cambio con curr_y = %0d (solo debe cambiar en 800)", last_y));
            // 2. a whole set, never a mix
            if (now_draw !== last_draw && !seen.exists(now_draw))
                fail($sformatf("draw* = %h no es ningun valor que tuvieron las entradas", now_draw));
            // 3. fresh at the end of row 800
            if (last_y == 11'd800 && curr_y == 11'd801) begin
                int k;
                k = sets.size() - 1;
                if (now_draw !== sets[k]) begin
                    if (!(k > 0 && $time - set_time[k] < MARGIN * 2 * PIX_HALF && now_draw === sets[k-1]))
                        fail($sformatf("al final de la fila 800 draw* = %h; se esperaba el ultimo valor %h", now_draw, sets[k]));
                end
                frames_checked++;
            end
        end
        last_draw = now_draw;
        last_y    = curr_y;
    end

    // 4. one pending copy per tick
    int copias = 0;
    always @(posedge clk_pix) if (!rst_pix && dut.new_values) copias++;

    // ---------------------------------------------------------------
    // Sequence
    // ---------------------------------------------------------------
    task automatic wait_frames(input int n);
        repeat (n * ROWS * ROW_CYC) @(posedge clk_pix);
    endtask

    initial begin
        int t0, c0;
        rst_pix = 1'b1; rst_juego = 1'b1; curr_y = 11'd0;
        {g1x, g1y, g2x, g2y, h1, h2} = '0;
        sets.push_back('0); set_time.push_back(0); seen[48'd0] = 1'b1;
        repeat (3) @(posedge clk_juego);
        @(negedge clk_pix); rst_pix = 1'b0;
        @(negedge clk_juego); rst_juego = 1'b0;
        drive = 1'b1;
        wait_frames(2);
        checking = 1'b1;

        // Run TICKS ticks, counting copies against ticks
        t0 = ticks; c0 = copias;
        repeat (TICKS) @(posedge clk_juego);
        repeat (MARGIN) @(posedge clk_pix);
        if (copias - c0 < (ticks - t0) - 1 || copias - c0 > (ticks - t0) + 1)
            fail($sformatf("%0d copias a pendiente en %0d ticks; se esperaba una por tick", copias - c0, ticks - t0));

        // 5. rst_pix mid-frame clears draw*; after 2 frames the checks resume
        wait_frames(1);
        repeat (1234) @(posedge clk_pix);
        @(negedge clk_pix); checking = 1'b0; rst_pix = 1'b1;
        repeat (50) @(posedge clk_pix);
        @(negedge clk_pix); rst_pix = 1'b0;
        wait_frames(2);
        checking = 1'b1;
        repeat (40) @(posedge clk_juego);

        $display("%0d ticks de clk_juego, %0d cuadros revisados", ticks, frames_checked);
        if (frames_checked < TICKS / 2) fail("se revisaron muy pocos cuadros");
        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
