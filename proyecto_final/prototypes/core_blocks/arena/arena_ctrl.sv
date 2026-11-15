// Alan A2, includes A1. clk MUST be clk_pix; no CDC implemented here.
// ALL controller ports and timing are PROVISIONAL, not an X1 protocol.
// Accept cmd_valid && !busy && !rst at rising edge; latch all arguments.
// op 1=CLEAR, 2=READ2, 3=COMMIT, 0=invalid no-op (done next cycle).
// busy applies backpressure, done pulses one cycle; results hold until READ2.
// Held valid may be accepted again once idle: producer must retire its request.
// Per Player: old = last valid head; target = resolved target; survive selects
// trail+head or CELL_CRASH at old. Caller resolves collisions before COMMIT.
// Reset aborts service, inhibits writes but DOES NOT clear RAM. Integration
// must hide partially updated memory and issue CLEAR before reuse. No Pause
// port: accepted commands run to completion; Pause admission belongs upstream.
module arena_ctrl (
    input logic clk, rst,
    input logic cmd_valid,
    input logic [1:0] cmd_op,
    input logic [12:0] old_p1, old_p2, target_p1, target_p2,
    input logic survive_p1, survive_p2,
    output logic busy, done,
    output logic [3:0] code_p1, code_p2,
    input logic [12:0] b_addr,
    output logic [3:0] b_rdata
);
    import game_pkg::*;
    typedef enum logic [3:0] {IDLE, CLEAR, READ_P1, READ_P2, READ_DONE,
                             WRITE_P1, HEAD_P1, WRITE_P2, HEAD_P2, INVALID} state_t;
    state_t state;
    logic [12:0] clear_addr, old_q_p1, old_q_p2, target_q_p1, target_q_p2;
    logic survive_q_p1, survive_q_p2;
    logic [12:0] a_addr;
    logic a_we;
    logic [3:0] a_wdata, a_rdata;
    arena_map ram (.clk(clk), .a_addr(a_addr), .a_we(a_we),
        .a_wdata(a_wdata), .a_rdata(a_rdata), .b_addr(b_addr), .b_rdata(b_rdata));
    always_comb begin
        busy = state != IDLE;
        a_addr = 0;
        a_we = 0;
        a_wdata = CELL_EMPTY;
        case (state)
            CLEAR: begin
                a_addr = clear_addr;
                a_we = !rst;
                if (clear_addr[6:0] >= PLAY_CX_MIN && clear_addr[6:0] <= PLAY_CX_MAX &&
                    clear_addr[12:7] >= PLAY_CY_MIN && clear_addr[12:7] <= PLAY_CY_MAX)
                    a_wdata = CELL_EMPTY;
                else a_wdata = CELL_WALL;
            end
            READ_P1: a_addr = target_q_p1;
            READ_P2: a_addr = target_q_p2;
            WRITE_P1: begin
                a_addr = old_q_p1; a_we = !rst;
                a_wdata = survive_q_p1 ? CELL_P1_TRAIL : CELL_CRASH;
            end
            HEAD_P1: begin
                a_addr = target_q_p1; a_we = !rst; a_wdata = CELL_P1_HEAD;
            end
            WRITE_P2: begin
                a_addr = old_q_p2; a_we = !rst;
                a_wdata = survive_q_p2 ? CELL_P2_TRAIL : CELL_CRASH;
            end
            HEAD_P2: begin
                a_addr = target_q_p2; a_we = !rst; a_wdata = CELL_P2_HEAD;
            end
            default: begin end
        endcase
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE; done <= 0; code_p1 <= 0; code_p2 <= 0;
            clear_addr <= 0; old_q_p1 <= 0; old_q_p2 <= 0;
            target_q_p1 <= 0; target_q_p2 <= 0;
            survive_q_p1 <= 0; survive_q_p2 <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (cmd_valid) begin
                    old_q_p1 <= old_p1; old_q_p2 <= old_p2;
                    target_q_p1 <= target_p1; target_q_p2 <= target_p2;
                    survive_q_p1 <= survive_p1; survive_q_p2 <= survive_p2;
                    case (cmd_op)
                        1: begin clear_addr <= 0; state <= CLEAR; end
                        2: state <= READ_P1;
                        3: state <= WRITE_P1;
                        default: state <= INVALID;
                    endcase
                end
                CLEAR: if (&clear_addr) begin state <= IDLE; done <= 1; end
                       else clear_addr <= clear_addr + 1'b1;
                READ_P1: state <= READ_P2;
                READ_P2: begin code_p1 <= a_rdata; state <= READ_DONE; end
                READ_DONE: begin code_p2 <= a_rdata; state <= IDLE; done <= 1; end
                WRITE_P1: state <= survive_q_p1 ? HEAD_P1 : WRITE_P2;
                HEAD_P1: state <= WRITE_P2;
                WRITE_P2: if (survive_q_p2) state <= HEAD_P2;
                          else begin state <= IDLE; done <= 1; end
                HEAD_P2, INVALID: begin state <= IDLE; done <= 1; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
