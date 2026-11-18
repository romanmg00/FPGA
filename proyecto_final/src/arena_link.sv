// Author: Alan (AIF31).
// Game-side half of the Arena crossing, on clk_juego. After each Step (and when load rises) it
// sends the heads to arena_ctrl and gets back the codes of the 4 neighbour Cells of each head.
// With the Step at edge k: heads sent at k+1, codes and codes_valid at k+4.
module arena_link (
    input  logic        clk,                        // clk_juego (~60 Hz)
    input  logic        rst,                        // rst_juego, synchronous, active high
    // From position_logic
    input  logic        load,                       // Bikes held at their starts; its rise prepares the Round
    input  logic        step,                       // the Step taken; in a Crash Step no Bike moves
    input  logic [10:0] blkpos1_x, blkpos1_y,       // heads in pixels (Cell x 16)
    input  logic [10:0] blkpos2_x, blkpos2_y,
    // To position_logic: neighbour codes of the current heads
    output logic [3:0]  code1_u, code1_r, code1_d, code1_l,
    output logic [3:0]  code2_u, code2_r, code2_d, code2_l,
    output logic        codes_valid,                // 1 when the codes are those of the current heads
    // To arena_ctrl (clk_pix): held until codes_tgl answers
    output logic        heads_tgl,                  // toggles each time new heads are sent
    output logic        prepare,                    // 1 Prepare (start heads), 0 Step
    output logic [12:0] old_head_p1, old_head_p2,   // heads sent last time {cy, cx}: become Trail
    output logic [12:0] new_head_p1, new_head_p2,   // heads now {cy, cx}
    // From arena_ctrl
    input  logic        codes_tgl,                  // equals heads_tgl once the codes are ready
    input  logic [15:0] neighbours_p1, neighbours_p2    // {up, right, down, left} of each head
);

    logic        load_last;                         // load one tick earlier, for its rise
    logic        prepare_pending, step_pending;     // an event waits to be sent
    logic        codes_tgl_sync;                    // codes_tgl after sync_2ff
    logic        codes_tgl_last = 1'b0;             // codes_tgl_sync one tick earlier; never reset
    logic        heads_tgl_ff = 1'b0;               // the flip-flop behind heads_tgl; never reset
    logic        idle;                              // no heads waiting for their codes
    logic        codes_arrived;                     // the codes of the heads sent arrive
    logic        send_prepare, send_step;
    logic [12:0] head_p1, head_p2;                  // heads now, {cy, cx}
    logic [31:0] codes;                             // u1 r1 d1 l1 u2 r2 d2 l2

    // The codes cross with a toggle; they have been stable for ticks when it shows.
    // The toggles and their synchronizer are never reset: a reset must not fake or repeat a
    // send or an answer. Heads sent before a reset are still answered, and only then the
    // Prepare that follows the reset is sent.
    sync_2ff u_sync_codes_tgl (.clk(clk), .rst(1'b0), .async_in(codes_tgl), .sync_out(codes_tgl_sync));

    assign head_p1 = {blkpos1_y[9:4], blkpos1_x[10:4]};   // cy is 0..49, so 6 bits
    assign head_p2 = {blkpos2_y[9:4], blkpos2_x[10:4]};

    assign heads_tgl     = heads_tgl_ff;
    assign idle          = (codes_tgl_last == heads_tgl_ff);
    assign codes_arrived = (codes_tgl_sync == heads_tgl_ff) && !idle;
    assign send_prepare  = !rst && idle && prepare_pending;
    assign send_step     = !rst && idle && step_pending && !prepare_pending;

    assign {code1_u, code1_r, code1_d, code1_l} = codes[31:16];
    assign {code2_u, code2_r, code2_d, code2_l} = codes[15:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            load_last       <= 1'b0;
            prepare_pending <= 1'b0;
            step_pending    <= 1'b0;
            codes           <= 32'd0;
            codes_valid     <= 1'b0;
        end else begin
            load_last <= load;

            // Events wait until no heads are waiting. At 6 or 8 ticks per Step they never wait.
            // The Prepare goes one tick after load rises: bike_move loads the starts at the rise.
            if (load && !load_last)
                prepare_pending <= 1'b1;
            else if (send_prepare)
                prepare_pending <= 1'b0;

            if (step)
                step_pending <= 1'b1;
            else if (send_step || send_prepare)
                step_pending <= 1'b0;

            if (codes_arrived)
                codes <= {neighbours_p1, neighbours_p2};

            // The codes stop matching when the heads change: at the Step and when load rises.
            if (step || (load && !load_last))
                codes_valid <= 1'b0;
            else if (codes_arrived && !prepare_pending && !step_pending)
                codes_valid <= 1'b1;
        end
    end

    // The heads sent: they change only when new ones are sent, and are held until their codes.
    always_ff @(posedge clk) begin
        codes_tgl_last <= codes_tgl_sync;
        if (send_prepare) begin
            prepare      <= 1'b1;
            new_head_p1  <= head_p1;
            new_head_p2  <= head_p2;
            heads_tgl_ff <= ~heads_tgl_ff;
        end else if (send_step) begin
            prepare      <= 1'b0;
            old_head_p1  <= new_head_p1;        // the heads in the Arena become Trail
            old_head_p2  <= new_head_p2;
            new_head_p1  <= head_p1;
            new_head_p2  <= head_p2;
            heads_tgl_ff <= ~heads_tgl_ff;
        end
    end

endmodule
