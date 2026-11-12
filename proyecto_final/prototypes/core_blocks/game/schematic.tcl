# Vivado's schematics of a built tron_top, exported as PDF and SVG: the
# synthesized netlist (synth.dcp of a run_tron.sh build), one page per level of
# hierarchy that the block diagrams in diagrams/ describe, showing the
# sub-module instances and the nets between them. Run through
# run_schematic.sh, which starts Vivado's GUI on a virtual display
# (show_schematic needs it).
#   tclargs: OUT_DIR SYNTH_DCP
set out [file normalize [lindex $argv 0]]
set dcp [file normalize [lindex $argv 1]]
set status [catch {
    open_checkpoint $dcp
    foreach {name parent} {
        1-tron_top {}
        2-tron_system u_system
        3-game_core u_system/u_game
        4-fast_core u_system/u_fast
        5-drawcon_game u_system/u_draw
    } {
        if {$parent eq {}} {
            set cells [get_cells -filter {IS_PRIMITIVE == 0}]
            set objs [concat $cells [get_ports]]
        } else {
            set cells [get_cells -quiet -hierarchical -filter "PARENT == $parent && IS_PRIMITIVE == 0"]
            set objs $cells
        }
        if {[llength $cells] == 0} {puts "SCHEMATIC $name: no cells"; continue}
        show_schematic $objs -name $name
        write_schematic -force -format pdf -orientation landscape -scope all $out/$name.pdf
        write_schematic -force -format svg -scope all $out/$name.svg
        puts "SCHEMATIC $name: [llength $cells] cells"
    }
} message]
if {$status} {puts "SCHEMATIC ERROR: $message"} else {
    set f [open $out/SCHEMATIC_COMPLETE.txt w]; puts $f done; close $f
}
exit
