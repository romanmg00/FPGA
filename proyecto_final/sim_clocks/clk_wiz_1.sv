// SIMULATION ONLY. Never add this to synthesis: real builds use the Vivado-generated IP
// (docs/design/CS-256 Vivado IP Inventory.md). A bench using it does not test the Wizard.
// Simulation stand-in for the second Wizard: ideal 5 MHz clock.
`timescale 1ns/1ps
module clk_wiz_1 (input logic clk_in1, output logic clk_out1);
    logic clk = 1'b0;
    always #100 clk = ~clk;
    assign clk_out1 = clk;
endmodule
