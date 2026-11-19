// Author: Alan (AIF31).
// The only writer of arena_map. For each new heads it does a Prepare (clear, start heads) or a
// Step (old heads to Trail, new heads), then reads the 4 neighbours of each head.
module arena_ctrl (
    input  logic        clk,                        // clk_pix
    input  logic        rst,
    // From arena_link (clk_juego)
    input  logic        heads_tgl,                  // toggles when new heads are sent
    input  logic        prepare,                    // 1 Prepare, 0 Step
    input  logic [12:0] old_head_p1, old_head_p2,   // {cy, cx}: become Trail
    input  logic [12:0] new_head_p1, new_head_p2,   // {cy, cx}: become heads
    // To arena_link
    output logic        codes_tgl,                  // equals heads_tgl when the codes are ready
    output logic [15:0] neighbours_p1, neighbours_p2,   // {up, right, down, left}
    // arena_map
    output logic [12:0] ctrl_addr,                  // {cy, cx} of the Cell
    output logic        ctrl_write,                 
    output logic [3:0]  ctrl_write_code,            // 0 EMPTY, 1 WALL, 2 P1 Trail, 3 P1 head, 4 P2 Trail, 5 P2 head
    input  logic [3:0]  ctrl_read_code              // 1 cycle after ctrl_addr
);

    typedef enum logic [2:0] {s_idle, s_start, s_clear, s_write, s_read} state_t;
    state_t state;

    logic        heads_tgl_sync;                    // heads_tgl after 2 synchronizers, on clk_pix
    logic        codes_tgl_ff = 1'b0;               // never reset
    logic        prepare_pix;                       // clk_pix copies of the inputs
    logic [12:0] old_head_p1_pix, old_head_p2_pix, new_head_p1_pix, new_head_p2_pix;
    logic [12:0] count;                             // s_clear: Cell; s_write: write 0-3; s_read: read 0-8
    logic        playable;                          // the Cell being cleared is inside the walls
    logic [12:0] read_head;
    logic [31:0] codes;                             // P1 up, right, down, left, then P2

    // Not reset
    sync_2ff u_sync_heads_tgl (.clk(clk), .rst(1'b0), .async_in(heads_tgl), .sync_out(heads_tgl_sync));

    assign codes_tgl     = codes_tgl_ff;
    assign neighbours_p1 = codes[31:16];
    assign neighbours_p2 = codes[15:0];
    assign playable  = (count[6:0] >= 7'd1 && count[6:0] <= 7'd78 && count[12:7] >= 6'd5 && count[12:7] <= 6'd48);
    assign read_head = count[2] ? new_head_p2_pix : new_head_p1_pix;   // reads 0-3 P1, 4-7 P2

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

    // A reset leaves codes_tgl alone, so heads cut by a reset are served again from the start.
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= s_idle;
            count <= 13'd0;
        end else
            case (state)
                s_idle:
                    if (heads_tgl_sync != codes_tgl_ff) begin      // new heads: copy them
                        prepare_pix     <= prepare;
                        old_head_p1_pix <= old_head_p1;
                        old_head_p2_pix <= old_head_p2;
                        new_head_p1_pix <= new_head_p1;
                        new_head_p2_pix <= new_head_p2;
                        count           <= 13'd0;
                        state           <= s_start;
                    end
                s_start: state <= prepare_pix ? s_clear : s_write;
                s_clear:
                    if (count == 13'd8191) begin                   // the last Cell
                        count <= 13'd2;                            // a Prepare writes only the heads
                        state <= s_write;
                    end else
                        count <= count + 13'd1;
                s_write:
                    if (count[1:0] == 2'd3) begin                  // the 4th write
                        count <= 13'd0;
                        state <= s_read;
                    end else
                        count <= count + 13'd1;
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
