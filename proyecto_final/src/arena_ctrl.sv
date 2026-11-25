// Author: Alan (AIF31).
// The only writer of arena_map, on clk_pix. Per request: a Prepare (clear, heads, three Rewards)
// or a Step (Trails, heads, Rewards taken placed again), then the neighbours of both heads.
module arena_ctrl #(
    parameter bit          FIXED_SEED = 1'b0,          // 1: every Match starts at SEED (tests), 0: free-running
    parameter logic [31:0] SEED       = 32'h1D2C_3B4A  // never 0
) (
    input  logic        clk,                        // clk_pix
    input  logic        rst,
    // From arena_link (clk_juego)
    input  logic        heads_tgl,
    input  logic        prepare,                    // 1 Prepare, 0 Step
    input  logic        reseed,
    input  logic [2:0]  collected,                  // slots taken, [0] slot 0
    input  logic [12:0] old_head_p1, old_head_p2,   // {cy, cx}: become Trail
    input  logic [12:0] new_head_p1, new_head_p2,   // {cy, cx}: become heads
    // To arena_link
    output logic        codes_tgl,
    output logic [15:0] neighbours_p1, neighbours_p2,   // {up, right, down, left}
    // arena_map
    output logic [12:0] ctrl_addr,                  // {cy, cx}
    output logic        ctrl_write,
    output logic [3:0]  ctrl_write_code,            // 0 EMPTY, 1 WALL, 2-5 Trails and heads, 8-10 Rewards
    input  logic [3:0]  ctrl_read_code              // 1 cycle after ctrl_addr
);

    typedef enum logic [3:0] {s_idle, s_start, s_clear, s_write, s_slot, s_draw, s_look, s_check,
                              s_put, s_read} state_t;
    state_t state;

    logic        heads_tgl_sync;
    logic        codes_tgl_ff = 1'b0;
    logic        prepare_pix, reseed_pix;           // clk_pix copies of the inputs
    logic [2:0]  collected_pix;
    logic [12:0] old_head_p1_pix, old_head_p2_pix, new_head_p1_pix, new_head_p2_pix;
    logic [12:0] count;                             // s_clear: Cell; s_write: write 0-3; s_read: read 0-8
    logic        playable;                          // inside the walls
    logic [12:0] read_head;
    logic [31:0] codes;                             // P1 up, right, down, left, then P2
    // Rewards
    logic [31:0] lfsr, lfsr_next;                   // lfsr_next: one draw later
    logic [2:0]  todo;                              // slots still to place
    logic [1:0]  slot;
    logic [12:0] cand;                              // Cell being tried, {cy, cx}
    logic [13:0] tries;                             // 1-64 draws, then 65-8256 scanned words

    sync_2ff u_sync_heads_tgl (.clk(clk), .rst(1'b0), .async_in(heads_tgl), .sync_out(heads_tgl_sync));

    assign codes_tgl     = codes_tgl_ff;
    assign neighbours_p1 = codes[31:16];
    assign neighbours_p2 = codes[15:0];
    assign playable  = (count[6:0] >= 7'd1 && count[6:0] <= 7'd78 && count[12:7] >= 6'd5 && count[12:7] <= 6'd48);
    assign read_head = count[2] ? new_head_p2_pix : new_head_p1_pix;   // reads 0-3 P1, 4-7 P2

    // One draw: 32 shifts left, new bit 0 = bit 31 ^ 21 ^ 1 ^ 0 (maximal length), as in
    // prototipos/tron_fpga/model/lfsr.py.
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

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= s_idle;
            count <= 13'd0;
            lfsr  <= SEED;
        end else
            case (state)
                s_idle: begin
                    if (!FIXED_SEED)
                        lfsr <= lfsr_next;                         // one draw per idle cycle
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
                end
                s_start:
                    if (prepare_pix) begin                         // the clear removes every Reward
                        if (FIXED_SEED && reseed_pix)
                            lfsr <= SEED;
                        todo  <= 3'b111;
                        state <= s_clear;
                    end else begin
                        todo  <= collected_pix;
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
                // Rewards, lowest slot first: up to 64 draws, then a scan; first EMPTY Cell wins.
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
                        state        <= s_idle;
                    end else
                        count <= count + 13'd1;
                end
                default: state <= s_idle;
            endcase
    end

endmodule
