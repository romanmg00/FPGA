// arena_svc: the fast Arena service (A2 with G4 placement), the only writer
// of arena_map port A. Owner: Alan. Domain: clk = clk_pix (ADR 0003 item 3);
// drawcon reads port B through b_addr/b_rdata on the same clock.
//
// Commands follow prototipos/tron_fpga/model/arena_ctrl.py:
//   PREPARE  clear all 8192 words (EMPTY on playable Cells, WALL elsewhere),
//            write both start heads, reseed the LFSR for a new Match, place
//            Reward slots 0, 1, 2.
//   READ2    read both target Cells, then report their codes.
//   COMMIT   per surviving Bike: old head -> Trail, target -> Head; per
//            crashed Bike: CELL_CRASH at its last valid head (ADR 0003
//            item 4; the model does the same). Then replace each
//            collected slot in ascending order.
// After rst the service clears the Arena once (Walls only, no Rewards).
//
// PROVISIONAL (ADR 0005): every port; the start/done handshake is local to
// clk_pix and is driven by fast_core. The Reward generator is the model's
// candidate (32-bit LFSR, taps 31/21/1/0, 32 shifts per draw, 64 draws,
// then a wrapping scan), which the agreement has not selected (E1). Each
// draw shifts 32 times in one cycle; a read takes one cycle of BRAM latency.
module arena_svc (
    input  logic        clk, rst,
    input  logic        start,                 // one cycle; ignored while busy
    input  logic [1:0]  op,                    // 1 PREPARE, 2 READ2, 3 COMMIT
    input  logic        new_match,
    input  logic [31:0] seed_mix, seed,
    input  logic        fixed_seed,
    input  logic [12:0] a_p1, a_p2,            // PREPARE heads, READ2 targets, COMMIT old heads
    input  logic [12:0] b_p1, b_p2,            // COMMIT new heads
    input  logic        survive_p1, survive_p2,
    input  logic [2:0]  collected,
    output logic        busy, done,
    output logic [3:0]  code_p1, code_p2,
    output logic        slot0_valid, slot1_valid, slot2_valid,
    output logic [12:0] slot0_cell, slot1_cell, slot2_cell,
    input  logic [12:0] b_addr,
    output logic [3:0]  b_rdata
);
    import game_pkg::*;
    localparam integer RANDOM_DRAWS = 64;

    typedef enum logic [4:0] {
        IDLE, CLEAR, P_HEAD1, P_HEAD2, R_T1, R_T2, R_DONE,
        C_OLD1, C_NEW1, C_OLD2, C_NEW2, NEXT_SLOT,
        PL_DRAW, PL_READ, PL_CHECK, SC_READ, SC_CHECK, PL_WRITE, FINISH
    } state_t;
    state_t state;

    logic [1:0]  op_q;
    logic        new_match_q, survive_q_p1, survive_q_p2;
    logic [12:0] a_q_p1, a_q_p2, b_q_p1, b_q_p2;
    logic [31:0] seed_mix_q, lfsr;
    logic [2:0]  todo;                         // slots still to place
    logic [1:0]  slot;
    logic [12:0] clear_addr, cand;
    logic [6:0]  draws;
    logic [13:0] scanned;
    logic [12:0] a_addr;
    logic        a_we;
    logic [3:0]  a_wdata, a_rdata;

    arena_map u_ram (.clk, .a_addr, .a_we, .a_wdata, .a_rdata, .b_addr, .b_rdata);

    function automatic logic [31:0] draw(input logic [31:0] s);
        logic [31:0] r;
        r = s;
        for (int i = 0; i < 32; i++) r = {r[30:0], r[31] ^ r[21] ^ r[1] ^ r[0]};
        return r;
    endfunction

    function automatic logic [3:0] clear_word(input logic [12:0] addr);
        if (addr[6:0] >= 7'(PLAY_CX_MIN) && addr[6:0] <= 7'(PLAY_CX_MAX) &&
            addr[12:7] >= 6'(PLAY_CY_MIN) && addr[12:7] <= 6'(PLAY_CY_MAX)) return CELL_EMPTY;
        return CELL_WALL;
    endfunction

    // The next LFSR word (one draw = 32 shifts) and the lowest slot still to place
    logic [31:0] lfsr_next;
    always_comb lfsr_next = draw(lfsr);
    logic [1:0] first_todo;
    always_comb first_todo = todo[0] ? 2'd0 : todo[1] ? 2'd1 : 2'd2;

    always_comb begin
        busy = state != IDLE;
        a_addr = cand;
        a_we = 1'b0;
        a_wdata = CELL_EMPTY;
        case (state)
            CLEAR:   begin a_addr = clear_addr; a_we = 1'b1; a_wdata = clear_word(clear_addr); end
            P_HEAD1: begin a_addr = a_q_p1; a_we = 1'b1; a_wdata = CELL_P1_HEAD; end
            P_HEAD2: begin a_addr = a_q_p2; a_we = 1'b1; a_wdata = CELL_P2_HEAD; end
            R_T1:    a_addr = a_q_p1;
            R_T2:    a_addr = a_q_p2;
            C_OLD1:  begin a_addr = a_q_p1; a_we = 1'b1; a_wdata = survive_q_p1 ? CELL_P1_TRAIL : CELL_CRASH; end
            C_NEW1:  begin a_addr = b_q_p1; a_we = 1'b1; a_wdata = CELL_P1_HEAD; end
            C_OLD2:  begin a_addr = a_q_p2; a_we = 1'b1; a_wdata = survive_q_p2 ? CELL_P2_TRAIL : CELL_CRASH; end
            C_NEW2:  begin a_addr = b_q_p2; a_we = 1'b1; a_wdata = CELL_P2_HEAD; end
            PL_WRITE: begin a_we = 1'b1; a_wdata = CELL_REWARD0 + 4'(slot); end
            default: begin end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= CLEAR; op_q <= 0; done <= 0;   // reset clears the Arena once
            clear_addr <= 0; code_p1 <= 0; code_p2 <= 0;
            lfsr <= (seed == 0) ? 32'h1 : seed;
            todo <= 0; slot <= 0; cand <= 0; draws <= 0; scanned <= 0;
            slot0_valid <= 0; slot1_valid <= 0; slot2_valid <= 0;
            slot0_cell <= 0; slot1_cell <= 0; slot2_cell <= 0;
            new_match_q <= 0; seed_mix_q <= 0; survive_q_p1 <= 0; survive_q_p2 <= 0;
            a_q_p1 <= 0; a_q_p2 <= 0; b_q_p1 <= 0; b_q_p2 <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (start) begin
                    op_q <= op; new_match_q <= new_match; seed_mix_q <= seed_mix;
                    a_q_p1 <= a_p1; a_q_p2 <= a_p2; b_q_p1 <= b_p1; b_q_p2 <= b_p2;
                    survive_q_p1 <= survive_p1; survive_q_p2 <= survive_p2;
                    case (op)
                        2'd1: begin clear_addr <= 0; state <= CLEAR; end
                        2'd2: state <= R_T1;
                        2'd3: begin todo <= collected; state <= C_OLD1; end
                        default: state <= FINISH;
                    endcase
                end
                CLEAR: if (&clear_addr) state <= (op_q == 2'd1) ? P_HEAD1 : FINISH;
                       else clear_addr <= clear_addr + 1'b1;
                P_HEAD1: state <= P_HEAD2;
                P_HEAD2: begin
                    if (new_match_q) begin
                        if (fixed_seed) lfsr <= (seed == 0) ? 32'h1 : seed;
                        else if ((lfsr ^ seed_mix_q) != 0) lfsr <= lfsr ^ seed_mix_q;
                    end
                    slot0_valid <= 0; slot1_valid <= 0; slot2_valid <= 0;
                    todo <= 3'b111;
                    state <= NEXT_SLOT;
                end
                R_T1: state <= R_T2;
                R_T2: begin code_p1 <= a_rdata; state <= R_DONE; end
                R_DONE: begin code_p2 <= a_rdata; state <= FINISH; end
                C_OLD1: state <= survive_q_p1 ? C_NEW1 : C_OLD2;
                C_NEW1: state <= C_OLD2;
                C_OLD2: state <= survive_q_p2 ? C_NEW2 : NEXT_SLOT;
                C_NEW2: state <= NEXT_SLOT;
                NEXT_SLOT: if (todo == 0) state <= FINISH;
                    else begin
                        slot <= first_todo;
                        todo[first_todo] <= 1'b0;
                        case (first_todo)
                            2'd0: slot0_valid <= 0;
                            2'd1: slot1_valid <= 0;
                            default: slot2_valid <= 0;
                        endcase
                        draws <= 0;
                        state <= PL_DRAW;
                    end
                PL_DRAW: begin
                    lfsr <= lfsr_next;
                    cand <= lfsr_next[12:0];        // {cy, cx} = word bits [12:7], [6:0]
                    draws <= draws + 1'b1;
                    state <= PL_READ;
                end
                PL_READ: state <= PL_CHECK;
                PL_CHECK: if (a_rdata == CELL_EMPTY) state <= PL_WRITE;
                    else if (draws == 7'(RANDOM_DRAWS)) begin
                        cand <= cand + 1'b1; scanned <= 1; state <= SC_READ;
                    end else state <= PL_DRAW;
                SC_READ: state <= SC_CHECK;
                SC_CHECK: if (a_rdata == CELL_EMPTY) state <= PL_WRITE;
                    else if (scanned == 14'd8192) state <= NEXT_SLOT;   // no EMPTY Cell: slot stays absent
                    else begin cand <= cand + 1'b1; scanned <= scanned + 1'b1; state <= SC_READ; end
                PL_WRITE: begin
                    case (slot)
                        2'd0: begin slot0_valid <= 1; slot0_cell <= cand; end
                        2'd1: begin slot1_valid <= 1; slot1_cell <= cand; end
                        default: begin slot2_valid <= 1; slot2_cell <= cand; end
                    endcase
                    state <= NEXT_SLOT;
                end
                FINISH: begin done <= (op_q != 2'd0); op_q <= 0; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
