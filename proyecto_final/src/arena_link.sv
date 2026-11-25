// Author: Alan (AIF31).
// Arena crossing, clk_juego side: sends the heads to arena_ctrl after each Step and when load
// rises, and gets back their neighbour codes. Step at edge k: heads at k+1, codes at k+4.
module arena_link (
    input  logic        clk,                        // clk_juego
    input  logic        rst,
    // From position_logic
    input  logic        load,                       // its rise prepares the Round
    input  logic        step,
    input  logic [1:0]  reward1, reward2,           // 0 none, 1-3 slot 0-2
    input  logic [10:0] blkpos1_x, blkpos1_y,       // heads, in pixels
    input  logic [10:0] blkpos2_x, blkpos2_y,
    // To position_logic
    output logic [3:0]  code1_u, code1_r, code1_d, code1_l,
    output logic [3:0]  code2_u, code2_r, code2_d, code2_l,
    output logic        codes_valid,                // the codes are those of the current heads
    // To arena_ctrl (clk_pix)
    output logic        heads_tgl,
    output logic        prepare,                    // 1 Prepare, 0 Step
    output logic        reseed,
    output logic [2:0]  collected,                  // slots taken, [0] slot 0
    output logic [12:0] old_head_p1, old_head_p2,   // {cy, cx}: become Trail
    output logic [12:0] new_head_p1, new_head_p2,   // {cy, cx}: become heads
    // From arena_ctrl
    input  logic        codes_tgl,
    input  logic [15:0] neighbours_p1, neighbours_p2    // {up, right, down, left}
);

    logic        load_last;
    logic        prepare_pending, step_pending;     // waiting to be sent
    logic        reseed_pending;                    // no Prepare sent since the reset
    logic [2:0]  collected_step;
    logic        codes_tgl_sync;
    logic        codes_tgl_last = 1'b0;
    logic        heads_tgl_ff = 1'b0;
    logic        idle;                              // no heads waiting for their codes
    logic        codes_arrived;
    logic        send_prepare, send_step;
    logic [12:0] head_p1, head_p2;                  // {cy, cx}
    logic [31:0] codes;                             // u1 r1 d1 l1 u2 r2 d2 l2

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
            reseed_pending  <= 1'b1;
            collected_step  <= 3'b000;
            codes           <= 32'd0;
            codes_valid     <= 1'b0;
        end else begin
            load_last <= load;

            // The Prepare goes one tick after load rises, once bike_move has loaded the starts.
            if (load && !load_last)
                prepare_pending <= 1'b1;
            else if (send_prepare)
                prepare_pending <= 1'b0;

            if (step)
                step_pending <= 1'b1;
            else if (send_step || send_prepare)
                step_pending <= 1'b0;

            // A Step needs codes_valid, so it never comes while another one waits.
            if (step)
                collected_step <= {reward1 == 2'd3 || reward2 == 2'd3,
                                   reward1 == 2'd2 || reward2 == 2'd2,
                                   reward1 == 2'd1 || reward2 == 2'd1};

            if (send_prepare)
                reseed_pending <= 1'b0;

            if (codes_arrived)
                codes <= {neighbours_p1, neighbours_p2};

            // The codes stop matching when the heads change: at the Step and when load rises.
            if (step || (load && !load_last))
                codes_valid <= 1'b0;
            else if (codes_arrived && !prepare_pending && !step_pending)
                codes_valid <= 1'b1;
        end
    end

    // The heads sent, held until their codes come back.
    always_ff @(posedge clk) begin
        codes_tgl_last <= codes_tgl_sync;
        if (send_prepare) begin
            prepare      <= 1'b1;
            reseed       <= reseed_pending;
            collected    <= 3'b000;             // a Prepare places all three
            new_head_p1  <= head_p1;
            new_head_p2  <= head_p2;
            heads_tgl_ff <= ~heads_tgl_ff;
        end else if (send_step) begin
            prepare      <= 1'b0;
            reseed       <= 1'b0;
            collected    <= collected_step;
            old_head_p1  <= new_head_p1;        // the heads in the Arena become Trail
            old_head_p2  <= new_head_p2;
            new_head_p1  <= head_p1;
            new_head_p2  <= head_p2;
            heads_tgl_ff <= ~heads_tgl_ff;
        end
    end

endmodule
