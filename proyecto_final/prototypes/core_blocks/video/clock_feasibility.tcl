# Run via video/run_clocks.sh; generated IP stays under fresh /builds folder.
set run_dir [file normalize [lindex $argv 0]]
create_project video_clocks $run_dir/project -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
set f [open $run_dir/clocks.txt w]
puts $f [version]
foreach {name requested} {video_pixel_clock 83.460 video_game_clock 4.6875} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $name
    set ip [get_ips $name]
    set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 CONFIG.PRIM_SOURCE No_buffer \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $requested CONFIG.USE_RESET false CONFIG.USE_LOCKED false] $ip
    set_property generate_synth_checkpoint false [get_files */${name}.xci]
    generate_target all $ip
    set p [open $run_dir/${name}-properties.txt w]
    puts $p [report_property -return_string $ip]; close $p
    set m [get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip]
    set d [get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip]
    set o [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip]
    set hz [expr {100000000.0*$m/$d/$o}]
    puts $f "$name requested_MHz=$requested M=$m D=$d O=$o achieved_hz=$hz VCO_hz=[expr {100000000.0*$m/$d}] PFD_hz=[expr {100000000.0/$d}]"
    if {$name eq "video_pixel_clock"} {set pixel_hz $hz} else {set base_hz $hz}
}
set half [expr {round($base_hz/120.0)}]
set game_hz [expr {$base_hz/(2*$half)}]
set frame_hz [expr {$pixel_hz/(1680*828)}]
puts $f "half_cycles=$half divide_by=[expr {2*$half}] game_hz=$game_hz error_Hz=[expr {$game_hz-60}] error_ppm=[expr {1e6*($game_hz/60-1)}]"
puts $f "frame_hz=$frame_hz game_ticks_per_frame=[expr {$game_hz/$frame_hz}]"
close $f
close_project
