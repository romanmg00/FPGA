# Creates the bike_rom IP (Block Memory Generator) in the open Vivado project.
#
# Same settings as bike_rom.xci, which Roman generated in Vivado 2020.2 on myws on
# 15 November 2026. The .xci is kept as the record; this script is for other Vivado
# versions or projects, because a .xci is tied to the version and project that made it
# (see docs/design/CS-256 Vivado IP Inventory.md).
#
# Run it in the Tcl Console with the project open:
#   source ~/FPGA/proyecto_final/ip/bike_rom/bike_rom.tcl
#
# Result: Single Port ROM, 1024 x 12 bits, address width 10, read latency 2 clock cycles
# (primitive output register on), one 18K BRAM. Ports: clka, ena, addra[9:0], douta[11:0].
# ena must be 1 for the ROM to read.

set here [file dirname [file normalize [info script]]]
set coe  [file normalize [file join $here .. .. sprites bike_synth.coe]]

if {![file exists $coe]} {
    error "bike_rom.tcl: cannot find $coe"
}

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name bike_rom

set_property -dict [list \
    CONFIG.Interface_Type                               {Native} \
    CONFIG.Memory_Type                                  {Single_Port_ROM} \
    CONFIG.Write_Width_A                                {12} \
    CONFIG.Read_Width_A                                 {12} \
    CONFIG.Write_Depth_A                                {1024} \
    CONFIG.Enable_A                                     {Use_ENA_Pin} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives  {true} \
    CONFIG.Register_PortA_Output_of_Memory_Core        {false} \
    CONFIG.Use_RSTA_Pin                                 {false} \
    CONFIG.Port_A_Write_Rate                            {0} \
    CONFIG.Load_Init_File                               {true} \
    CONFIG.Coe_File                                     $coe \
] [get_ips bike_rom]

generate_target all [get_ips bike_rom]

puts "bike_rom: [get_property CONFIG.Memory_Type [get_ips bike_rom]],\
 [get_property CONFIG.Write_Depth_A [get_ips bike_rom]] x [get_property CONFIG.Write_Width_A [get_ips bike_rom]],\
 init from $coe"
