## Timing de game_top. Solo para implementacion: estos nombres existen despues de sintetizar.

## clk_juego sale de un flip-flop del divisor sobre clk_pix (ADR 0006):
## 83,455,882 Hz / (2 * 695466), ~60 Hz. -divide_by es 2 * CLK_JUEGO_N de game_top.sv.
## Se define a la salida del BUFG porque la Q del toggle tambien alimenta su propia D,
## y ese camino sigue en el dominio de clk_pix.
create_generated_clock -name clk_juego -source [get_pins clk_juego_toggle_reg/C] -divide_by 1390932 [get_pins u_bufg_juego/O]

## Entradas asincronas: solo hasta el primer flip-flop de cada sincronizador.
set_false_path -from [get_ports cpu_resetn] -to [get_cells {u_rst_pix/meta_reg u_rst_juego/meta_reg}]
set_false_path -from [get_ports {btn[*]}] -to [get_cells {g_btn[*].u_sync/meta_reg}]
set_false_path -from [get_ports {sw[*]}] -to [get_cells {g_sw[*].u_sync/meta_reg}]

## blkpos cruza de clk_juego a clk_pix SIN cruce explicito (por eso el bloque a veces se
## corta; X1 lo resuelve). Esto limita el retardo a un pixel; no hace seguro el cruce.
set_max_delay -datapath_only 11.982 -from [get_cells {u_position_logic/blkpos_*_reg[*]}] -to [get_cells {u_vga_out/pix_*_reg[*]}]
