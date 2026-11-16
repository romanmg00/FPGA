// Arena memory: one 4-bit code per Cell, 8192 words addressed {cy[5:0], cx[6:0]}, on clk_pix.
// Port A (arena_ctrl, the only writer) reads in 1 cycle; port B (drawcon) reads in 2 cycles,
// the same as the sprite ROMs. A BRAM cannot be cleared by rst: arena_ctrl clears it.
module arena_map (
    input  logic        clk,        // clk_pix
    // Port A: arena_ctrl (reads and writes)
    input  logic [12:0] a_addr,
    input  logic        a_we,
    input  logic [3:0]  a_wdata,
    output logic [3:0]  a_rdata,    // word at a_addr, 1 cycle later (old word if written then)
    // Port B: drawcon (reads only)
    input  logic [12:0] b_addr,
    output logic [3:0]  b_rdata     // word at b_addr, 2 cycles later
);

    (* ram_style = "block" *) logic [3:0] mem [0:8191];    // 8192 Cells x 4 bits = 32 Kb
    logic [3:0] b_word;                                     // port B, first stage

    always_ff @(posedge clk) begin
        if (a_we)
            mem[a_addr] <= a_wdata;
        a_rdata <= mem[a_addr];
    end

    // Port B is registered twice; synthesis can place the second register in the BRAM.
    always_ff @(posedge clk) begin
        b_word  <= mem[b_addr];
        b_rdata <= b_word;
    end

endmodule
