set out [file normalize [lindex $argv 0]]
create_project clock_probe $out/project -part xc7a100tcsg324-1
foreach {name input freq second} {probe_shared 100 83.460 5.5419921875 probe_cascade 83.45588235294117 4.6875 0} {
 create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $name
 set ip [get_ips $name]
 set_property -dict [list CONFIG.PRIM_IN_FREQ $input CONFIG.PRIM_SOURCE No_buffer CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $freq CONFIG.USE_RESET false CONFIG.USE_LOCKED false] $ip
 if {$second != 0} {set_property -dict [list CONFIG.CLKOUT2_USED true CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $second] $ip}
 generate_target all $ip
 report_property $ip -file $out/$name-properties.txt
}
set f [open $out/probe.sv w]
puts $f {module probe(input logic clk, input logic din, output logic dout);
 wire pix, base; logic [16:0] count = 0; logic slow = 0; wire game;
 probe_shared u_wiz(.clk_in1(clk), .clk_out1(pix), .clk_out2(base));
 always_ff @(posedge base) if (count == 46182) begin count <= 0; slow <= ~slow; end else count <= count+1;
 BUFG u_buf(.I(slow), .O(game));
 logic p=0, g=0;
 always_ff @(posedge pix) p <= din ^ g;
 always_ff @(posedge game) g <= p;
 assign dout = g;
endmodule}
close $f
read_verilog -sv $out/probe.sv
set_property generate_synth_checkpoint false [get_files */probe_shared.xci]
synth_design -top probe -part xc7a100tcsg324-1
create_clock -name board -period 10 [get_ports clk]
create_generated_clock -name game -source [get_pins slow_reg/C] -divide_by 92366 [get_pins u_buf/O]
report_clocks -file $out/clocks.rpt
report_clock_interaction -file $out/interaction.rpt
report_cdc -details -file $out/cdc.rpt
write_checkpoint -force $out/probe.dcp
