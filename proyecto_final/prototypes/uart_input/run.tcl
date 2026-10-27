# Full Vivado/XSim experiment. All products go beneath the caller's fresh output.
set source_dir [file dirname [file normalize [info script]]]
set output_dir [file normalize [lindex $argv 0]]
set flow [lindex $argv 1]
set part xc7a100tcsg324-1
file mkdir $output_dir
proc emit {path value} {
    set f [open $path w]; puts $f $value; close $f
}
emit $output_dir/version.txt [version]
create_project uart_input $output_dir/project -part $part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property coreContainer.enable false [current_project]

# Inspect the actual catalog and preserve IP-XACT/port evidence.
file mkdir $output_dir/catalog
set catalog [open $output_dir/catalog/uart-interfaces.txt w]
puts $catalog "Vivado [version -short], part $part"
puts $catalog "All matching installed definitions: [get_ipdefs -all -filter {NAME =~ *uart* || NAME =~ *UART*}]"
foreach ip_name {axi_uartlite axi_uart16550} {
    set definitions [get_ipdefs -all xilinx.com:ip:$ip_name:*]
    if {[llength $definitions] == 0} {error "Missing expected UART catalog entry $ip_name"}
    set definition [lindex [lsort -dictionary $definitions] end]
    set module_name inspect_$ip_name
    create_ip -vlnv $definition -module_name $module_name -dir $output_dir/catalog
    generate_target instantiation_template [get_ips $module_name]
    set ip [get_ips $module_name]
    puts $catalog "\nIP $definition"
    puts $catalog [report_property -return_string $ip]
    # get_ipdefs points to the installed component metadata used by IP Catalog.
    set component [get_property XML_FILE_NAME [get_ipdefs $definition]]
    puts $catalog "Component XML: $component"
    if {![file exists $component]} {error "Cannot inspect installed IP XML $component"}
    file copy $component $output_dir/catalog/${ip_name}-component.xml
    set f [open $component r]; set xml [read $f]; close $f
    set interfaces [regexp -all -inline {(?s)<spirit:busInterface>.*?</spirit:busInterface>} $xml]
    foreach interface $interfaces {
        regexp {<spirit:name>([^<]+)</spirit:name>} $interface -> interface_name
        regexp {<spirit:busType[^>]+>} $interface bus_type
        puts $catalog "$interface_name $bus_type"
    }
}
close $catalog

# Handout settings: reset/locked outputs disabled; achieved rate is inspected.
foreach {name requested} {uart_pixel_clock 83.460 uart_game_clock 5.000} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $name
    set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 \
        CONFIG.PRIM_SOURCE No_buffer \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $requested CONFIG.USE_RESET false \
        CONFIG.USE_LOCKED false] [get_ips $name]
    set_property generate_synth_checkpoint false [get_files */${name}.xci]
    generate_target all [get_ips $name]
    emit $output_dir/${name}-properties.txt [report_property -return_string [get_ips $name]]
}
set pixel [get_ips uart_pixel_clock]
set pixel_mult [get_property CONFIG.MMCM_CLKFBOUT_MULT_F $pixel]
set pixel_div [get_property CONFIG.MMCM_DIVCLK_DIVIDE $pixel]
set pixel_out [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $pixel]
set achieved_hz [expr {100000000.0 * $pixel_mult / $pixel_div / $pixel_out}]
set clk_hz [expr {round($achieved_hz)}]
set game [get_ips uart_game_clock]
set game_hz [expr {100000000.0 * [get_property CONFIG.MMCM_CLKFBOUT_MULT_F $game] / [get_property CONFIG.MMCM_DIVCLK_DIVIDE $game] / [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $game]}]
set half_cycles [expr {round($game_hz / 120.0)}]
set reset_cycles [expr {$half_cycles * 12}]
set clocks_per_bit [expr {round($achieved_hz / 115200.0)}]
emit $output_dir/clock-arithmetic.txt "requested_pixel_hz=83460000\nachieved_pixel_hz=$achieved_hz\nrtl_clk_hz=$clk_hz\nclocks_per_bit=$clocks_per_bit\nreceiver_baud=[expr {$achieved_hz / $clocks_per_bit}]\nreceiver_error_percent=[expr {100.0 * ($achieved_hz / $clocks_per_bit / 115200.0 - 1)}]\ngame_base_hz=$game_hz\ngame_half_cycles=$half_cycles\ngame_hz=[expr {$game_hz / (2 * $half_cycles)}]\nreset_hold_cycles=$reset_cycles"
set rtl {uart_sync_2ff uart_rx uart_cmd_decode uart_async_fifo uart_input_path uart_input_board}
foreach module $rtl {read_verilog -sv $source_dir/$module.sv}
set_property top uart_input_board [current_fileset]
set_property generic "clk_hz=$clk_hz game_half_cycles=$half_cycles reset_hold_cycles=$reset_cycles" [current_fileset]
add_files -fileset constrs_1 $source_dir/uart_input_board.xdc

