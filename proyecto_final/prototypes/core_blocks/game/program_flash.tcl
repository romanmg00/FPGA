# Write a flash image (run_tron.tcl's tron_top.bin) to the Nexys A7-100T's
# QSPI flash (Spansion S25FL128S, 16 MB) over JTAG, then reboot the FPGA from
# it, as PROG or power-up will. Host only (Vivado or Vivado Lab with the board
# attached):
#   vivado -mode batch -source program_flash.tcl -tclargs tron_top.bin [SERIAL]
# SERIAL is the Digilent cable serial; without it the only target is used.
if {$argc < 1} { puts stderr "usage: program_flash.tcl FILE.bin \[SERIAL\]"; exit 2 }
set bin [file normalize [lindex $argv 0]]
set serial [expr {$argc > 1 ? [lindex $argv 1] : ""}]
if {![file isfile $bin] || [file size $bin] == 0} { puts stderr "Missing or empty $bin"; exit 2 }
set result [catch {
    open_hw_manager
    connect_hw_server -url localhost:3121
    set targets [get_hw_targets -quiet "*Digilent/${serial}*"]
    if {[llength $targets] != 1} { error "Expected one Digilent target: $targets" }
    current_hw_target [lindex $targets 0]
    open_hw_target
    set dev [lindex [get_hw_devices -quiet xc7a100t_0] 0]
    if {$dev eq ""} { error "No xc7a100t_0 on the target" }
    current_hw_device $dev
    puts "DEVICE: $dev IDCODE: [get_property IDCODE_HEX $dev]"
    set part [lindex [get_cfgmem_parts {s25fl128sxxxxxx0-spi-x1_x2_x4}] 0]
    create_hw_cfgmem -hw_device $dev $part
    set mem [get_property PROGRAM.HW_CFGMEM $dev]
    set_property PROGRAM.ADDRESS_RANGE {use_file} $mem
    set_property PROGRAM.FILES [list $bin] $mem
    set_property PROGRAM.PRM_FILE {} $mem
    set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $mem
    set_property PROGRAM.BLANK_CHECK 0 $mem
    set_property PROGRAM.ERASE 1 $mem
    set_property PROGRAM.CFG_PROGRAM 1 $mem
    set_property PROGRAM.VERIFY 1 $mem
    set_property PROGRAM.CHECKSUM 0 $mem
    # The FPGA is loaded with Vivado's flash-programming core first.
    create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
    program_hw_devices $dev
    refresh_hw_device $dev
    program_hw_cfgmem -hw_cfgmem $mem
    puts "FLASHED: $bin (erase, program, verify)"
    boot_hw_device $dev                      ;# reload from the flash, as PROG does
    after 2000
    refresh_hw_device -update_hw_probes false $dev
    set done [get_property REGISTER.CONFIG_STATUS.BIT13_DONE_INTERNAL_SIGNAL_STATUS $dev]
    puts "DONE_PIN after boot from flash: $done"
    if {$done ne "1"} { error "FPGA did not configure from the flash" }
} message]
catch {close_hw_target}
catch {disconnect_hw_server}
catch {close_hw_manager}
if {$result} { puts stderr $message; exit 1 }
exit 0
