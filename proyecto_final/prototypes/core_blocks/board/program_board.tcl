# Run ONLY on alan-legion with the Nexys A7 connected; not run by this build.
set bitfile [file normalize [lindex $argv 0]]
if {![file exists $bitfile]} {error "Usage: vivado_lab -mode batch -source program_board.tcl -tclargs /absolute/core_board_top.bit"}
open_hw_manager
connect_hw_server
open_hw_target
set devices [get_hw_devices -filter {PART =~ xc7a100t*}]
if {[llength $devices]!=1} {error "Expected exactly one xc7a100t device, got $devices"}
current_hw_device [lindex $devices 0]
set_property PROGRAM.FILE $bitfile [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]
close_hw_manager
