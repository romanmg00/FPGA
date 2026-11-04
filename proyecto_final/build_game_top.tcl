# Construye game_top desde el repositorio, sin proyecto previo.
#   vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR [sim|full]
# sim corre los testbenches; full ademas sintetiza, implementa y escribe game_top.bit.
set here [file dirname [file normalize [info script]]]
set out  [file normalize [lindex $argv 0]]
set mode [expr {[llength $argv] > 1 ? [lindex $argv 1] : "full"}]
proc emit {path text} {set f [open $path w]; puts $f $text; close $f}
file mkdir $out
emit $out/version.txt [version]

# Un testbench pasa si su log tiene la marca y ninguna linea de error.
proc run_bench {top marker files} {
    global out
    set dir $out/tests/$top
    file mkdir $dir
    set was [pwd]
    cd $dir
    exec xvlog -sv {*}$files >@stdout 2>@stdout
    exec xelab -debug off --timescale 1ns/1ps $top -s $top >@stdout 2>@stdout
    catch {exec xsim $top -runall -log sim.log >@stdout 2>@stdout}
    set f [open sim.log]; set log [read $f]; close $f
    cd $was
    if {![string match "*$marker*" $log] || [regexp -nocase {fatal:|error:|FAIL } $log]} {
        error "Testbench failed: $top (see $dir/sim.log)"
    }
    puts "OK $top"
}
set design [list $here/counters.sv $here/vga_out.sv $here/drawcon.sv $here/sync_2ff.sv \
    $here/board_reset_sync.sv $here/position_logic.sv $here/game_top.sv]
run_bench vga_out_tb "PRUEBAS OK" [list $here/vga_out_tb.sv $here/vga_out.sv $here/counters.sv]
run_bench position_logic_tb "PASS position_logic_tb" [list $here/position_logic_tb.sv $here/position_logic.sv]
run_bench game_top_tb "PASS game_top_tb" [concat [list $here/game_top_tb.sv $here/sim_clocks/clk_wiz_0.sv $here/sim_clocks/clk_wiz_1.sv] $design]
emit $out/tests/PASS.txt "All testbenches passed"
if {$mode eq "sim"} {exit}

create_project game_top $out/project -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]

# Los dos Wizards se generan aqui, para que funcione con cualquier version de Vivado.
# ip/clk_wiz_0/clk_wiz_0.xci se queda para el proyecto de Roman; es de Vivado 2020.2 y
# de otra parte, y al importarlo aqui Vivado pide revisar su actualizacion.
# clk_wiz_1 esta encadenado desde clk_pix, como en PR 11; se discute en el issue 10.
file mkdir $out/ip
foreach {name in_mhz source requested} {
    clk_wiz_0 100.000 Single_ended_clock_capable_pin 83.460
    clk_wiz_1 83.456  No_buffer                      5.000
} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $name -dir $out/ip
    set ip [get_ips $name]
    set_property -dict [list CONFIG.PRIM_IN_FREQ $in_mhz CONFIG.PRIM_SOURCE $source \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $requested CONFIG.USE_RESET false CONFIG.USE_LOCKED false] $ip
    set_property generate_synth_checkpoint false [get_files */${name}.xci]
    generate_target all $ip
    set m [get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip]
    set d [get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip]
    set o [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip]
    emit $out/$name-properties.txt [report_property -return_string $ip]
    emit $out/$name-frequency.txt "in_mhz=$in_mhz achieved_hz=[expr {$in_mhz * 1.0e6 * $m / $d / $o}] m=$m d=$d o=$o"
}
# Debe dar el mismo reloj de pixel que el .xci del repositorio.
set ip [get_ips clk_wiz_0]
if {[get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip] != 28.375 || [get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip] != 4 || [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip] != 8.5} {
    error "clk_wiz_0 no coincide con clk_wiz_0.xci (M 28.375, D 4, O 8.5)"
}

read_verilog -sv $design
set_property top game_top [current_fileset]
add_files -fileset constrs_1 [list $here/game_top.xdc $here/game_top_timing.xdc]
set_property USED_IN_SYNTHESIS false [get_files game_top_timing.xdc]

set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation failed"}
open_run impl_1

# Revision de estructura: hay un MMCM en cada Wizard. No prueba que sean IP generada:
# un modulo escrito a mano alrededor de un MMCME2_ADV tambien pasa.
foreach inst {u_clk u_clk1} {
    set mmcm [get_cells -hierarchical -filter "REF_NAME == MMCME2_ADV && NAME =~ $inst/*"]
    if {[llength $mmcm] != 1} {error "$inst debe ser un Clocking Wizard generado; se encontro: $mmcm"}
}

# Lista de reportes de CS-256 Official FPGA Coding Practices.
foreach cmd {report_clocks report_clock_networks report_clock_utilization report_clock_interaction report_exceptions report_methodology report_drc} {
    $cmd -file $out/$cmd.rpt
}
report_utilization -hierarchical -file $out/report_utilization.rpt
report_exceptions -ignored -file $out/exceptions_ignored.rpt
report_cdc -details -file $out/report_cdc.rpt
check_timing -verbose -file $out/check_timing.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file $out/timing_summary.rpt
file copy $out/project/game_top.runs/impl_1/game_top.bit $out/game_top.bit
set f [open $out/timing_summary.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "routed timing failed"}
emit $out/BUILD_COMPLETE.txt "All testbenches pass; routed timing met; game_top.bit written. Read the reports for sign-off."
close_project
