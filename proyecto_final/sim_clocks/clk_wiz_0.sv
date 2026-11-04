// SIMULATION ONLY. Never add this to synthesis: real builds use the Vivado-generated IP
// (docs/design/CS-256 Vivado IP Inventory.md). A bench using it does not test the Wizard.
// Simulation stand-in for the pixel Wizard: ideal clock at the achieved 83.456 MHz.
`timescale 1ns/1ps
module clk_wiz_0 (input logic clk_in1, output logic clk_out1);
    logic clk = 1'b0;
    always #5.991 clk = ~clk;
    assign clk_out1 = clk;
endmodule
