# Author: Alan (AIF31). Changes by Roman (romanmg00): pos_link, its bench and its constraint checks (X1, #48).
# Rewards (G4): the rewards scenario and the reseed crossing check.
# Construye game_top desde el repositorio, sin proyecto previo.
#   vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR [quick|sim|full]
# quick corre los testbenches de modulos (unos 20 s) y salta game_top_tb, que tarda hasta 20 min;
# es para probar mientras se trabaja. sim corre todos los testbenches; full ademas sintetiza,
# implementa y escribe game_top.bit. Antes de un push o un PR, sim o full.
set here [file dirname [file normalize [info script]]]
set src  $here/src           ;# diseno: todo lo que se sintetiza
set tb   $here/testbenches   ;# testbenches
set xdc  $here/constraints   ;# pines y temporizacion
set out  [file normalize [lindex $argv 0]]
set mode [expr {[llength $argv] > 1 ? [lindex $argv 1] : "full"}]
if {$mode ni {quick sim full}} {error "modo $mode: debe ser quick, sim o full"}
proc emit {path text} {set f [open $path w]; puts $f $text; close $f}
file mkdir $out
emit $out/version.txt [version]

# Un build nuevo nunca hereda el resultado de otro que uso la misma carpeta.
file delete -force $out/game_top.bit $out/BUILD_COMPLETE.txt $out/tests/PASS.txt

# Los testbenches corren al mismo tiempo, cada uno con su carpeta y su propio xsim, junto a
# la sintesis y la implementacion. Requiere sh, asi que este script es para Linux.
set benches {}
proc start_bench {name top marker files {xsim_args ""}} {
    global benches out
    set dir $out/tests/$name
    file delete -force $dir
    file mkdir $dir
    # $readmemh files are opened from the run folder: drawcon's sun table (sprites/sun_rows.mem)
    # and hud_layer's icons (sprites/hud_icons.mem).
    file copy $::here/sprites/sun_rows.mem $::here/sprites/hud_icons.mem $dir
    set quoted {}
    foreach file $files {lappend quoted "'$file'"}
    set run "xvlog -sv [join $quoted] && xelab -debug off --timescale 1ns/1ps $top -s $top && xsim $top -runall -log sim.log $xsim_args"
    set was [pwd]
    cd $dir
    set pipe [open |[list sh -c "($run) > run.log 2>&1"] r]
    cd $was
    lappend benches [list $name $marker $dir $pipe]
}
# Un testbench pasa solo si su proceso termina bien y su log nuevo tiene la marca, sin errores.
# La carpeta se borra antes de correrlo, para que nunca cuente un log de una corrida vieja.
proc wait_benches {} {
    global benches out mode
    set failed {}
    foreach bench $benches {
        lassign $bench name marker dir pipe
        set ok 0
        if {![catch {close $pipe}] && [file exists $dir/sim.log]} {
            set f [open $dir/sim.log]; set log [read $f]; close $f
            set ok [expr {[string match "*$marker*" $log] && ![regexp -nocase {fatal:|error:|FAIL } $log]}]
        }
        if {$ok} {puts "OK $name"} else {lappend failed $name}
    }
    if {[llength $failed]} {error "Testbenches failed: $failed (see $out/tests/<name>/run.log)"}
    if {$mode eq "quick"} {
        emit $out/tests/PASS.txt "Module testbenches passed (quick: game_top_tb not run)"
    } else {
        emit $out/tests/PASS.txt "All testbenches passed"
    }
}
# Regla de docs/design/CS-256 Vivado IP Inventory.md: los Wizards y bike_rom son IP generada
# por Vivado. Primera revision: ningun archivo del diseno define un modulo con el nombre de una
# de ellas. Los modelos de sim_clocks/ y sim_models/ solo van a los testbenches.
proc check_no_handwritten_ip {files} {
    foreach file $files {
        set f [open $file]; set text [read $f]; close $f
        if {[regexp -line {^\s*module\s+(clk_wiz_\w*|bike_rom)\M} $text found]} {
            error "$file define a mano un modulo de IP: $found"
        }
    }
}

