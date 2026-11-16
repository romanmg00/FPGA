# Supplement the shared runner's empty PRIMITIVE_GROUP report in Vivado 2025.2.
# Recreate exactly its OOC design/constraints, then inspect actual primitives.
set run_dir [lindex $argv 0]
source $run_dir/synth.tcl
set cells [get_cells -hier -filter {REF_NAME =~ RAMB*}]
set f [open $run_dir/ram.txt w]
puts $f "RAM primitives: [llength $cells]"
foreach c $cells {
    puts $f "[get_property REF_NAME $c] $c"
    foreach p {WRITE_MODE_A WRITE_MODE_B DOA_REG DOB_REG READ_WIDTH_A READ_WIDTH_B WRITE_WIDTH_A WRITE_WIDTH_B} {
        puts $f "  $p=[get_property $p $c]"
    }
}
close $f
if {[llength $cells] != 1 || [get_property REF_NAME $cells] ne "RAMB36E1"} {
    error "Expected exactly one RAMB36E1"
}
puts "PASS arena_ram_report"
