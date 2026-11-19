# Author: Alan (AIF31).
# Vivado's RTL schematics of game_top for README.md, exported as SVG: the elaborated design
# (RTL Analysis > Schematic), which keeps the port and signal names of the source. One page per
# view the README describes, with the module instances and the nets between them.
# It opens the project of a build_game_top.tcl full run (OUT_DIR/project/game_top.xpr), where
# the IP already exists. show_schematic needs Vivado's GUI: run it from the GUI's Tcl console, or
# headless with
#   xvfb-run -a vivado -mode gui -source proyecto_final/schematics.tcl -tclargs DIAGRAM_DIR XPR exit
# With "exit" as the third argument Vivado closes when it is done.
set out [file normalize [lindex $argv 0]]
set xpr [file normalize [lindex $argv 1]]
set status [catch {
    file mkdir $out
    open_project $xpr
    synth_design -rtl -name rtl_1
    # Main blocks of game_top, without the 2-FF synchronizers and the reset synchronizers, so the
    # page reads like the handout's game_top diagram
    set main [get_cells -filter {IS_PRIMITIVE == 0 && REF_NAME !~ sync_2ff* && REF_NAME !~ board_reset_sync*}]
    set pages [list \
        1-game_top       [concat $main [get_ports]] \
        2-position_logic [get_cells -hierarchical -filter {PARENT == u_position_logic && IS_PRIMITIVE == 0}] \
        3-scoreboard     [get_cells {u_match_fsm u_score_unit u_seg7_view u_seg7_link u_seg7_driver}] \
        4-arena          [get_cells {u_position_logic u_arena_link u_arena_ctrl u_arena_map u_drawcon}] \
        5-video          [get_cells {u_glide1 u_glide2 u_arena_map u_drawcon u_vga_out}]]
    foreach {name objs} $pages {
        if {[llength $objs] == 0} {error "$name: nothing to draw"}
        show_schematic $objs -name $name
        write_schematic -force -format svg -scope all $out/$name.svg
        puts "SCHEMATIC $name: [llength $objs] objects"
    }
} message]
if {$status} {puts "SCHEMATIC ERROR: $message"} else {
    set f [open $out/SCHEMATIC_COMPLETE.txt w]; puts $f done; close $f
}
if {[lindex $argv 2] eq "exit"} {exit}