# Each self-checking bench must reach its PASS marker; $fatal alone may leave
# launch_simulation returning successfully, so scan the simulator log as well.
file mkdir $output_dir/tests
foreach {bench extra suffix} {
    uart_rx_tb {} rx
    uart_async_fifo_tb {} fifo
    uart_input_path_tb {real_ratio=0} path-fast
    uart_input_path_tb {real_ratio=1} path-real
} {
    set fs sim_$suffix
    create_fileset -simset $fs
    add_files -fileset $fs $source_dir/$bench.sv
    set_property top $bench [get_filesets $fs]
    set generics $extra
    if {$bench ne "uart_async_fifo_tb"} {append generics " clk_hz=$clk_hz"}
    # -simset chooses sources but the backend also reads the active simset's
    # properties. Activate it explicitly; a minimal PARAM=42 probe verified this.
    current_fileset -simset [get_filesets $fs]
    set_property generic [string trim $generics] [get_filesets $fs]
    set_property xsim.simulate.runtime 0ns [get_filesets $fs]
    set_property xsim.elaborate.debug_level typical [get_filesets $fs]
    launch_simulation -simset $fs -mode behavioral
    # Log observable behavior rather than every fast-clock counter or scoreboard.
    if {$bench eq "uart_rx_tb"} {
        foreach signal {rx rx_byte rx_valid framing_error cmd cmd_valid rst} {log_wave /$bench/$signal}
    } elseif {$bench eq "uart_async_fifo_tb"} {
        foreach signal {wr_en wr_data full rd_en rd_data empty rd_valid overflow wr_rst rd_rst} {log_wave /$bench/$signal}
    } else {
        foreach signal {uart_rx_pin event_cmd event_valid overflow full ready rst_pix rst_game consume} {log_wave /$bench/$signal}
    }
    run all
    set sim_dir [get_property DIRECTORY [current_project]]/uart_input.sim/$fs/behav/xsim
    set log_path $sim_dir/simulate.log
    close_sim
    if {![file exists $log_path]} {error "Missing simulation log $log_path"}
    file copy $log_path $output_dir/tests/$suffix.txt
    set f [open $log_path r]; set log [read $f]; close $f
    if {![string match "*PASS $bench*" $log] || [regexp {(?i)fatal:|error:|failed} $log]} {
        error "Bench $bench ($suffix) did not pass; inspect $log_path"
    }
    if {$bench ne "uart_async_fifo_tb" && ![string match "*clk_hz=$clk_hz*" $log]} {
        error "Bench $bench did not use generated clk_hz=$clk_hz"
    }
    if {$bench eq "uart_input_path_tb" && ![string match "*[lindex $extra 0]*" $log]} {
        error "Bench $bench did not use requested $extra"
    }
}
emit $output_dir/tests/PASS.txt "All four XSim runs reached their PASS markers."
if {$flow eq "sim"} {close_project; exit}

set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value [list -generic [list clk_hz=$clk_hz game_half_cycles=$half_cycles reset_hold_cycles=$reset_cycles]] \
    -objects [get_runs synth_1]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis did not complete"}
