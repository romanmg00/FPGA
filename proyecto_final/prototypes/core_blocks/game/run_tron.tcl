# Full build of tron_top: Clocking Wizards from the IP Catalog, synthesis,
# derived crossing constraints, implementation, bitstream and the sign-off
# reports of the Coding Practices. Modelled on board/run_board.tcl, which met
# routed timing for the board test pattern. Run through run_tron.sh.
set out [file normalize [lindex $argv 0]]
set src $out/src
set core $src/prototypes/core_blocks
proc emit {path text} {set f [open $path w]; puts $f $text; close $f}
create_project tron $out/project -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
emit $out/version.txt [version]

# Handout settings: no reset, no locked; record the achieved rates.
foreach {name requested} {tron_pixel_clock 83.460 tron_base_clock 4.6875} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $name
    set ip [get_ips $name]
    set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 CONFIG.PRIM_SOURCE No_buffer \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $requested CONFIG.USE_RESET false CONFIG.USE_LOCKED false] $ip
    set_property generate_synth_checkpoint false [get_files */${name}.xci]
    generate_target all $ip
    emit $out/$name-properties.txt [report_property -return_string $ip]
    set hz [expr {100000000.0 * [get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip] / \
        [get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip] / [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip]}]
    emit $out/$name-frequency.txt "requested_mhz=$requested achieved_hz=$hz"
}

foreach f {
    game_pkg.sv io/sync_2ff.sv io/btn_debounce.sv io/seg7_driver.sv io/seg7_page.sv
    step/turn_unit.sv step/next_cell.sv step/step_resolve.sv score/score_unit.sv
    arena/arena_map.sv video/game_clk_div.sv board/board_reset_sync.sv
    game/reset_stretch.sv game/arena_svc.sv game/fast_core.sv game/game_core.sv
    game/sprite_rom.sv game/drawcon_game.sv game/tron_system.sv game/tron_top.sv
} {read_verilog -sv $core/$f}
read_verilog -sv [list $src/vga_out.sv $src/counters.sv \
    $src/prototypes/uart_input/uart_sync_2ff.sv $src/prototypes/uart_input/uart_rx.sv \
    $src/prototypes/uart_input/uart_cmd_decode.sv]
set_property top tron_top [current_fileset]
# Sprite ROM contents: the .mem twins of the .coe files from tools/png2coe.py.
set_property generic "SPRITE_DIR=\"$core/game/sprites/\"" [current_fileset]
add_files -fileset constrs_1 $core/game/tron_top.xdc

launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis did not complete"}
open_run synth_1

# --- clocks -------------------------------------------------------------------
set div_c [get_pins u_div/game_toggle_reg/C]
set div_o [get_pins u_div/u_game_buf/O]
if {[llength $div_c] != 1 || [llength $div_o] != 1} {error "divider pin query"}
create_generated_clock -name clk_juego -source $div_c -divide_by 78126 $div_o
set pix  [get_clocks -of_objects [get_pins u_pixel_wiz/clk_out1]]
set game [get_clocks clk_juego]
if {[llength $pix] != 1} {error "pixel clock query"}

proc first_stage {cells what} {
    # Every endpoint must be the first flop of a synchronizer.
    if {[llength $cells] == 0} {error "no endpoints for $what"}
    foreach c $cells {
        if {![string match FD* [get_property REF_NAME $c]] || [get_property ASYNC_REG $c] != 1} {
            error "$what reaches $c, which is not an ASYNC_REG flop"
        }
    }
}
set log [open $out/cdc-endpoints.txt w]

# --- asynchronous pins: only into first synchronizer stages ------------------
foreach port {cpu_resetn btn[0] btn[1] btn[2] btn[3] btn[4] sw[0] sw[14] sw[15] uart_rx} {
    set ends [get_cells -of_objects [all_fanout -from [get_ports $port] -flat -endpoints_only]]
    first_stage $ends $port
    puts $log "pin $port -> $ends"
    set_false_path -from [get_ports $port] -to $ends
}

# --- stretched reset request (clk_base) into each domain's synchronizer ------
set rst_src [get_cells u_reset/rst_req_reg]
set rst_dst [get_cells -of_objects [all_fanout -from [get_pins u_reset/rst_req_reg/Q] -flat -endpoints_only]]
first_stage $rst_dst "rst_req"
puts $log "rst_req -> $rst_dst"
set_false_path -from $rst_src -to $rst_dst

# --- game <-> fast mailbox, input batch and render snapshot ------------------
# Bounded, not excluded: every path between the two domains settles within
# one clk_pix period. tick_tgl is 2-FF synchronized; the payload buses are
# latched on tick_seen (>= 2 clk_pix edges after tick_tgl) or sampled by
# clk_juego a whole tick after their quiet-window update (fast_core.sv).
set g2f_from [all_registers -clock $game]
set g2f_to   [all_registers -clock $pix]
set_max_delay -datapath_only 11.982 -from $g2f_from -to $g2f_to
set_max_delay -datapath_only 11.982 -from $g2f_to -to $g2f_from
puts $log "game->fast and fast->game bounded at 11.982 ns datapath_only"
close $log

# --- outputs: human-facing pads, registered sources --------------------------
# Flip-flops and block RAMs only (vga_out's outputs are combinational from the
# counters, drawcon and the memories); all_registers would also return the MMCMs,
# which segments their clock paths.
set flops [get_cells -hier -filter {REF_NAME =~ FD* || REF_NAME =~ RAMB*}]
set_max_delay -datapath_only 11.982 -from $flops -to [get_ports {vga_* seg[*] an[*]}]
set_max_delay -datapath_only 1000 -from $flops -to [get_ports {led[*]}]

write_xdc -force $out/derived.xdc
write_checkpoint -force $out/synth.dcp
close_design
set_property USED_IN_IMPLEMENTATION false [get_files tron_top.xdc]
add_files -fileset constrs_1 $out/derived.xdc
set_property USED_IN_SYNTHESIS false [get_files derived.xdc]

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation did not complete"}
open_run impl_1
foreach cmd {report_clocks report_clock_networks report_clock_utilization report_clock_interaction
             report_bus_skew report_exceptions report_methodology report_drc report_utilization} {
    $cmd -file $out/$cmd.rpt
}
report_cdc -details -file $out/report_cdc.rpt
report_cdc -file $out/report_cdc_summary.rpt
check_timing -verbose -file $out/check_timing.rpt
report_utilization -hierarchical -file $out/utilization_hierarchical.rpt
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 10 -file $out/timing_summary.rpt
report_exceptions -ignored -file $out/exceptions_ignored.rpt
write_checkpoint -force $out/routed.dcp
file copy -force $out/project/tron.runs/impl_1/tron_top.bit $out/tron_top.bit
set f [open $out/timing_summary.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "routed timing failed"}
emit $out/BUILD_COMPLETE.txt "Bitstream generated; routed timing met. Read the reports for sign-off."
close_project
