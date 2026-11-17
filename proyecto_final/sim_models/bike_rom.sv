// Author: Alan (AIF31).
// SIMULATION ONLY. Never add this to synthesis: real builds create bike_rom from the IP
// Catalog (docs/design/CS-256 Vivado IP Inventory.md). A bench using it does not test the IP.
// Simulation stand-in for bike_rom (Block Memory Generator, Single Port ROM, 1024 x 12) on
// clka: same ports, 2 cycles of read latency, data from the .mem that build_game_top.tcl makes
// from sprites/bike_synth.coe, given with xsim -testplusarg bike_mem=<file>.
`timescale 1ns/1ps
module bike_rom (
    input  logic        clka,
    input  logic        ena,          // gates both stages, as in the IP; drawcon ties it to 1
    input  logic [9:0]  addra,        // {row, column} of the 32 x 32 sprite
    output logic [11:0] douta         // RGB444 word, 2 clka cycles after addra
);
    logic [11:0] mem [0:1023];
    logic [11:0] word = 12'h000;      // memory latch, first cycle
    logic [11:0] out_reg = 12'h000;   // primitive output register, second cycle
    string path;

    initial begin
        if (!$value$plusargs("bike_mem=%s", path))
            $fatal(1, "bike_rom stand-in: no sprite data; run xsim with -testplusarg bike_mem=<file>.mem");
        $readmemh(path, mem);
        foreach (mem[i])
            if ($isunknown(mem[i])) $fatal(1, "bike_rom stand-in: %s does not fill word %0d", path, i);
    end

    always_ff @(posedge clka) begin
        if (ena) begin
            word    <= mem[addra];
            out_reg <= word;
        end
    end

    assign douta = out_reg;
endmodule
