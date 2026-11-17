// Author: Alan (AIF31).
// Arena controller on clk_pix, the only writer of arena_map (port A). It serves one request
// from arena_link at a time: Prepare (8192-word clear, both start heads) or Step (Trails and
// heads), then reads the 4 neighbour Cells of each head. Step 17 cycles, Prepare 8,207.
module arena_ctrl (
    input  logic        clk,                    // clk_pix
    input  logic        rst,                    // rst_pix, synchronous, active high
    // Request from arena_link (clk_juego), held until ack_tgl answers it
    input  logic        req_tgl,                // toggles once per request
    input  logic        req_prepare,            // 1 Prepare, 0 Step
    input  logic [12:0] req_old1, req_old2,     // heads in the Arena now, {cy, cx}: become Trail
    input  logic [12:0] req_new1, req_new2,     // heads after the Step, {cy, cx}: become head
    // Answer to arena_link
    output logic        ack_tgl,                // takes the value of req_tgl once it is served
    output logic [15:0] nbr1, nbr2,             // codes of the neighbour Cells {up, right, down, left}
    // Port A of arena_map
    output logic [12:0] a_addr,
    output logic        a_we,
    output logic [3:0]  a_wdata,
    input  logic [3:0]  a_rdata                 // 1 cycle after a_addr
);

    typedef enum logic [3:0] {s_idle, s_start, s_clear, s_trail1, s_trail2, s_head1, s_head2, s_read, s_done} state_t;
    state_t st;

    logic        req_sync;                      // req_tgl after sync_2ff
    logic        ack_q = 1'b0;                  // ack_tgl; never reset (see below)
    logic        prepare_q;                     // the request, copied when req_sync changes
    logic [12:0] old1_q, old2_q, new1_q, new2_q;
    logic [12:0] cnt;                           // s_clear: address; s_read: read number 0..7
    logic [12:0] head;                          // s_read: head whose neighbours are read
    logic        rd_valid;                      // a_rdata holds a neighbour code this cycle
    logic [31:0] codes;                         // u1 r1 d1 l1 u2 r2 d2 l2, shifted in from the right

    // The request crosses as a toggle; the bundle has been stable for 2 cycles when it shows.
    // The toggles and their synchronizer are never reset: a reset must not fake an answer.
    sync_2ff u_sync_req (.clk(clk), .rst(1'b0), .async_in(req_tgl), .sync_out(req_sync));

    assign ack_tgl = ack_q;
    assign nbr1 = codes[31:16];
    assign nbr2 = codes[15:0];

    // Port A. Neighbours are computed per field, so cx - 1 at cx = 0 stays in the same row.
    always_comb begin
        a_addr  = 13'd0;
        a_we    = 1'b0;
        a_wdata = 4'd0;
        head    = cnt[2] ? new2_q : new1_q;     // reads 0..3 Bike 1, 4..7 Bike 2
        case (st)
            s_clear: begin
                a_addr = cnt;
                a_we   = 1'b1;
                // EMPTY on the playable Cells cx 1..78, cy 5..48; WALL elsewhere (HUD, padding)
                if (cnt[6:0] >= 7'd1 && cnt[6:0] <= 7'd78 && cnt[12:7] >= 6'd5 && cnt[12:7] <= 6'd48)
                    a_wdata = 4'd0;             // EMPTY
                else
                    a_wdata = 4'd1;             // WALL
            end
            // A Bike that did not move (it crashed, or the other one did) has old = new: the
            // head write comes last, so that Cell stays a head.
            s_trail1: begin
                a_addr  = old1_q;
                a_we    = 1'b1;
                a_wdata = 4'd2;                 // P1 Trail
            end
            s_trail2: begin
                a_addr  = old2_q;
                a_we    = 1'b1;
                a_wdata = 4'd4;                 // P2 Trail
            end
            s_head1: begin
                a_addr  = new1_q;
                a_we    = 1'b1;
                a_wdata = 4'd3;                 // P1 head
            end
            s_head2: begin
                a_addr  = new2_q;
                a_we    = 1'b1;
                a_wdata = 4'd5;                 // P2 head
            end
            s_read: begin
                case (cnt[1:0])
                    2'd0: a_addr = {head[12:7] - 6'd1, head[6:0]};  // up: cy - 1
                    2'd1: a_addr = {head[12:7], head[6:0] + 7'd1};  // right: cx + 1
                    2'd2: a_addr = {head[12:7] + 6'd1, head[6:0]};  // down: cy + 1
                    2'd3: a_addr = {head[12:7], head[6:0] - 7'd1};  // left: cx - 1
                    default: a_addr = head;
                endcase
            end
            default: begin end
        endcase
    end

    // Prepare: clear, head1, head2, 8 reads. Step: trail1, trail2, head1, head2, 8 reads.
    // s_start chooses from the copy, so no input from clk_juego reaches the state register.
    // ack_tgl changes only when the request is done, and a reset leaves it alone: a request
    // cut by a reset is still open, so it is served again from the start (same writes, or the
    // whole clear again). No half-cleared Arena is ever answered.
    always_ff @(posedge clk) begin
        if (rst) begin
            st        <= s_idle;
            prepare_q <= 1'b0;
            old1_q    <= 13'd0;
            old2_q    <= 13'd0;
            new1_q    <= 13'd0;
            new2_q    <= 13'd0;
            cnt       <= 13'd0;
            rd_valid  <= 1'b0;
            codes     <= 32'd0;
        end else begin
            rd_valid <= (st == s_read);
            if (rd_valid)
                codes <= {codes[27:0], a_rdata};
            case (st)
                s_idle: begin
                    if (req_sync != ack_q) begin        // a new request: copy it
                        prepare_q <= req_prepare;
                        old1_q    <= req_old1;
                        old2_q    <= req_old2;
                        new1_q    <= req_new1;
                        new2_q    <= req_new2;
                        cnt       <= 13'd0;
                        st        <= s_start;
                    end
                end
                s_start: st <= prepare_q ? s_clear : s_trail1;
                s_clear: begin
                    if (cnt == 13'd8191) begin          // last of the 8192 words
                        cnt <= 13'd0;
                        st  <= s_head1;
                    end else
                        cnt <= cnt + 13'd1;
                end
                s_trail1: st <= s_trail2;
                s_trail2: st <= s_head1;
                s_head1:  st <= s_head2;
                s_head2:  st <= s_read;
                s_read: begin
                    if (cnt[2:0] == 3'd7)               // 8 neighbours
                        st <= s_done;
                    else
                        cnt <= cnt + 13'd1;
                end
                s_done: begin                           // the last code shifts in at this edge
                    ack_q <= ~ack_q;
                    st      <= s_idle;
                end
                default: st <= s_idle;
            endcase
        end
    end

endmodule