# position_logic instancia round_fsm, step_counter y bike_move desde el PR #21; bike_glide
# dibuja cada moto deslizandose entre celdas (ADR 0010).
set movement [list $src/round_fsm.sv $src/step_counter.sv $src/bike_move.sv $src/position_logic.sv]
set design [concat [list $src/counters.sv $src/vga_out.sv $src/drawcon.sv $src/sync_2ff.sv \
    $src/board_reset_sync.sv $src/arena_map.sv $src/arena_ctrl.sv $src/arena_link.sv] $movement [list $src/bike_glide.sv \
    $src/pos_link.sv $src/match_fsm.sv $src/score_unit.sv $src/seg7_view.sv $src/seg7_link.sv $src/seg7_driver.sv \
    $src/multidigit.sv $src/sevenseg.sv $src/uart_rx.sv $src/uart_decode.sv $src/uart_link.sv $src/hud_layer.sv \
    $src/game_top.sv]]
check_no_handwritten_ip $design

# CLK_JUEGO_N vive en game_top.sv y 2 * N en game_top_timing.xdc, porque el XDC no puede
# leer parametros de SystemVerilog. Se revisa antes de todo, tambien en modo sim.
proc read_file_text {path} {set f [open $path]; set text [read $f]; close $f; return $text}
if {![regexp -line {^\s*localparam\s+int\s+CLK_JUEGO_N\s*=\s*([0-9_]+)\s*;} [read_file_text $src/game_top.sv] -> clk_juego_n]} {
    error "game_top.sv no define CLK_JUEGO_N"
}
set clk_juego_n [string map {_ {}} $clk_juego_n]
if {![regexp -line {^\s*create_generated_clock\s+-name\s+clk_juego\s.*-divide_by\s+([0-9]+)} [read_file_text $xdc/game_top_timing.xdc] -> xdc_divide]} {
    error "game_top_timing.xdc no define clk_juego con -divide_by"
}
if {$xdc_divide != 2 * $clk_juego_n} {
    error "game_top_timing.xdc usa -divide_by $xdc_divide, pero game_top.sv pide 2 * $clk_juego_n = [expr {2 * $clk_juego_n}]"
}
# sim_models/bike_rom.sv y game_top_tb leen los datos de sprites/bike_synth.coe, la misma
# fuente que la IP, convertidos aqui a .mem para $readmemh.
proc coe_to_mem {coe mem words} {
    set text [read_file_text $coe]
    if {![regexp {memory_initialization_radix\s*=\s*16\s*;} $text]} {error "$coe no esta en base 16"}
    if {![regexp {memory_initialization_vector\s*=([^;]*);} $text -> vector]} {error "$coe no tiene memory_initialization_vector"}
    set values [regexp -all -inline {[0-9A-Fa-f]+} $vector]
    if {[llength $values] != $words} {error "$coe tiene [llength $values] palabras; se esperaban $words"}
    emit $mem [join $values \n]
}
file mkdir $out/tests
set bike_mem $out/tests/bike_synth.mem
coe_to_mem $here/sprites/bike_synth.coe $bike_mem 1024

