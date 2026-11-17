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

## Las posiciones dibujadas cruzan de clk_juego a clk_pix SIN cruce explicito (por eso una
## moto a veces se corta; X1 lo resuelve, issue de X1). drawcon lee draw_x/draw_y de cada
## bike_glide, que son registros (ADR 0010). Esto limita el retardo a un pixel; no hace seguro
## el cruce. build_game_top.tcl revisa que el origen no quede vacio.
set_max_delay -datapath_only 11.982 -from [get_cells {u_glide*/draw_*_reg[*]}] -to [get_cells {u_vga_out/pix_*_reg[*]}]

## drawcon (PR #35) tambien calcula la direccion de cada bike_rom (una BRAM por moto, en clk_pix)
## con esas posiciones y con heading_reg de bike_move (clk_juego), sin cruce explicito (X1, issue
## #30). Mismo limite de un pixel; build_game_top.tcl revisa los origenes y las 2 BRAM.
set_max_delay -datapath_only 11.982 -from [get_cells {u_glide*/draw_*_reg[*] u_position_logic/u_bike_move*/heading_reg[*]}] -to [get_cells -hierarchical -filter {NAME =~ u_drawcon/bike_rom_*/* && REF_NAME =~ RAMB*}]

## Cruce de la arena (contrato, sección 3). clk_juego y clk_pix no tienen un periodo común que
## Vivado pueda expandir, así que esas rutas se tratan como asíncronas: los toggles van a
## sync_2ff y el pedido y los códigos se copian solo después de su toggle; aquí se acota su retardo.
set_max_delay -datapath_only 11.982 -from [get_cells u_arena_link/req_q_reg] -to [get_cells u_arena_ctrl/u_sync_req/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_arena_link/req_*_reg*}] -to [get_cells {u_arena_ctrl/*_q_reg*}]
set_max_delay -datapath_only 11.982 -from [get_cells u_arena_ctrl/ack_q_reg] -to [get_cells u_arena_link/u_sync_ack/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_arena_ctrl/codes_reg[*]}] -to [get_cells {u_arena_link/codes_reg[*]}]

## Cruce del marcador (seg7_link, ADR 0008): clk_juego carga los 20 bits y cambia un toggle; clk_pix
## sincroniza el toggle y copia los bits cuando lo ve cambiar. Mismo patron que la arena:
## aqui se acota el retardo del toggle y de los datos a un pixel. build_game_top.tcl revisa
## que los dos lados existan.
set_max_delay -datapath_only 11.982 -from [get_cells u_seg7_link/tick_toggle_reg] -to [get_cells u_seg7_link/u_sync_toggle/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_seg7_link/values_juego_reg[*]}] -to [get_cells {u_seg7_link/values_pix_reg[*]}]
