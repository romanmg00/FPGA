// Author: Alan (AIF31).
// Arena memory: one 4-bit code per Cell, address {cy, cx}.
// Codes: 0 empty, 1 wall, 2/4 P1/P2 Trail, 3/5 P1/P2 head, 6-7 reserved, 8-10 Rewards.
module arena_map (
    input  logic        clk,                // clk_pix
    // arena_ctrl: reads and writes
    input  logic [12:0] ctrl_addr,          // {cy, cx}
    input  logic        ctrl_write,
    input  logic [3:0]  ctrl_write_code,
    output logic [3:0]  ctrl_read_code,     // 1 cycle later
    // drawcon: reads only
    input  logic [12:0] draw_addr,          // {cy, cx}
    output logic [3:0]  draw_code           // 2 cycles later, like the sprite ROMs
);

    (* ram_style = "block" *) logic [3:0] cells [0:8191];  // one BRAM
    logic [3:0] draw_code_stage1;

    always_ff @(posedge clk) begin
        if (ctrl_write)
            cells[ctrl_addr] <= ctrl_write_code;
        ctrl_read_code <= cells[ctrl_addr];
    end

    always_ff @(posedge clk) begin
        draw_code_stage1 <= cells[draw_addr];
        draw_code        <= draw_code_stage1;
    end

endmodule