start_bench sync_2ff_tb sync_2ff_tb "PASS sync_2ff_tb" [list $tb/sync_2ff_tb.sv $src/sync_2ff.sv]
start_bench board_reset_sync_tb board_reset_sync_tb "PASS board_reset_sync_tb" [list $tb/board_reset_sync_tb.sv $src/board_reset_sync.sv]
start_bench vga_out_tb vga_out_tb "PRUEBAS OK" [list $tb/vga_out_tb.sv $src/vga_out.sv $src/counters.sv]
# Los testbenches de Roman imprimen PRUEBAS OK solo si no hubo errores.
start_bench round_fsm_tb round_fsm_tb "PRUEBAS OK" [list $tb/round_fsm_tb.sv $src/round_fsm.sv]
start_bench step_counter_tb step_counter_tb "PRUEBAS OK" [list $tb/step_counter_tb.sv $src/step_counter.sv]
start_bench bike_move_tb bike_move_tb "PRUEBAS OK" [list $tb/bike_move_tb.sv $src/bike_move.sv]
start_bench position_logic_tb position_logic_tb "PRUEBAS OK" [concat [list $tb/position_logic_tb.sv] $movement]
start_bench bike_glide_tb bike_glide_tb "PASS bike_glide_tb" [list $tb/bike_glide_tb.sv $src/bike_glide.sv]
start_bench pos_link_tb pos_link_tb "PRUEBAS OK" [list $tb/pos_link_tb.sv $src/pos_link.sv $src/sync_2ff.sv]
# Arena: arena_map and arena_ctrl (clk_pix) and arena_link (clk_juego), alone.
set arena [list $src/sync_2ff.sv $src/arena_map.sv $src/arena_ctrl.sv $src/arena_link.sv]
start_bench arena_map_tb arena_map_tb "PASS arena_map_tb" [list $tb/arena_map_tb.sv $src/arena_map.sv]
start_bench arena_ctrl_tb arena_ctrl_tb "PASS arena_ctrl_tb" [concat [list $tb/arena_ctrl_tb.sv] $arena]
foreach ticks {6 8} {
    start_bench arena_tb_s$ticks arena_tb "PASS arena_tb STEP_TICKS=$ticks" \
        [concat [list $tb/arena_tb.sv] $arena] "-testplusarg step_ticks=$ticks"
}
# Physical Scoreboard (ADR 0008): the homework 1 display path, extended.
start_bench sevenseg_tb sevenseg_tb "PASS sevenseg_tb" [list $tb/sevenseg_tb.sv $src/sevenseg.sv]
start_bench multidigit_tb multidigit_tb "PASS multidigit_tb" [list $tb/multidigit_tb.sv $src/multidigit.sv $src/sevenseg.sv]
start_bench seg7_view_tb seg7_view_tb "PASS seg7_view_tb" [list $tb/seg7_view_tb.sv $src/seg7_view.sv]
start_bench seg7_driver_tb seg7_driver_tb "PASS seg7_driver_tb" [list $tb/seg7_driver_tb.sv $src/seg7_driver.sv $src/multidigit.sv $src/sevenseg.sv]
# Match lifecycle (G3/G5, Paso 7c): match_fsm and score_unit alone.
start_bench match_fsm_tb match_fsm_tb "PASS match_fsm_tb" [list $tb/match_fsm_tb.sv $src/match_fsm.sv]
start_bench score_unit_tb score_unit_tb "PASS score_unit_tb" [list $tb/score_unit_tb.sv $src/score_unit.sv]
# Scoreboard crossing (Paso 7d): seg7_link alone, clk_juego and clk_pix unrelated.
start_bench seg7_link_tb seg7_link_tb "PASS seg7_link_tb" [list $tb/seg7_link_tb.sv $src/seg7_link.sv $src/sync_2ff.sv]
# HUD: hud_layer alone, every pixel of the band.
start_bench hud_layer_tb hud_layer_tb "PASS hud_layer_tb" [list $tb/hud_layer_tb.sv $src/hud_layer.sv $src/sevenseg.sv]
# The Match on clk_juego alone: match_fsm, score_unit and position_logic, as wired in game_top.
start_bench match_tb match_tb "PASS match_tb" [concat [list $tb/match_tb.sv $src/match_fsm.sv $src/score_unit.sv] $movement]
# P2's input over UART (ADR 0013): the receiver behind sync_2ff, the byte decoder, and the
# command crossing to clk_juego.
start_bench uart_rx_tb uart_rx_tb "PASS uart_rx_tb" [list $tb/uart_rx_tb.sv $src/uart_rx.sv $src/sync_2ff.sv]
start_bench uart_decode_tb uart_decode_tb "PASS uart_decode_tb" [list $tb/uart_decode_tb.sv $src/uart_decode.sv]
start_bench uart_link_tb uart_link_tb "PASS uart_link_tb" [list $tb/uart_link_tb.sv $src/uart_link.sv $src/sync_2ff.sv]
foreach scenario [expr {$mode eq "quick" ? {} : {idle steps turns head_on wall_crash resets_short reset_long match pause rewards uart uart_uturn}}] {
    start_bench game_top_tb_$scenario game_top_tb "PASS game_top_tb $scenario" \
        [concat [list $tb/game_top_tb.sv $here/sim_clocks/clk_wiz_0.sv $here/sim_models/bike_rom.sv] $design] \
        "-testplusarg scenario=$scenario -testplusarg 'bike_mem=$bike_mem'"
}

