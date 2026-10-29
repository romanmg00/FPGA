// Alan A1. Contract section 4 ports unchanged. clk is clk_pix (ADR 0003
// working default); no crossing. One synchronous read stage on each port.
// READ_FIRST: A returns old data on write; same-clock B collision returns old
// data too. Both ports MUST share the same buffered clock. No array reset.
module arena_map (
    input logic clk,
    input logic [12:0] a_addr,
    input logic a_we,
    input logic [3:0] a_wdata,
    output logic [3:0] a_rdata,
    input logic [12:0] b_addr,
    output logic [3:0] b_rdata
);
    import game_pkg::*;
    (* ram_style = "block" *) logic [3:0] mem [0:(1<<ADDR_W)-1];
    always_ff @(posedge clk) begin
        if (a_we) mem[a_addr] <= a_wdata;
        a_rdata <= mem[a_addr];
        b_rdata <= mem[b_addr];
    end
endmodule
