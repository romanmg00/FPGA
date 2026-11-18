// Author: Alan (AIF31).
// Arena memory: one 4-bit code per Cell, 8192 words addressed {cy[5:0], cx[6:0]}, on clk_pix.
// The ctrl_ port (arena_ctrl, the only writer) reads in 1 cycle; the draw_ port (drawcon) reads
// in 2 cycles, the same as the sprite ROMs. A BRAM cannot be cleared by rst: arena_ctrl clears it.
//
// Cell codes (contract section 5). arena_ctrl writes 0 to 5; 6 to 10 are not written yet.
//   4'd0      EMPTY     the clear writes it on the playable Cells (cx 1..78, cy 5..48)
//   4'd1      WALL      the clear writes it on every other Cell: border, HUD rows, unused padding
//   4'd2      P1 Trail  P1's head of the previous Step; drawcon paints it a darker cyan
//   4'd3      P1 head   P1's Cell now; not painted, the Bike slides into it (ADR 0010)
//   4'd4      P2 Trail  as 2, a darker orange
//   4'd5      P2 head   as 3
//   4'd6      CRASH     reserved
//   4'd7      (none)    reserved
//   4'd8..10  Rewards   (G4) not written yet
// position_logic takes only 0 and 8..10 as free: a Step into any other code is a Crash.
module arena_map (
    input  logic        clk,                // clk_pix
    // arena_ctrl: reads and writes (BRAM port A)
    input  logic [12:0] ctrl_addr,          // Cell {cy, cx}
    input  logic        ctrl_write,         // 1: write ctrl_write_code into the Cell
    input  logic [3:0]  ctrl_write_code,
    output logic [3:0]  ctrl_read_code,     // code at ctrl_addr, 1 cycle later (old code if written then)
    // drawcon: reads only (BRAM port B)
    input  logic [12:0] draw_addr,          // Cell {cy, cx}
    output logic [3:0]  draw_code           // code at draw_addr, 2 cycles later
);

    (* ram_style = "block" *) logic [3:0] cells [0:8191];  // 8192 Cells x 4 bits = 32 Kb
    logic [3:0] draw_code_stage1;                           // draw port, first of the 2 registers

    always_ff @(posedge clk) begin
        if (ctrl_write)
            cells[ctrl_addr] <= ctrl_write_code;
        ctrl_read_code <= cells[ctrl_addr];
    end

    // The draw port is registered twice; synthesis can place the second register in the BRAM.
    always_ff @(posedge clk) begin
        draw_code_stage1 <= cells[draw_addr];
        draw_code        <= draw_code_stage1;
    end

endmodule