proc build_bitstream {} {
global here src xdc out design clk_juego_n
create_project game_top $out/project -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]

# El unico Clocking Wizard se genera aqui, para que funcione con cualquier version de
# Vivado. ip/clk_wiz_0/clk_wiz_0.xci se queda para el proyecto de Roman; es de Vivado
# 2020.2 y de otra parte, y al importarlo aqui Vivado pide revisar su actualizacion.
# clk_juego sale de un contador sobre clk_pix, sin segundo Wizard (ADR 0006).
file mkdir $out/ip
set in_mhz 100.000
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0 -dir $out/ip
set ip [get_ips clk_wiz_0]
set_property -dict [list CONFIG.PRIM_IN_FREQ $in_mhz CONFIG.PRIM_SOURCE Single_ended_clock_capable_pin \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 83.460 CONFIG.USE_RESET false CONFIG.USE_LOCKED false] $ip
set_property generate_synth_checkpoint false [get_files */clk_wiz_0.xci]
generate_target all $ip
set m [get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip]
set d [get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip]
set o [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip]
emit $out/clk_wiz_0-properties.txt [report_property -return_string $ip]
# Periodo exacto de clk_pix en ns. PERIOD de Vivado sale redondeado a 1 ps.
set pix_period [expr {1.0e3 * $d * $o / ($in_mhz * $m)}]
emit $out/clk_wiz_0-frequency.txt "in_mhz=$in_mhz achieved_hz=[expr {1.0e9 / $pix_period}] m=$m d=$d o=$o"
# Segunda revision: el Wizard es un objeto de IP del catalogo.
if {[llength $ip] != 1 || ![string match xilinx.com:ip:clk_wiz:* [get_property IPDEF $ip]]} {
    error "clk_wiz_0 no es IP del catalogo: [get_property IPDEF $ip]"
}
# Debe dar el reloj de pixel de ip/clk_wiz_0/clk_wiz_0.xci. Son valores copiados de ese
# archivo: este script no lo lee, asi que si cambia hay que actualizarlos aqui.
if {[get_property CONFIG.MMCM_CLKFBOUT_MULT_F $ip] != 28.375 || [get_property CONFIG.MMCM_DIVCLK_DIVIDE $ip] != 4 || [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $ip] != 8.5} {
    error "clk_wiz_0 no da los valores esperados (M 28.375, D 4, O 8.5)"
}

# bike_rom (Block Memory Generator) tambien se genera aqui, con los valores de
# ip/bike_rom/bike_rom.tcl y los datos de sprites/bike_synth.coe. ip/bike_rom/bike_rom.xci se
# queda como registro del proyecto de Roman (Vivado 2020.2); este script no lo lee.
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name bike_rom -dir $out/ip
set rom [get_ips bike_rom]
set_property -dict [list CONFIG.Interface_Type Native CONFIG.Memory_Type Single_Port_ROM \
    CONFIG.Write_Width_A 12 CONFIG.Read_Width_A 12 CONFIG.Write_Depth_A 1024 CONFIG.Enable_A Use_ENA_Pin \
    CONFIG.Register_PortA_Output_of_Memory_Primitives true CONFIG.Register_PortA_Output_of_Memory_Core false \
    CONFIG.Use_RSTA_Pin false CONFIG.Port_A_Write_Rate 0 CONFIG.Load_Init_File true \
    CONFIG.Coe_File $here/sprites/bike_synth.coe] $rom
