# Author: Roman (romanmg00).
# Creates the reward_rom IP (Block Memory Generator) in the open Vivado project.
#
# Same settings as reward_rom.xci, which Roman generated in Vivado 2020.2 on myws on
# 16 November 2026. The .xci is kept as the record; this script is for other Vivado
# versions or projects, because a .xci is tied to the version and project that made it
# (see docs/design/CS-256 Vivado IP Inventory.md).
#
# Run it in the Tcl Console with the project open:
#   source ~/FPGA/proyecto_final/ip/reward_rom/reward_rom.tcl
#
# Result: Single Port ROM, 512 x 12 bits, address width 9 ({sel, a_y, a_x}: words 0-255
# the +1 gem, 256-511 the +3 star), read latency 2 clock cycles (primitive output register
# on), one 18K BRAM. Ports: clka, ena, addra[8:0], douta[11:0].
# ena must be 1 for the ROM to read.

set here [file dirname [file normalize [info script]]]
set coe  [file normalize [file join $here .. .. sprites reward_neon.coe]]

if {![file exists $coe]} {
    error "reward_rom.tcl: cannot find $coe"
}

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name reward_rom

set_property -dict [list \
    CONFIG.Interface_Type                               {Native} \
    CONFIG.Memory_Type                                  {Single_Port_ROM} \
    CONFIG.Write_Width_A                                {12} \
    CONFIG.Read_Width_A                                 {12} \
    CONFIG.Write_Depth_A                                {512} \
    CONFIG.Enable_A                                     {Use_ENA_Pin} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives  {true} \
    CONFIG.Register_PortA_Output_of_Memory_Core        {false} \
    CONFIG.Use_RSTA_Pin                                 {false} \
    CONFIG.Port_A_Write_Rate                            {0} \
    CONFIG.Load_Init_File                               {true} \
    CONFIG.Coe_File                                     $coe \
] [get_ips reward_rom]

generate_target all [get_ips reward_rom]

puts "reward_rom: [get_property CONFIG.Memory_Type [get_ips reward_rom]],\
 [get_property CONFIG.Write_Depth_A [get_ips reward_rom]] x [get_property CONFIG.Write_Width_A [get_ips reward_rom]],\
 init from $coe"
