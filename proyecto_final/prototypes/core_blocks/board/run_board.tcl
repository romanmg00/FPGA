set out [file normalize [lindex $argv 0]]
set src $out/src
set core $src/prototypes/core_blocks
proc emit {path text} {set f [open $path w];puts $f $text;close $f}
create_project core_board $out/project -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
emit $out/version.txt [version]
foreach {name requested} {video_pixel_clock 83.460 video_game_clock 4.6875} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $name
    set ip [get_ips $name]
    set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 CONFIG.PRIM_SOURCE No_buffer CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $requested CONFIG.USE_RESET false CONFIG.USE_LOCKED false] $ip
    set_property generate_synth_checkpoint false [get_files */${name}.xci]
    generate_target all $ip
    emit $out/$name-properties.txt [report_property -return_string $ip]
    set hz [expr {100000000.0*[get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip]/[get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip]/[get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip]}]
    emit $out/$name-frequency.txt "achieved_hz=$hz"
}
foreach f {game_pkg.sv io/sync_2ff.sv io/btn_debounce.sv io/seg7_driver.sv arena/arena_map.sv arena/arena_ctrl.sv video/game_clk_div.sv board/board_reset_sync.sv board/drawcon_arena.sv board/core_board_top.sv} {read_verilog -sv $core/$f}
read_verilog -sv [list $src/vga_out.sv $src/counters.sv]
set_property top core_board_top [current_fileset]
add_files -fileset constrs_1 $core/board/core_board_top.xdc
file mkdir $out/tests
foreach bench {drawcon_arena_tb core_board_top_tb} {
    create_fileset -simset $bench
    add_files -fileset $bench $core/board/$bench.sv
    current_fileset -simset [get_filesets $bench]
    set_property top $bench [get_filesets $bench]
    set_property xsim.simulate.runtime 0ns [get_filesets $bench]
    launch_simulation -simset $bench -mode behavioral
    run all
    close_sim
    set logpath $out/project/core_board.sim/$bench/behav/xsim/simulate.log
    set f [open $logpath];set log [read $f];close $f
    emit $out/tests/$bench.txt $log
    if {![string match "*PASS $bench*" $log] || [regexp -nocase {fatal:|error:} $log]} {error "Failed $bench"}
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
set c [get_pins u_div/game_toggle_reg/C]
set o [get_pins u_div/u_game_buf/O]
if {[llength $c]!=1 || [llength $o]!=1} {error "divider query"}
create_generated_clock -name clk_juego -source $c -divide_by 78126 $o
# External asynchronous pins terminate ONLY at first-stage synchronizers.
foreach {port pattern count} {
    cpu_resetn {u_reset_*/meta_reg} 2
    btn[0] {u_buttons/buttons[0].sync_inst/meta_reg} 1
    btn[1] {u_buttons/buttons[1].sync_inst/meta_reg} 1
    btn[2] {u_buttons/buttons[2].sync_inst/meta_reg} 1
    btn[3] {u_buttons/buttons[3].sync_inst/meta_reg} 1
    btn[4] {u_buttons/buttons[4].sync_inst/meta_reg} 1
} {
    # Exact NAME equality avoids glob brackets on generate indices.
    if {$port eq "cpu_resetn"} {set dst [get_cells -hier -filter {NAME =~ u_reset_*/meta_reg}]} else {set dst [get_cells -hier -filter "NAME == $pattern"]}
    if {[llength $dst]!=$count} {error "external sync query: $pattern -> $dst"}
    set_false_path -from [get_ports $port] -to $dst
}
for {set i 0} {$i<16} {incr i} {
    set name [format {switches[%d].u_sync/meta_reg} $i]
    set dst [get_cells -hier -filter "NAME == $name"]
    if {[llength $dst]!=1} {error "switch sync query $name"}
    set_false_path -from [get_ports [format {sw[%d]} $i]] -to $dst
}
# Registered Gray TEST-PATTERN counter only. Bound all launch-to-first-stage
# routes and bit skew to one pixel period; never clock-group these domains.
set dst [get_cells -hier -regexp {gray_meta_reg\[[0-9]+\]}]
set launch {}
foreach d $dst {
    set starts [all_fanin -flat -startpoints_only -to [get_pins $d/D]]
    if {[llength $starts]!=1} {error "Gray source $d $starts"}
    lappend launch [get_cells -of_objects $starts]
}
if {[llength $dst]!=6} {error "Gray endpoint count $dst"}
set_max_delay -datapath_only 11.982 -from $launch -to $dst
set_bus_skew 11.982 -from $launch -to $dst
emit $out/cdc-endpoints.txt "Gray launch=$launch destination=$dst"
# Engineering pad-path budgets, NOT monitor setup/hold specifications.
# VGA already registered in vga_out. LEDs and scan display are human outputs.
set_max_delay -datapath_only 11.982 -from [get_cells -hier -filter {REF_NAME =~ FD*}] -to [get_ports {vga_* seg[*] an[*]}]
set_max_delay -datapath_only 1000 -from [get_cells -hier -filter {REF_NAME =~ FD*}] -to [get_ports {led[*]}]
write_xdc -force $out/derived.xdc
write_checkpoint -force $out/synth.dcp
close_design
set_property USED_IN_IMPLEMENTATION false [get_files core_board_top.xdc]
add_files -fileset constrs_1 $out/derived.xdc
set_property USED_IN_SYNTHESIS false [get_files derived.xdc]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_run impl_1
foreach cmd {report_clocks report_clock_networks report_clock_utilization report_clock_interaction report_bus_skew report_exceptions report_methodology report_drc report_utilization} {$cmd -file $out/$cmd.rpt}
report_cdc -details -file $out/report_cdc.rpt
check_timing -verbose -file $out/check_timing.rpt
report_utilization -hierarchical -file $out/utilization_hierarchical.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file $out/timing_summary.rpt
report_exceptions -ignored -file $out/exceptions_ignored.rpt
write_checkpoint -force $out/routed.dcp
file copy $out/project/core_board.runs/impl_1/core_board_top.bit $out/core_board_top.bit
set f [open $out/timing_summary.rpt];set timing [read $f];close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "routed timing failed"}
emit $out/BUILD_COMPLETE.txt "Both benches PASS; bitstream generated. Read reports for signoff."
close_project