open_run synth_1
# Add generated clock and CDC bounds after synthesis so hierarchy is checked.
set toggle_c [get_pins -of_objects [get_cells game_toggle_reg] -filter {REF_PIN_NAME == C}]
set game_clock_target [get_pins -of_objects [get_cells u_game_buf] -filter {REF_PIN_NAME == O}]
if {[llength $game_clock_target] != 1 || [llength $toggle_c] != 1} {error "Divider pin query did not resolve uniquely"}
# Define only at BUFG/O. Q also feeds the divider's D feedback in the 5 MHz
# domain; making Q a clock source misclassifies that data feedback as a CDC.
create_generated_clock -name game_clk -source $toggle_c -divide_by [expr {2*$half_cycles}] $game_clock_target
set fast_period [expr {floor(1.0e12 / $achieved_hz) / 1000.0}]
set endpoints [open $output_dir/cdc-endpoints.txt w]
foreach direction {wr rd} {
    set dst [get_cells -hier -regexp [format {.*u_fifo/%s_gray_sync1_reg\[[0-9]+\]} $direction]]
    if {[llength $dst] != 7} {error "Expected seven first-stage synchronizer bits ($direction)"}
    set src_cells {}
    foreach stage $dst {
        set d [get_pins -of_objects $stage -filter {REF_PIN_NAME == D}]
        set launch [all_fanin -flat -startpoints_only -to $d]
        if {[llength $launch] != 1} {error "Expected one registered source for $stage, got $launch"}
        set source_cell [get_cells -of_objects $launch]
        if {![string match FD* [get_property REF_NAME $source_cell]]} {
            error "Gray CDC startpoint is not a flip-flop: $launch"
        }
        # Q is useful for the audit log, but timing constraints use the cells:
        # constraining Q directly segments paths and invalidates skew checks.
        set q [get_pins -of_objects $source_cell -filter {REF_PIN_NAME == Q}]
        if {[llength $q] != 1} {error "Expected one Q pin on $source_cell"}
        puts $endpoints "$direction $q -> $d"
        lappend src_cells $source_cell
    }
    # Synthesis can merge Gray MSB with binary MSB; trace actual source Q pins
    # instead of forcing seven source registers with particular RTL names.
    set_max_delay -datapath_only $fast_period -from $src_cells -to $dst
    set_bus_skew $fast_period -from $src_cells -to $dst
}
close $endpoints
foreach {src_name dst_name} {
    rd_up_reg rd_up_sync1_reg
    wr_up_reg wr_up_sync1_reg
} {
    set src [get_cells -hier -filter "NAME =~ */u_fifo/$src_name"]
    set dst [get_cells -hier -filter "NAME =~ */u_fifo/$dst_name"]
    if {[llength $src] != 1 || [llength $dst] != 1} {error "Readiness path query failed"}
    set_false_path -from $src -to $dst
}
foreach {port stage} {uart_rx_pin u_path/u_rx_sync/stage1_reg cpu_resetn u_button_sync/stage1_reg} {
    set target [get_cells -hier -filter "NAME == $stage"]
    if {[llength $target] != 1} {error "External synchronizer query failed $stage"}
    set_false_path -from [get_ports $port] -to $target
}
set reset_source [get_cells reset_hold_reg]
foreach reset_sync {u_reset_pix u_reset_game} {
    set reset_dest [get_cells $reset_sync/stage1_reg]
    set_false_path -from $reset_source -to $reset_dest
}
# Stable dual-port payload is qualified by synchronized pointers. Keep the
# memory-to-read-register paths bounded, and report their CDC classification.
set payload_dest [get_cells -hier -regexp {.*u_fifo/rd_data_reg\[[0-9]+\]}]
set payload_launch {}
foreach start [all_fanin -flat -startpoints_only -to [get_pins -of_objects $payload_dest -filter {REF_PIN_NAME == D}]] {
    if {[get_property REF_NAME [get_cells -of_objects $start]] eq "RAMD64E"} {lappend payload_launch $start}
}
if {[llength $payload_launch] != 3 || [llength $payload_dest] != 3} {error "Payload endpoints not found"}
# RAM64M is transformed into RAMD64E. The actual sequential timing startpoints
# are its active CLK pins, not the enclosing RAM64M/mux cells.
set_max_delay -datapath_only $fast_period -from $payload_launch -to $payload_dest
write_xdc -force $output_dir/derived-constraints.xdc
write_checkpoint -force $output_dir/synth.dcp
# Persist derived constraints for the implementation run; the written XDC
# includes the base constraints, so exclude that duplicate from impl only.
close_design
set_property USED_IN_IMPLEMENTATION false [get_files uart_input_board.xdc]
add_files -fileset constrs_1 $output_dir/derived-constraints.xdc
set_property USED_IN_SYNTHESIS false [get_files derived-constraints.xdc]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation did not complete"}
open_run impl_1
foreach {command filename} {
    report_utilization utilization.rpt
    report_drc drc.rpt
    report_methodology methodology.rpt
    report_clocks clocks.rpt
    report_clock_networks clock-networks.rpt
    report_clock_interaction clock-interaction.rpt
    report_clock_utilization clock-utilization.rpt
    report_bus_skew bus-skew.rpt
    report_exceptions exceptions.rpt
} {$command -file $output_dir/$filename}
report_cdc -details -file $output_dir/cdc.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file $output_dir/timing-summary.rpt
report_utilization -hierarchical -file $output_dir/utilization-hierarchical.rpt
check_timing -verbose -file $output_dir/check-timing.rpt
write_checkpoint -force $output_dir/routed.dcp
file copy $output_dir/project/uart_input.runs/impl_1/uart_input_board.bit $output_dir/uart_input_board.bit
foreach {filename pattern description} {
    timing-summary.rpt {All user specified timing constraints are met.} {setup/hold/pulse-width timing}
    bus-skew.rpt {Endpoints:\s+7} {seven endpoints on each Gray bus}
} {
    set f [open $output_dir/$filename r]; set report [read $f]; close $f
    set required_matches [expr {$filename eq "bus-skew.rpt" ? 2 : 1}]
    if {[regexp -all $pattern $report] != $required_matches || [string match *VIOLATED* $report]} {
        error "Routed acceptance failed: $description"
    }
}
set f [open $output_dir/methodology.rpt r]; set methodology [read $f]; close $f
if {[string match {*Critical Warning*} $methodology]} {error "Unresolved critical methodology warning"}
emit $output_dir/BUILD_COMPLETE.txt "XSim, IP inspection and routed bitstream generation completed; inspect reports before timing/CDC sign-off."
close_project
exit
