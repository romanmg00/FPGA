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
//   4. Scoreboard of the pending copy, from the inputs: MARGIN clk_pix cycles after every
//      clk_juego tick, dut.pend* holds the set that tick drove. The detector also pulses once
//      per tick (rising and falling toggles both count).
//   5. rst_pix clears draw* and pend*, and the outputs come back with fresh values after it.
//   6. Directed cases: clk_juego is then driven by hand, with one rising edge every other frame,
//      from 10 clk_pix cycles before row 800 starts to 6 after, twice at each offset (both toggle
//      polarities). An edge at least MARGIN cycles before row 800 shows in that frame; one after
//      row 800 waits for the next frame; one in between may do either, but the next frame shows it.
module pos_link_tb;

    localparam int ROW_CYC  = 4;          // clk_pix cycles per row (shortened)
    localparam int ROWS     = 828;        // rows per frame, as vga_out
    localparam int PIX_HALF = 5;          // clk_pix period 10
    localparam int JUE_HALF = 16573;      // clk_juego period 33146, a frame is 33120
    localparam int MARGIN   = 8;          // clk_pix cycles allowed for the crossing
    localparam int TICKS    = 400;        // clk_juego ticks to run

    logic        clk_pix = 1'b0, clk_juego;
    logic        clk_free = 1'b0;         // free-running clk_juego
    logic        clk_man  = 1'b0;         // clk_juego driven by hand (check 6)
    bit          jue_free = 1'b1;         // 1: clk_juego = clk_free; 0: clk_juego = clk_man
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
    always #JUE_HALF clk_free  = ~clk_free;
    assign clk_juego = jue_free ? clk_free : clk_man;  // switched only while both are low

    int errores = 0;
    function automatic void fail(input string msg);
        if (errores < 20) $display("ERROR t=%0t: %s", $time, msg);
        errores++;
    endfunction

    // rst_pix seen by at least one clk_pix edge (the reset is synchronous). Declared before the
    // checks below use it: XSim rejects a use before the declaration (VRFC 10-3380).
    bit rst_seen = 1'b0;
    always @(posedge clk_pix) rst_seen <= rst_pix;

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
            if (pack(dut.pend1_x, dut.pend1_y, dut.pend2_x, dut.pend2_y,
                     dut.pend_heading1, dut.pend_heading2) !== 48'd0)
                fail("pend* no es 0 durante rst_pix");
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

    // 4. Scoreboard of the pending copy. Its expected value comes from the inputs, not from
    // dut.new_values, so it fails if pending is copied at the wrong time. Ticks are about a frame
    // apart, far more than MARGIN cycles, so one process can wait for each tick in turn.
    int pend_checked = 0;
    always @(posedge clk_juego) if (drive) begin
        logic [47:0] want;
        bit          rst_in_window;
        #1 want = sets[sets.size() - 1];  // the set the drive process pushed at this edge
        rst_in_window = rst_pix;
        repeat (MARGIN) begin
            @(posedge clk_pix);
            rst_in_window |= rst_pix;
        end
        @(negedge clk_pix);
        rst_in_window |= rst_pix;
        if (!rst_in_window) begin         // a reset in the window may delay the copy
            pend_checked++;
            if (pack(dut.pend1_x, dut.pend1_y, dut.pend2_x, dut.pend2_y,
                     dut.pend_heading1, dut.pend_heading2) !== want)
                fail($sformatf("%0d ciclos despues del tick, pend* = %h; se esperaba %h", MARGIN,
                     pack(dut.pend1_x, dut.pend1_y, dut.pend2_x, dut.pend2_y,
                          dut.pend_heading1, dut.pend_heading2), want));
        end
    end

    // The detector pulses once per tick
    int copias = 0;
    always @(posedge clk_pix) if (!rst_pix && dut.new_values) copias++;

    // Position in the frame, in clk_pix cycles: row 800 starts at 800 * ROW_CYC
    int frame_pos;
    assign frame_pos = curr_y * ROW_CYC + col;

    // ---------------------------------------------------------------
    // Sequence
    // ---------------------------------------------------------------
    task automatic wait_frames(input int n);
        repeat (n * ROWS * ROW_CYC) @(posedge clk_pix);
    endtask

    // Waits for the next falling clk_pix edge in row 800, then for the first one in row 801
    // (check 3 samples there), and returns draw*
    task automatic end_of_row_800(output logic [47:0] got);
        do @(negedge clk_pix); while (curr_y != 11'd800);
        do @(negedge clk_pix); while (curr_y != 11'd801);
        got = pack(d1x, d1y, d2x, d2y, dh1, dh2);
    endtask

    // 6. One hand-driven clk_juego rising edge 3 ns after the clk_pix edge at which the frame
    // position becomes 800 * ROW_CYC + k (k < 0: before row 800 starts), then the checks.
    int directed_cases = 0;
    task automatic tick_near_row_800(input int k);
        logic [47:0] old_set, new_set, got;
        bit          tgl;
        old_set = sets[sets.size() - 1];
        do begin @(posedge clk_pix); #1; end while (frame_pos != 800 * ROW_CYC + k);
        #2 clk_man = 1'b1;
        #1 new_set = sets[sets.size() - 1];
        tgl = dut.pos_tgl;
        if (k >= ROW_CYC) begin
            // row 800 has already ended in this frame: draw* still holds the old set
            if (pack(d1x, d1y, d2x, d2y, dh1, dh2) !== old_set)
                fail($sformatf("caso k=%0d: draw* no es el valor anterior despues de la fila 800", k));
            end_of_row_800(got);
            if (got !== new_set)
                fail($sformatf("caso k=%0d: el cuadro siguiente no muestra el valor nuevo", k));
            $display("caso k=%0d pos_tgl=%0b: nuevo en el cuadro siguiente", k, tgl);
        end else begin
            end_of_row_800(got);
            if (k <= -MARGIN && got !== new_set)
                fail($sformatf("caso k=%0d: el flanco llego %0d ciclos antes de la fila 800 y draw* no lo muestra", k, -k));
            if (got !== new_set && got !== old_set)
                fail($sformatf("caso k=%0d: draw* = %h no es ni el valor anterior ni el nuevo", k, got));
            $display("caso k=%0d pos_tgl=%0b: %s en este cuadro", k, tgl, got === new_set ? "nuevo" : "anterior");
            if (got !== new_set) begin
                end_of_row_800(got);
                if (got !== new_set)
                    fail($sformatf("caso k=%0d: el cuadro siguiente no muestra el valor nuevo", k));
            end
        end
        clk_man = 1'b0;
        directed_cases++;
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

        // Run TICKS ticks, counting detector pulses against ticks
        t0 = ticks; c0 = copias;
        repeat (TICKS) @(posedge clk_juego);
        repeat (MARGIN) @(posedge clk_pix);
        if (copias - c0 < (ticks - t0) - 1 || copias - c0 > (ticks - t0) + 1)
            fail($sformatf("%0d pulsos de new_values en %0d ticks; se esperaba uno por tick", copias - c0, ticks - t0));

        // 5. rst_pix mid-frame clears draw*; after 2 frames the checks resume
        wait_frames(1);
        repeat (1234) @(posedge clk_pix);
        @(negedge clk_pix); checking = 1'b0; rst_pix = 1'b1;
        repeat (50) @(posedge clk_pix);
        @(negedge clk_pix); rst_pix = 1'b0;
        wait_frames(2);
        checking = 1'b1;
        repeat (40) @(posedge clk_juego);

        // 6. Directed cases around row 800, clk_juego by hand from here on
        @(negedge clk_free); jue_free = 1'b0;
        for (int k = -10; k <= 6; k++)
            repeat (2) begin                // two edges: the toggle rises once and falls once
                tick_near_row_800(k);
                wait_frames(1);
            end

        $display("%0d ticks de clk_juego, %0d cuadros revisados, %0d copias a pendiente revisadas, %0d casos dirigidos",
                 ticks, frames_checked, pend_checked, directed_cases);
        if (frames_checked < TICKS / 2) fail("se revisaron muy pocos cuadros");
        if (pend_checked < TICKS)       fail("se revisaron muy pocas copias a pendiente");
        if (errores == 0) $display("PRUEBAS OK");
        else              $display("FALLARON %0d revisiones", errores);
        $finish;
    end

endmodule
