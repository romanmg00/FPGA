## Author: Alan (AIF31). Changes by Roman (romanmg00): pos_link constraints (X1, #48).
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
set_false_path -from [get_ports {sw[*]}] -to [get_cells {u_sync_pause/meta_reg u_sync_goal*/meta_reg}]
set_false_path -from [get_ports uart_rx] -to [get_cells u_sync_uart/meta_reg]

## Posiciones y direcciones de las motos (X1, issue #30): pos_link cruza de clk_juego a clk_pix con
## un toggle por sync_2ff, y los valores se copian a pend*_reg solo despues del toggle, cuando llevan
## varios ciclos quietos. Como en la arena, aqui se acota su retardo a un periodo de clk_pix.
## build_game_top.tcl revisa que ningun origen ni destino quede vacio.
set_max_delay -datapath_only 11.982 -from [get_cells u_pos_link/pos_tgl_reg] -to [get_cells u_pos_link/u_sync_2ff/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_glide*/glide_x_reg[*] u_glide*/glide_y_reg[*] u_position_logic/u_bike_move*/heading_reg[*]}] -to [get_cells {u_pos_link/pend*_reg[*]}]

## Cruce de la arena (contrato, sección 3). clk_juego y clk_pix no tienen un periodo común que
## Vivado pueda expandir, así que esas rutas se tratan como asíncronas: los toggles van a
## sync_2ff, y las cabezas y los códigos se copian solo después de su toggle; aquí se acota su retardo.
## heads_tgl lleva las cabezas de arena_link a arena_ctrl (copias *_pix), con reseed de los premios
## (G4); codes_tgl devuelve los códigos.
set_max_delay -datapath_only 11.982 -from [get_cells u_arena_link/heads_tgl_ff_reg] -to [get_cells u_arena_ctrl/u_sync_heads_tgl/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_arena_link/prepare_reg u_arena_link/reseed_reg u_arena_link/old_head_p*_reg[*] u_arena_link/new_head_p*_reg[*]}] -to [get_cells {u_arena_ctrl/*_pix_reg*}]
set_max_delay -datapath_only 11.982 -from [get_cells u_arena_ctrl/codes_tgl_ff_reg] -to [get_cells u_arena_link/u_sync_codes_tgl/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_arena_ctrl/codes_reg[*]}] -to [get_cells {u_arena_link/codes_reg[*]}]

## Cruce del marcador (seg7_link, ADR 0008): clk_juego carga los 20 bits y cambia un toggle; clk_pix
## sincroniza el toggle y copia los bits cuando lo ve cambiar. Mismo patron que la arena:
## aqui se acota el retardo del toggle y de los datos a un pixel. build_game_top.tcl revisa
## que los dos lados existan.
set_max_delay -datapath_only 11.982 -from [get_cells u_seg7_link/tick_toggle_reg] -to [get_cells u_seg7_link/u_sync_toggle/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_seg7_link/values_juego_reg[*]}] -to [get_cells {u_seg7_link/values_pix_reg[*]}]

## Cruce de los comandos de P2 (uart_link, ADR 0013): clk_pix guarda el comando en cmd_pix y cambia
## cmd_tgl; clk_juego sincroniza el toggle, copia cmd_pix a cmd_juego y responde con ack_tgl.
## cmd_pix no cambia hasta que vuelve la respuesta. Mismo patron que la arena: se acota el
## retardo de los dos toggles y de los datos a un pixel. build_game_top.tcl cuenta cada lado.
set_max_delay -datapath_only 11.982 -from [get_cells u_uart_link/cmd_tgl_reg] -to [get_cells u_uart_link/u_sync_cmd/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells u_uart_link/ack_tgl_reg] -to [get_cells u_uart_link/u_sync_ack/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_uart_link/cmd_pix_reg[*]}] -to [get_cells {u_uart_link/cmd_juego_reg[*]}]
