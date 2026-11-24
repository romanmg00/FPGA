// Author: Alan (AIF31).
// The only writer of arena_map. For each new heads it does a Prepare (clear, start heads, the
// three Rewards) or a Step (old heads to Trail, new heads, a new Cell for each Reward taken),
// then reads the 4 neighbours of each head, so the codes already show the Rewards placed.
// Rewards (ADR 0012): a 32-bit LFSR, taps 31, 21, 1, 0, shifted 32 times per draw; up to 64
// draws, then a scan of all 8192 words from the last draw on. The first EMPTY Cell takes the
// Reward; with none, that slot stays absent until the next Prepare.
module arena_ctrl #(
    parameter bit          FIXED_SEED = 1'b0,          // 1: each new Match starts the LFSR at SEED (tests)
    parameter logic [31:0] SEED       = 32'h1D2C_3B4A  // LFSR value after reset; never 0
) (
    input  logic        clk,                        // clk_pix
    input  logic        rst,
    // From arena_link (clk_juego)
    input  logic        heads_tgl,                  // toggles when new heads are sent
    input  logic        prepare,                    // 1 Prepare, 0 Step
    input  logic        reseed,                     // Prepare of a new Match: mix the seed
    input  logic [2:0]  collected,                  // Step: Reward slots taken, [0] slot 0 ... [2] slot 2
    input  logic [12:0] old_head_p1, old_head_p2,   // {cy, cx}: become Trail
    input  logic [12:0] new_head_p1, new_head_p2,   // {cy, cx}: become heads
    // To arena_link
    output logic        codes_tgl,                  // equals heads_tgl when the codes are ready
    output logic [15:0] neighbours_p1, neighbours_p2,   // {up, right, down, left}
    // arena_map
    output logic [12:0] ctrl_addr,                  // {cy, cx} of the Cell
    output logic        ctrl_write,
    output logic [3:0]  ctrl_write_code,            // 0 EMPTY, 1 WALL, 2-5 Trails and heads, 8-10 Rewards
    input  logic [3:0]  ctrl_read_code              // 1 cycle after ctrl_addr
);

    typedef enum logic [3:0] {s_idle, s_start, s_clear, s_write, s_slot, s_draw, s_look, s_check,
                              s_put, s_read} state_t;
    state_t state;

    logic        heads_tgl_sync;                    // heads_tgl after 2 synchronizers, on clk_pix
    logic        codes_tgl_ff = 1'b0;               // never reset
    logic        prepare_pix, reseed_pix;           // clk_pix copies of the inputs
    logic [2:0]  collected_pix;
    logic [12:0] old_head_p1_pix, old_head_p2_pix, new_head_p1_pix, new_head_p2_pix;
    logic [12:0] count;                             // s_clear: Cell; s_write: write 0-3; s_read: read 0-8
    logic        playable;                          // the Cell being cleared is inside the walls
    logic [12:0] read_head;
    logic [31:0] codes;                             // P1 up, right, down, left, then P2
    // Rewards
    logic [31:0] seed_count = 32'd0;                // clk_pix cycles since configuration; never reset
    logic [31:0] lfsr, lfsr_next;                   // lfsr_next: lfsr shifted 32 times (one draw)
    logic [2:0]  todo;                              // slots still to place in this request
    logic [2:0]  placed = 3'b000;                   // slots already written for this request; never reset
    logic [1:0]  slot;                              // the slot being placed
    logic [12:0] cand;                              // the Cell being tried, {cy, cx}
    logic [13:0] tries;                             // 1-64 draws, then 65-8256 scanned words

    // Not reset
    sync_2ff u_sync_heads_tgl (.clk(clk), .rst(1'b0), .async_in(heads_tgl), .sync_out(heads_tgl_sync));

    assign codes_tgl     = codes_tgl_ff;
    assign neighbours_p1 = codes[31:16];
    assign neighbours_p2 = codes[15:0];
    assign playable  = (count[6:0] >= 7'd1 && count[6:0] <= 7'd78 && count[12:7] >= 6'd5 && count[12:7] <= 6'd48);
    assign read_head = count[2] ? new_head_p2_pix : new_head_p1_pix;   // reads 0-3 P1, 4-7 P2

    // One draw: 32 shifts left, the new bit 0 is bit 31 ^ bit 21 ^ bit 1 ^ bit 0
    // (x^32 + x^22 + x^2 + x + 1, maximal length), as prototipos/tron_fpga/model/lfsr.py.
    always_comb begin
        lfsr_next = lfsr;
        for (int i = 0; i < 32; i++)
            lfsr_next = {lfsr_next[30:0], lfsr_next[31] ^ lfsr_next[21] ^ lfsr_next[1] ^ lfsr_next[0]};
    end

    always_comb begin
        ctrl_addr       = 13'd0;
        ctrl_write      = 1'b0;
        ctrl_write_code = 4'd0;
        case (state)
            s_clear: begin
                ctrl_addr       = count;
                ctrl_write      = 1'b1;
                ctrl_write_code = playable ? 4'd0 : 4'd1;           // EMPTY, else WALL
            end
            // Trails before heads: a Bike that did not move has old = new, and stays a head.
            s_write: begin
                ctrl_write = 1'b1;
                case (count[1:0])
                    2'd0: begin ctrl_addr = old_head_p1_pix; ctrl_write_code = 4'd2; end  // P1 Trail
                    2'd1: begin ctrl_addr = old_head_p2_pix; ctrl_write_code = 4'd4; end  // P2 Trail
                    2'd2: begin ctrl_addr = new_head_p1_pix; ctrl_write_code = 4'd3; end  // P1 head
                    2'd3: begin ctrl_addr = new_head_p2_pix; ctrl_write_code = 4'd5; end  // P2 head
                endcase
            end
            s_look: ctrl_addr = cand;                               // its code is back in s_check
            s_put: begin
                ctrl_addr       = cand;
                ctrl_write      = 1'b1;
                ctrl_write_code = 4'd8 + {2'b00, slot};              // Reward slot 0, 1, 2: 8, 9, 10
            end
            s_read: begin
                case (count[1:0])
                    2'd0: ctrl_addr = {read_head[12:7] - 6'd1, read_head[6:0]};  // up: cy - 1
                    2'd1: ctrl_addr = {read_head[12:7], read_head[6:0] + 7'd1};  // right: cx + 1
                    2'd2: ctrl_addr = {read_head[12:7] + 6'd1, read_head[6:0]};  // down: cy + 1
                    2'd3: ctrl_addr = {read_head[12:7], read_head[6:0] - 7'd1};  // left: cx - 1
                endcase
            end
            default: begin end
        endcase
    end

    always_ff @(posedge clk)
        seed_count <= seed_count + 32'd1;

    // A reset leaves codes_tgl alone, so heads cut by a reset are served again from the start.
    // placed is not reset either: a Reward written before the reset is not placed twice.
    always_ff @(posedge clk) begin
        if (state == s_put)                                // with its write, even on a reset edge
            placed[slot] <= 1'b1;
        if (rst) begin
            state <= s_idle;
            count <= 13'd0;
            lfsr  <= SEED;
        end else
            case (state)
                s_idle:
                    if (heads_tgl_sync != codes_tgl_ff) begin      // new heads: copy them
                        prepare_pix     <= prepare;
                        reseed_pix      <= reseed;
                        collected_pix   <= collected;
                        old_head_p1_pix <= old_head_p1;
                        old_head_p2_pix <= old_head_p2;
                        new_head_p1_pix <= new_head_p1;
                        new_head_p2_pix <= new_head_p2;
                        count           <= 13'd0;
                        state           <= s_start;
                    end
                s_start:
                    if (prepare_pix) begin                         // the clear removes every Reward
                        if (reseed_pix) begin
                            if (FIXED_SEED)
                                lfsr <= SEED;
                            else if ((lfsr ^ seed_count) != 32'd0) // Start timing; 0 would stop the LFSR
                                lfsr <= lfsr ^ seed_count;
                        end
                        placed <= 3'b000;
                        todo   <= 3'b111;
                        state  <= s_clear;
                    end else begin
                        todo  <= collected_pix & ~placed;
                        state <= s_write;
                    end
                s_clear:
                    if (count == 13'd8191) begin                   // the last Cell
                        count <= 13'd2;                            // a Prepare writes only the heads
                        state <= s_write;
                    end else
                        count <= count + 13'd1;
                s_write:
                    if (count[1:0] == 2'd3)                        // the 4th write
                        state <= s_slot;
                    else
                        count <= count + 13'd1;
                // Rewards, lowest slot first.
                s_slot: begin
                    tries <= 14'd0;
                    if (todo[0]) begin
                        slot <= 2'd0; todo[0] <= 1'b0; state <= s_draw;
                    end else if (todo[1]) begin
                        slot <= 2'd1; todo[1] <= 1'b0; state <= s_draw;
                    end else if (todo[2]) begin
                        slot <= 2'd2; todo[2] <= 1'b0; state <= s_draw;
                    end else begin
                        count <= 13'd0;
                        state <= s_read;
                    end
                end
                s_draw: begin                                      // cx is bits 6-0, cy bits 12-7
                    lfsr  <= lfsr_next;
                    cand  <= lfsr_next[12:0];
                    tries <= tries + 14'd1;
                    state <= s_look;
                end
                s_look: state <= s_check;
                s_check:
                    if (ctrl_read_code == 4'd0)                    // EMPTY: the Reward goes here
                        state <= s_put;
                    else if (tries == 14'd8256)                    // 64 draws + 8192 words: no EMPTY Cell
                        state <= s_slot;                           // the slot stays absent
                    else if (tries < 14'd64)
                        state <= s_draw;
                    else begin                                     // scan on from the last draw, wrapping
                        cand  <= cand + 13'd1;
                        tries <= tries + 14'd1;
                        state <= s_look;
                    end
                s_put: state <= s_slot;
                // Reads go out on counts 0-7; each code comes back one count later.
                s_read: begin
                    if (count != 13'd0)
                        codes <= {codes[27:0], ctrl_read_code};
                    if (count == 13'd8) begin                      // the 8th code is in: answer
                        codes_tgl_ff <= ~codes_tgl_ff;
                        placed       <= 3'b000;
                        state        <= s_idle;
                    end else
                        count <= count + 13'd1;
                end
                default: state <= s_idle;
            endcase
    end

endmodule
