// Author: Alan (AIF31).
// Arena controller on clk_pix, the only writer of arena_map (its ctrl_ port). Each time arena_link
// sends new heads it does a Prepare (8192-word clear, both start heads) or a Step (Trails and
// heads), then reads the 4 neighbour Cells of each head. Step 17 cycles, Prepare 8,207.
module arena_ctrl (
    input  logic        clk,                        // clk_pix
    input  logic        rst,                        // rst_pix, synchronous, active high
    // From arena_link (clk_juego): held until codes_tgl answers
    input  logic        heads_tgl,                  // toggles each time new heads are sent
    input  logic        prepare,                    // 1 Prepare (start heads), 0 Step
    input  logic [12:0] old_head_p1, old_head_p2,   // heads in the Arena now, {cy, cx}: become Trail
    input  logic [12:0] new_head_p1, new_head_p2,   // heads after the Step, {cy, cx}: become head
    // To arena_link
    output logic        codes_tgl,                  // takes the value of heads_tgl once the codes are ready
    output logic [15:0] neighbours_p1, neighbours_p2,   // codes of the neighbour Cells {up, right, down, left}
    // arena_map's ctrl_ port
    output logic [12:0] ctrl_addr,
    output logic        ctrl_write,
    output logic [3:0]  ctrl_write_code,
    input  logic [3:0]  ctrl_read_code              // 1 cycle after ctrl_addr
);

    typedef enum logic [3:0] {s_idle, s_start, s_clear, s_trail_p1, s_trail_p2, s_head_p1, s_head_p2, s_read, s_done} state_t;
    state_t state;

    logic        heads_tgl_sync;                    // heads_tgl after sync_2ff
    logic        codes_tgl_ff = 1'b0;               // the flip-flop behind codes_tgl; never reset (see below)
    // The heads sent, copied on clk_pix when heads_tgl_sync changes
    logic        prepare_pix;
    logic [12:0] old_head_p1_pix, old_head_p2_pix, new_head_p1_pix, new_head_p2_pix;
    logic [12:0] count;                             // s_clear: address; s_read: read number 0..7
    logic [12:0] read_head;                         // s_read: head whose neighbours are read
    logic        read_valid;                        // ctrl_read_code holds a neighbour code this cycle
    logic [31:0] codes;                             // u1 r1 d1 l1 u2 r2 d2 l2, shifted in from the right

    // The heads cross as a toggle; they have been stable for 2 cycles when it shows.
    // The toggles and their synchronizer are never reset: a reset must not fake an answer.
    sync_2ff u_sync_heads_tgl (.clk(clk), .rst(1'b0), .async_in(heads_tgl), .sync_out(heads_tgl_sync));

    assign codes_tgl     = codes_tgl_ff;
    assign neighbours_p1 = codes[31:16];
    assign neighbours_p2 = codes[15:0];

    // ctrl_ port. Neighbours are computed per field, so cx - 1 at cx = 0 stays in the same row.
    always_comb begin
        ctrl_addr       = 13'd0;
        ctrl_write      = 1'b0;
        ctrl_write_code = 4'd0;
        read_head       = count[2] ? new_head_p2_pix : new_head_p1_pix;    // reads 0..3 Bike 1, 4..7 Bike 2
        case (state)
            s_clear: begin
                ctrl_addr  = count;
                ctrl_write = 1'b1;
                // EMPTY on the playable Cells cx 1..78, cy 5..48; WALL elsewhere (HUD, padding)
                if (count[6:0] >= 7'd1 && count[6:0] <= 7'd78 && count[12:7] >= 6'd5 && count[12:7] <= 6'd48)
                    ctrl_write_code = 4'd0;         // EMPTY
                else
                    ctrl_write_code = 4'd1;         // WALL
            end
            // A Bike that did not move (it crashed, or the other one did) has old = new: the
            // head write comes last, so that Cell stays a head.
            s_trail_p1: begin
                ctrl_addr       = old_head_p1_pix;
                ctrl_write      = 1'b1;
                ctrl_write_code = 4'd2;             // P1 Trail
            end
            s_trail_p2: begin
                ctrl_addr       = old_head_p2_pix;
                ctrl_write      = 1'b1;
                ctrl_write_code = 4'd4;             // P2 Trail
            end
            s_head_p1: begin
                ctrl_addr       = new_head_p1_pix;
                ctrl_write      = 1'b1;
                ctrl_write_code = 4'd3;             // P1 head
            end
            s_head_p2: begin
                ctrl_addr       = new_head_p2_pix;
                ctrl_write      = 1'b1;
                ctrl_write_code = 4'd5;             // P2 head
            end
            s_read: begin
                case (count[1:0])
                    2'd0: ctrl_addr = {read_head[12:7] - 6'd1, read_head[6:0]};  // up: cy - 1
                    2'd1: ctrl_addr = {read_head[12:7], read_head[6:0] + 7'd1};  // right: cx + 1
                    2'd2: ctrl_addr = {read_head[12:7] + 6'd1, read_head[6:0]};  // down: cy + 1
                    2'd3: ctrl_addr = {read_head[12:7], read_head[6:0] - 7'd1};  // left: cx - 1
                    default: ctrl_addr = read_head;
                endcase
            end
            default: begin end
        endcase
    end

    // Prepare: clear, head_p1, head_p2, 8 reads. Step: trail_p1, trail_p2, head_p1, head_p2, 8 reads.
    // s_start chooses from the copy, so no input from clk_juego reaches the state register.
    // codes_tgl changes only when the codes are ready, and a reset leaves it alone: heads cut
    // by a reset are still open, so they are served again from the start (same writes, or the
    // whole clear again). No half-cleared Arena is ever answered.
    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= s_idle;
            prepare_pix     <= 1'b0;
            old_head_p1_pix <= 13'd0;
            old_head_p2_pix <= 13'd0;
            new_head_p1_pix <= 13'd0;
            new_head_p2_pix <= 13'd0;
            count           <= 13'd0;
            read_valid      <= 1'b0;
            codes           <= 32'd0;
        end else begin
            read_valid <= (state == s_read);
            if (read_valid)
                codes <= {codes[27:0], ctrl_read_code};
            case (state)
                s_idle: begin
                    if (heads_tgl_sync != codes_tgl_ff) begin  // new heads: copy them
                        prepare_pix     <= prepare;
                        old_head_p1_pix <= old_head_p1;
                        old_head_p2_pix <= old_head_p2;
                        new_head_p1_pix <= new_head_p1;
                        new_head_p2_pix <= new_head_p2;
                        count           <= 13'd0;
                        state           <= s_start;
                    end
                end
                s_start: state <= prepare_pix ? s_clear : s_trail_p1;
                s_clear: begin
                    if (count == 13'd8191) begin            // last of the 8192 words
                        count <= 13'd0;
                        state <= s_head_p1;
                    end else
                        count <= count + 13'd1;
                end
                s_trail_p1: state <= s_trail_p2;
                s_trail_p2: state <= s_head_p1;
                s_head_p1:  state <= s_head_p2;
                s_head_p2:  state <= s_read;
                s_read: begin
                    if (count[2:0] == 3'd7)                 // 8 neighbours
                        state <= s_done;
                    else
                        count <= count + 13'd1;
                end
                s_done: begin                               // the last code shifts in at this edge
                    codes_tgl_ff <= ~codes_tgl_ff;
                    state        <= s_idle;
                end
                default: state <= s_idle;
            endcase
        end
    end

endmodule
