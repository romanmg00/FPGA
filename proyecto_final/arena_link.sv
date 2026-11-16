// Game-side half of the Arena crossing, on clk_juego. After each Step (and when load rises) it
// sends the heads to arena_ctrl and gets back the codes of the 4 neighbour Cells of each head.
// With the Step at edge k: request at k+1, codes and codes_valid at k+4.
module arena_link (
    input  logic        clk,                    // clk_juego (~60 Hz)
    input  logic        rst,                    // rst_juego, synchronous, active high
    // From position_logic
    input  logic        load,                   // Bikes held at their starts; its rise prepares the Round
    input  logic        step,                   // Step tick: the Bikes move at this edge
    input  logic        crash1, crash2,         // the Bike crashes on this Step (read while step = 1)
    input  logic [10:0] blkpos1_x, blkpos1_y,   // heads in pixels (Cell x 16)
    input  logic [10:0] blkpos2_x, blkpos2_y,
    // To position_logic: neighbour codes of the current heads
    output logic [3:0]  code1_u, code1_r, code1_d, code1_l,
    output logic [3:0]  code2_u, code2_r, code2_d, code2_l,
    output logic        codes_valid,            // 1 when the codes are those of the current heads
    // To arena_ctrl (clk_pix), held until ack_tgl answers
    output logic        req_tgl,                // toggles once per request
    output logic        req_prepare,            // 1 Prepare, 0 Step
    output logic        req_crash1, req_crash2,
    output logic [12:0] req_old1, req_old2,     // heads sent last time {cy, cx}: become Trail
    output logic [12:0] req_new1, req_new2,     // heads now {cy, cx}
    // From arena_ctrl
    input  logic        ack_tgl,                // equals req_tgl once the request is served
    input  logic [15:0] nbr1, nbr2              // {up, right, down, left} of each head
);

    logic        load_q;                        // load one tick ago, for its rise
    logic        prep_wait, step_wait;          // an event waits to be sent
    logic        crash1_q, crash2_q;            // crashes of the waiting Step
    logic        ack_sync;                      // ack_tgl after sync_2ff
    logic        ack_seen = 1'b0;               // ack_sync one tick ago; never reset
    logic        req_q = 1'b0;                  // req_tgl; never reset
    logic        idle;                          // no request open
    logic        answer;                        // the answer to the open request arrives
    logic        send_prep, send_step;
    logic [12:0] head1, head2;                  // heads now, {cy, cx}
    logic [31:0] codes;                         // u1 r1 d1 l1 u2 r2 d2 l2

    // The answer crosses as a toggle; the codes have been stable for ticks when it shows.
    // The toggles and their synchronizer are never reset: a reset must not fake or repeat a
    // request or an answer. A request open at a reset is still answered, and only then the
    // Prepare that follows the reset is sent.
    sync_2ff u_sync_ack (.clk(clk), .rst(1'b0), .async_in(ack_tgl), .sync_out(ack_sync));

    assign head1 = {blkpos1_y[9:4], blkpos1_x[10:4]};   // cy is 0..49, so 6 bits
    assign head2 = {blkpos2_y[9:4], blkpos2_x[10:4]};

    assign req_tgl   = req_q;
    assign idle      = (ack_seen == req_q);
    assign answer    = (ack_sync == req_q) && !idle;
    assign send_prep = !rst && idle && prep_wait;
    assign send_step = !rst && idle && step_wait && !prep_wait;

    assign {code1_u, code1_r, code1_d, code1_l} = codes[31:16];
    assign {code2_u, code2_r, code2_d, code2_l} = codes[15:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            load_q      <= 1'b0;
            prep_wait   <= 1'b0;
            step_wait   <= 1'b0;
            crash1_q    <= 1'b0;
            crash2_q    <= 1'b0;
            codes       <= 32'd0;
            codes_valid <= 1'b0;
        end else begin
            load_q <= load;

            // Events wait until no request is open. At 6 or 8 ticks per Step they never wait.
            // The Prepare goes one tick after load rises: bike_move loads the starts at the rise.
            if (load && !load_q)
                prep_wait <= 1'b1;
            else if (send_prep)
                prep_wait <= 1'b0;

            if (step) begin
                step_wait <= 1'b1;
                crash1_q  <= crash1;
                crash2_q  <= crash2;
            end else if (send_step || send_prep)
                step_wait <= 1'b0;

            if (answer)
                codes <= {nbr1, nbr2};

            // The codes stop matching when the heads change: at the Step and when load rises.
            if (step || (load && !load_q))
                codes_valid <= 1'b0;
            else if (answer && !prep_wait && !step_wait)
                codes_valid <= 1'b1;
        end
    end

    // The request: it changes only when one is sent, and is held until its answer.
    always_ff @(posedge clk) begin
        ack_seen <= ack_sync;
        if (send_prep) begin
            req_prepare <= 1'b1;
            req_crash1  <= 1'b0;
            req_crash2  <= 1'b0;
            req_new1    <= head1;
            req_new2    <= head2;
            req_q       <= ~req_q;
        end else if (send_step) begin
            req_prepare <= 1'b0;
            req_crash1  <= crash1_q;
            req_crash2  <= crash2_q;
            req_old1    <= req_new1;            // the heads in the Arena become Trail
            req_old2    <= req_new2;
            req_new1    <= head1;
            req_new2    <= head2;
            req_q       <= ~req_q;
        end
    end

endmodule