set_property generate_synth_checkpoint false [get_files */bike_rom.xci]
generate_target all $rom
emit $out/bike_rom-properties.txt [report_property -return_string $rom]
# Segunda revision, para la ROM: es Block Memory Generator del catalogo, 1024 x 12, con el
# registro de salida de la primitiva (2 ciclos de latencia, como sim_models/bike_rom.sv) y
# los datos del .coe del repositorio. Valores copiados de bike_rom.tcl, que este script no lee.
if {[llength $rom] != 1 || ![string match xilinx.com:ip:blk_mem_gen:* [get_property IPDEF $rom]]} {
    error "bike_rom no es IP del catalogo: [get_property IPDEF $rom]"
}
foreach {key want} {Memory_Type Single_Port_ROM Write_Depth_A 1024 Write_Width_A 12 Read_Width_A 12
        Register_PortA_Output_of_Memory_Primitives true Register_PortA_Output_of_Memory_Core false
        Load_Init_File true} {
    if {[get_property CONFIG.$key $rom] ne $want} {
        error "bike_rom: $key es [get_property CONFIG.$key $rom], se esperaba $want"
    }
}

read_verilog -sv $design
# drawcon's $readmemh("sun_rows.mem"): the striped sun's rows, one 21-bit word each.
read_mem $here/sprites/sun_rows.mem
# hud_layer's $readmemh("hud_icons.mem"): 16 x 16 icons, one 16-bit word per row.
read_mem $here/sprites/hud_icons.mem
set_property top game_top [current_fileset]
# Lo que se sintetiza: exactamente los .sv de src/, ni testbenches, ni modelos de
# sim_clocks/ o sim_models/, ni prototipos. Las IP (clk_wiz_0, bike_rom) van aparte, como .xci.
set expected [lsort [glob $src/*.sv]]
# foreach instead of lmap: lmap is Tcl 8.6, and Vivado 2020.2 ships Tcl 8.5.
set got {}
foreach f [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == SystemVerilog}] {
    lappend got [file normalize $f]
}
set got [lsort $got]
if {$got ne $expected} {
    error "sources_1 no es src/*.sv:\n  esperado: $expected\n  cargado:  $got"
}
foreach f [get_files -of_objects [get_filesets sources_1]] {
    if {[regexp {_tb\.sv$|/sim_clocks/|/sim_models/|/prototypes/} $f]} {error "sources_1 tiene $f"}
}
emit $out/sources_1.txt [join [get_files -of_objects [get_filesets sources_1]] \n]
add_files -fileset constrs_1 [list $xdc/game_top.xdc $xdc/game_top_timing.xdc]
set_property USED_IN_SYNTHESIS false [get_files game_top_timing.xdc]

set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation failed"}
open_run impl_1

# Tercera revision: la instancia tiene la estructura que genera el Wizard. Las tres no
# confirman que la instancia sea la IP generada: una copia editada y renombrada de su codigo
# las pasa, asi que tambien hay que revisar las fuentes.
set mmcm [get_cells -quiet u_clk/inst/mmcm_adv_inst]
if {[llength $mmcm] != 1 || [get_property REF_NAME $mmcm] ne "MMCME2_ADV"} {
    error "u_clk no tiene la estructura de clk_wiz_0: [get_cells -quiet -hierarchical -filter "NAME =~ u_clk/*"]"
}

# El periodo de clk_juego que usa el analisis debe ser 2 * CLK_JUEGO_N periodos de clk_pix.
# Se usa el periodo exacto de clk_pix calculado arriba con M, D y O del Wizard.
# La tolerancia (5e-7) es menor que el cambio de un N de mas o de menos (1.4e-6).
set juego_period [get_property PERIOD [get_clocks clk_juego]]
set want_period [expr {2.0 * $clk_juego_n * $pix_period}]
if {abs($juego_period - $want_period) > 5.0e-7 * $want_period} {
    error "clk_juego tiene periodo $juego_period ns; con N = $clk_juego_n deberia ser $want_period ns"
}
emit $out/clk_juego-period.txt "clk_juego_n=$clk_juego_n pix_period_ns=$pix_period juego_period_ns=$juego_period"

# Los set_max_delay de pos_link en game_top_timing.xdc nombran registros de bike_glide, bike_move
# y pos_link. Si un cambio de nombres deja uno sin origen o sin destino, Vivado solo avisa, asi
# que aqui se detiene el build. Mientras turn_req2 = 0, P2 no cambia de fila ni de direccion y la
# sintesis quita parte de su glide_y y sus heading_reg. Los numeros quedan en pos_link_cells.txt.
set bike_cells    [get_cells -quiet {u_glide*/glide_x_reg[*] u_glide*/glide_y_reg[*]}]
set heading_cells [get_cells -quiet {u_position_logic/u_bike_move*/heading_reg[*]}]
set pend_cells    [get_cells -quiet {u_pos_link/pend*_reg[*]}]
set tgl_cells     [get_cells -quiet {u_pos_link/pos_tgl_reg u_pos_link/u_sync_2ff/meta_reg}]
emit $out/pos_link_cells.txt "[llength $bike_cells] glide_x/y: [lsort $bike_cells]\n[llength $heading_cells] heading: [lsort $heading_cells]\n[llength $pend_cells] pend*: [lsort $pend_cells]\n[llength $tgl_cells] toggle: [lsort $tgl_cells]"
if {[llength $bike_cells] == 0} {
    error "game_top_timing.xdc: el set_max_delay de pos_link no encuentra los registros glide_x/glide_y de bike_glide"
}
if {[llength $heading_cells] == 0} {
    error "game_top_timing.xdc: el set_max_delay de pos_link no encuentra los heading_reg de bike_move"
}
if {[llength $pend_cells] == 0} {
    error "game_top_timing.xdc: el set_max_delay de pos_link no encuentra los registros pend* de pos_link"
}
if {[llength $tgl_cells] != 2} {
    error "game_top_timing.xdc: el set_max_delay del toggle de pos_link deberia encontrar pos_tgl_reg y meta_reg, no [llength $tgl_cells] celdas"
}
# Los dos set_max_delay de seg7_link cubren sus 26 bits. Los numeros quedan en seg7_link_cells.txt.
set link_report {}
foreach {what pattern want} {toggle u_seg7_link/tick_toggle_reg 1 sync u_seg7_link/u_sync_toggle/meta_reg 1
        values_juego {u_seg7_link/values_juego_reg[*]} 26 values_pix {u_seg7_link/values_pix_reg[*]} 26} {
    set cells [get_cells -quiet $pattern]
    lappend link_report "$what: [llength $cells] of $want"
    if {[llength $cells] != $want} {
        error "game_top_timing.xdc: el set_max_delay de seg7_link encuentra [llength $cells] celdas en $pattern, se esperaban $want"
    }
}
emit $out/seg7_link_cells.txt [join $link_report \n]
# Los cuatro set_max_delay del cruce de la arena: igual, cada lado debe existir. Los numeros
# quedan en arena_link_cells.txt.
set arena_report {}
foreach {what pattern} {heads_tgl u_arena_link/heads_tgl_ff_reg
        heads_tgl_sync u_arena_ctrl/u_sync_heads_tgl/meta_reg
        heads {u_arena_link/prepare_reg u_arena_link/old_head_p*_reg[*] u_arena_link/new_head_p*_reg[*]}
        reseed u_arena_link/reseed_reg
        heads_pix {u_arena_ctrl/*_pix_reg*}
        codes_tgl u_arena_ctrl/codes_tgl_ff_reg codes_tgl_sync u_arena_link/u_sync_codes_tgl/meta_reg
        codes_pix {u_arena_ctrl/codes_reg[*]} codes_juego {u_arena_link/codes_reg[*]}} {
    set cells [get_cells -quiet $pattern]
    lappend arena_report "$what: [llength $cells]"
    if {[llength $cells] == 0} {
        error "game_top_timing.xdc: el set_max_delay de la arena no encuentra $pattern"
    }
}
emit $out/arena_link_cells.txt [join $arena_report \n]
# Los tres set_max_delay de uart_link: cada patron debe encontrar todos sus bits, no solo
# alguno (un registro absorbido por otro dejaria bits sin restriccion, como en el issue #54).
# Los numeros quedan en uart_link_cells.txt.
set uart_report {}
foreach {what pattern want} {cmd_tgl u_uart_link/cmd_tgl_reg 1 cmd_tgl_sync u_uart_link/u_sync_cmd/meta_reg 1
        ack_tgl u_uart_link/ack_tgl_reg 1 ack_tgl_sync u_uart_link/u_sync_ack/meta_reg 1
        cmd_pix {u_uart_link/cmd_pix_reg[*]} 5 cmd_juego {u_uart_link/cmd_juego_reg[*]} 5} {
    set cells [get_cells -quiet $pattern]
    lappend uart_report "$what: [llength $cells] of $want"
    if {[llength $cells] != $want} {
        error "game_top_timing.xdc: el set_max_delay de uart_link encuentra [llength $cells] celdas en $pattern, se esperaban $want"
    }
}
emit $out/uart_link_cells.txt [join $uart_report \n]

# Lista de reportes de CS-256 Official FPGA Coding Practices.
foreach cmd {report_clocks report_clock_networks report_clock_utilization report_clock_interaction report_exceptions report_methodology report_drc} {
    $cmd -file $out/$cmd.rpt
}
report_utilization -hierarchical -file $out/report_utilization.rpt
report_exceptions -ignored -file $out/exceptions_ignored.rpt
report_cdc -details -file $out/report_cdc.rpt
check_timing -verbose -file $out/check_timing.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file $out/timing_summary.rpt
# El bitstream solo se publica en OUT_DIR si pasa todo, al final del script. Sin game_top.bit
# no hay build valido.
# Las entradas asincronas (false path) y las salidas VGA no llevan retardo a proposito;
# cualquier otra cosa sin reloj o sin restriccion detiene el build.
set f [open $out/check_timing.rpt]; set checks [read $f]; close $f
foreach item {no_clock constant_clock pulse_width_clock unconstrained_internal_endpoints multiple_clock generated_clocks loops partial_input_delay partial_output_delay latch_loops} {
    if {![regexp "checking $item \\(0\\)" $checks]} {error "check_timing: $item no es 0 (ver check_timing.rpt)"}
}
if {![regexp {There are 0 input ports with no input delay specified} $checks]} {
    error "check_timing: hay entradas sin false path ni retardo (ver check_timing.rpt)"
}
set f [open $out/timing_summary.rpt]; set timing [read $f]; close $f
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "routed timing failed"}
close_project
}

# Se espera a los testbenches aunque falle el build, para que ninguno siga corriendo en la
# carpeta despues de terminar, y se reportan los dos errores.
set build_failed [catch {if {$mode eq "full"} {build_bitstream}} build_error]
set bench_failed [catch {wait_benches} bench_error]
if {$build_failed && $bench_failed} {puts $bench_error}
if {$build_failed} {error $build_error}
if {$bench_failed} {error $bench_error}
if {$mode ne "full"} {exit}
file copy $out/project/game_top.runs/impl_1/game_top.bit $out/game_top.bit
emit $out/BUILD_COMPLETE.txt "All testbenches pass; routed timing met; game_top.bit written. Read the reports for sign-off."
