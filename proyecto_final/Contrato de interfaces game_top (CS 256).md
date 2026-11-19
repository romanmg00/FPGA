# Contrato de interfaces: game\_top (CS 256)

Oct 11, 2026 · @Román · actualizado el 20 oct 2026 a la [especificación acordada](../docs/decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md) el 5 nov 2026 a los relojes de [ADR 0006](../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md) y el 15 nov 2026 al intervalo de paso de los ADR 0007 y 0010 y a la vista de meta del ADR 0008 · Juego: **Tron** (motos de luz, 2 jugadores) · Fuente: `cs256-project1-fall26.pdf` (las diapositivas citadas son de esa presentación)

> **Cómo leer este contrato.** Las reglas, entradas, relojes, códigos y el reparto ya siguen la especificación del 20 de octubre, que es la que manda si algo no coincide, salvo en los puntos que cambian los ADR aceptados después: el [ADR 0006](../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md) quita el segundo Clocking Wizard y la instrucción de seguir el handout al pie de la letra, el [ADR 0007](../docs/adr/0007-configurable-step-interval.md) cambia el paso fijo de 6 ticks por un intervalo configurable, y el [ADR 0008](../docs/adr/0008-scoreboard-goal-page-before-a-match.md) agrega al marcador la vista de la meta de puntos. Lo que la especificación deja como trabajo de ingeniería está marcado como **Pendiente**: ahí se anotan los requisitos, no puertos inventados. Cuando el equipo decida una de esas interfaces, se escribe aquí (y, si cambia una regla, como ADR 0003 en adelante en `docs/adr/`). La versión anterior, para 3 personas y un solo reloj, está en [`deprecated/`](deprecated/).

## 0. El juego

Dos motos de luz avanzan solas por una arena y dejan una estela permanente detrás. **P1** maneja con los botones de dirección de la placa y **P2** con W A S D en una página web que manda los comandos por USB-UART. Quien choca con una pared, con cualquier estela o con la otra moto pierde una vida y termina la ronda. Hay **tres premios** en la arena; tomarlos da puntos. Gana quien llegue primero a la meta de puntos; si no, pierde quien se queda sin vidas.

- **Partida:** 3 vidas y 0 puntos por jugador; los puntos y las vidas siguen de una ronda a otra.
- **Meta:** `{SW15, SW14}` = `00` 10 (por defecto), `01` 20, `10` 30, `11` 40. Se toma solo al empezar una partida nueva; cambiar los switches a media partida vale para la siguiente.
- **Premios:** tres a la vez, de una celda cada uno: **+1, +1 y +3**. Si solo uno choca, el otro gana **+3** de bono. Ya no hay tope de 99.
- **Start:** botón central (BTNC, N17) o Espacio/Enter en la página web; cualquiera de los dos jugadores puede darlo.
- **Pausa:** `SW0` arriba congela el juego; abajo, sigue. **Reset:** `CPU_RESETN` regresa a esperar Start.
- **Display de 7 segmentos:** los 4 dígitos de la izquierda son de P2 y los 4 de la derecha de P1. Cada 3 s cambian juntos entre `P2 nn  P1 nn` (puntos) y `L2 nn  L1 nn` (vidas), sin apagarse.
- **Después del núcleo:** primero el **marcador en pantalla** (prioridad *Should* en el plan de desarrollo). Luego, como extras (*Could*): menús, estelas de largo fijo, movimiento suave, temas y fondos con switches, brillo y scanlines. Los power-ups no entran este semestre.

**Arena en cuadrícula.** La pantalla se divide en **celdas de 16 × 16 px (80 × 50 celdas)** y el contenido de cada celda se guarda en una memoria, `arena_map`:

- **Dibujar** la arena es una lectura por píxel: `drawcon` pregunta qué hay en la celda actual y elige el color.
- **Mover** una moto son unas pocas escrituras por paso: la cabeza nueva y la cabeza vieja que pasa a estela.
- **Detectar un choque** es leer la celda a la que va a entrar la moto, antes de moverla.

Las motos (32 × 32) y los premios (16 × 16) se dibujan encima, como sprites desde ROM. Las motos van centradas en su celda de cabeza y el choque se decide por esa celda, no por el dibujo.

**Modelo de referencia.** [ADR 0004](../docs/adr/0004-shared-headless-model-base.md) selecciona `prototipos/tron_fpga/model/` como base del **único modelo de reglas sin gráficos** para ambos visores y la verificación SystemVerilog. Falta adaptar el visor de Roman para consumirlo. Las reglas acordadas siguen mandando; seleccionar la base no acepta los supuestos de timing/CDC del prototipo ni los demás puntos propuestos en ADR 0003.

## 1. Convenciones generales

- **Relojes (ADR 0002 y [ADR 0006](../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md)).** `clk` (100 MHz de la placa) solo entra al Clocking Wizard. Hay **un solo** Clocking Wizard.
  - `clk_pix`, **83.46 MHz**: `vga_out`, `drawcon`, las ROM de sprites y el servicio rápido de memoria (o un reloj rápido adecuado para la memoria; **pendiente**).
  - `clk_juego`, **~60 Hz**, de un contador de 20 bits sobre `clk_pix` que alterna un registro cada *N* ciclos; ese registro pasa por un `BUFG`. *N* sale de la frecuencia lograda: 83,455,882 / (2 × 60) ≈ 695,466. Lo acordamos con los TAs: el paso 10 del handout pide un divisor más un contador, no un segundo Clocking Wizard. Corre todo el estado del juego (movimiento, choques, rondas, vidas y puntos).
  - No es una habilitación de un cuadro dentro de `clk_pix`, y no está alineado con el borrado vertical. Todo lo que cruza entre los dos relojes necesita un cruce explícito (CDC) y se prueba.
- **Reset:** `rst` es síncrono y activo en alto dentro del diseño. `CPU_RESETN` (activo en bajo) se invierte una sola vez en `game_top` y se sincroniza en cada dominio de reloj.
- **Coordenadas de píxel:** sin signo, origen (0,0) arriba a la izquierda, x crece a la derecha, y crece hacia abajo. Área visible de 1280 × 800, con un **borde blanco de 10 px**.
- **Coordenadas de celda:** `cx` 0–79 (7 bits) y `cy` 0–49 (6 bits). De píxel a celda se pasa con un corrimiento: `cx = x >> 4`, `cy = y >> 4`. La dirección en `arena_map` es `{cy[5:0], cx[6:0]}` (13 bits, cuadrícula de 128 × 64 con relleno), sin multiplicaciones.
  - Filas `cy = 0..3`: franja de 64 px para el marcador.
  - Paredes: fila `cy = 4`, fila `cy = 49`, columnas `cx = 0` y `cx = 79` (cubren el borde de 10 px).
  - Arena jugable: **78 × 44 celdas**, `cx = 1..78`, `cy = 5..48` (píxeles `x = 16..1263`, `y = 80..783`).
  - El acomodo es una base de trabajo: se puede revisar después de probarlo, anotándolo aquí y como ADR nuevo (la especificación no se edita).
- **Tipos y nombres:** `logic`, `snake_case`, un módulo por archivo con el mismo nombre. Los anchos están en las tablas de este documento y se usan tal cual en el código. Nada de arreglos en los puertos: una señal por jugador (`_p1`, `_p2`).
- **Entradas asíncronas:** botones, switches y `uart_rx` pasan por un sincronizador de 2 flip-flops antes de usarse.

## 2. Puertos externos de `game_top`

`game_top` expone 14 pines VGA como mínimo (diapositiva 3), más las entradas de control; todo lo demás suma a la rúbrica de E/S extra. Placa: **Nexys A7-100T** (XC7A100T-1CSG324C). Los pines están en `nexys-a7-100t-master.xdc`, en la raíz del repo.

| Puerto | Dir | Ancho | Descripción | Pin |
| --- | --- | --- | --- | --- |
| `clk` | in | 1 | Reloj de la placa, 100 MHz | E3 |
| `cpu_resetn` | in | 1 | Reset, activo en bajo | C12 |
| `btn` | in | 5 | `[0]` arriba, `[1]` abajo, `[2]` izquierda, `[3]` derecha: dirección de P1. `[4]` centro: Start | M18, P18, P17, M17, N17 |
| `sw` | in | 16 | `sw[0]` pausa; `sw[15:14]` meta de puntos; los demás libres para extras | Ver XDC |
| `uart_rx` | in | 1 | Comandos de P2 y Start desde la página web, 115200 baudios, 8N1 (`UART_TXD_IN` en el XDC) | C4 |
| `vga_r`, `vga_g`, `vga_b` | out | 4 c/u | Color | Ver XDC |
| `vga_hs`, `vga_vs` | out | 1 c/u | Sincronía horizontal y vertical | Ver XDC |
| `seg` | out | 7 | Segmentos del display, activos en bajo: `seg[0]` = CA (a) … `seg[6]` = CG (g) | Ver XDC |
| `dp` | out | 1 | Punto decimal del display; siempre apagado (1) | H15 |
| `an` | out | 8 | Selección de dígito del display, activa en bajo; `an[0]` es el de la derecha | Ver XDC |
| `led` | out | 16 | Libres, para depurar | Ver XDC |

Polaridad, según el handout: `hsync` vale 0 durante las cuentas 0–135 y `vsync` vale 1 durante las cuentas 0–2.

## 3. Señales internas entre bloques

Los anchos de video salen de los contadores de la diapositiva 7: `hcnt` llega a 1679, que necesita 11 bits, y `vcnt` llega a 827, que cabría en 10. Roman y Alan acordaron (2026-10-26) usar 11 bits para los dos contadores y las dos coordenadas, para que todas las señales de posición tengan el mismo ancho y evitar errores al conectarlas.

**Video** (dominio `clk_pix`)

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `clk_pix` | Clocking Wizard → video y memoria | 1 | 83.46 MHz |
| `curr_x`, `curr_y` | `vga_out` → `drawcon` | 11 / 11 | Píxel de salida (0–1279, 0–799), alineado con la salida como en el handout |
| `draw_r`, `draw_g`, `draw_b` | `drawcon` → `vga_out` | 4 c/u | Color del píxel. Las ROM se leen con anticipación según la **latencia real** que genere Vivado (los 2 ciclos del curso son un ejemplo) |

**Juego** (dominio `clk_juego`)

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `clk_juego` | Contador de 20 bits sobre `clk_pix` → juego | 1 | ~60 Hz |
| Pasos | interno | — | Un paso cada **8** ticks de `clk_juego` (7.5 celdas/s). Por el ADR 0007 es un parámetro fijo durante el juego; el [ADR 0010](../docs/adr/0010-bikes-sliding-between-cells.md) (aceptado por Roman el 16 nov) elige 8 con las motos deslizándose: así se ve suave, y la arena cruza de reloj sin excepciones de CDC. Es `STEP_TICKS` de `game_top`, que lo pasa a `position_logic` y a `bike_glide`. Cada moto se **dibuja** deslizándose de su celda anterior a la nueva durante el paso; el juego sigue moviéndose por celdas |

**Arena y memoria** — **Propuesta** (Alan, [issue #38](https://github.com/romanmg00/FPGA/issues/38); módulos y pruebas en `arena_map.sv`, `arena_ctrl.sv` y `arena_link.sv`, conectados en `game_top` con `position_logic` y `drawcon` en el PR #40). El controlador rápido de la arena, `arena_ctrl`, es el **único que escribe** en `arena_map`; `drawcon` lee por el puerto B. Requisitos que cumple: no perder ni repetir pedidos, y que un reset no deje la memoria a medias. Faltan la colocación de premios (G4) y los puntos. La foto coherente de las motos para dibujar la hace `pos_link` (X1, issue #30, PR #48).

- **Lecturas de las vecinas, no de los destinos.** Después de cada paso el juego manda las **cabezas**, y la arena devuelve el código de las **4 celdas vecinas** de cada cabeza: arriba, derecha, abajo e izquierda (`code1_u/r/d/l`, `code2_u/r/d/l`), en el mismo orden que la dirección (0 arriba, 1 derecha, 2 abajo, 3 izquierda). En el tick del paso, `position_logic` toma la vecina hacia donde va la moto. El destino depende del giro pendiente, que puede cambiar hasta el tick del paso, y la respuesta tarda unos 3 ticks en cruzar; con las vecinas ya está la de cualquier giro. Los códigos se leen después de las escrituras del paso anterior y antes de las de este, así que siguen la regla de leer antes de escribir (sección 4, paso 2).
- **Tiempos**, con el paso en el flanco *k* de `clk_juego`:

  | Flanco | Qué pasa |
  | --- | --- |
  | *k* | Las motos se mueven; `codes_valid` baja |
  | *k*+1 | `arena_link` manda el pedido: cabezas viejas → estela, nuevas → cabeza. Una moto que no se movió (choque) tiene la misma celda vieja y nueva, y sigue siendo cabeza: la arena **no usa el código 6**. `arena_ctrl` hace las 4 escrituras y luego las 8 lecturas: 17 ciclos de `clk_pix` desde el toggle, unos 0.2 µs |
  | *k*+4 | Los 8 códigos llegan a `clk_juego`; `codes_valid` = 1 |
  | *k*+6 u *k*+8 | Siguiente paso: sobran 2 ticks con 6 y 4 con 8 |

- **Preparar la ronda:** cuando sube `load` de `round_fsm` (también al salir del reset, porque `round_fsm` arranca en `s_release`), el flanco siguiente manda una preparación: se escriben las 8192 palabras (sección 6), las dos cabezas de salida y se leen sus vecinas. Son 8,207 ciclos (98.3 µs) y los códigos llegan también 4 flancos después de la subida de `load`. Se manda un flanco después porque `bike_move` carga las salidas en el mismo flanco en que ve `load` = 1.
- **Cruce de reloj** (el patrón del issue #30, en los dos sentidos): `arena_link` alterna `req_tgl` y deja el pedido quieto hasta la respuesta; en `clk_pix`, `req_tgl` pasa por `sync_2ff` y el pedido se copia cuando el toggle sincronizado cambia. `arena_ctrl` contesta igual, con `ack_tgl` y los códigos quietos hasta el siguiente pedido. Un evento que encuentra un pedido abierto espera; con 6 u 8 ticks por paso nunca pasa.
- **Reset:** los toggles y sus sincronizadores **no se resetean** (tienen valor inicial de configuración). Si un reset corta un pedido, sigue abierto y `arena_ctrl` lo hace otra vez desde el principio: las mismas escrituras o la limpieza completa. Un reset corto que solo llega a `clk_pix` no deja la arena a medias ni da una respuesta falsa. Después de un reset del juego, la respuesta a un pedido viejo no cuenta; los códigos valen hasta la respuesta de la preparación.
- **Pausa:** la arena no tiene pausa; mientras el juego está en pausa no hay pasos, así que no hay pedidos.
- **Si `codes_valid` = 0 en el tick del paso** (propuesta para `position_logic`): el paso espera, sin perder el giro pendiente, y el `step` que se manda a `arena_link` es el paso que de verdad se dio. Con 6 u 8 ticks no pasa; solo tras un reset que corta un pedido.

**Conexión en `game_top`** (hecha en el PR #40):

```systemverilog
// clk_juego
arena_link u_arena_link (.clk(clk_juego), .rst(rst_juego),
    .load, .step,                                                  // de position_logic
    .blkpos1_x, .blkpos1_y, .blkpos2_x, .blkpos2_y,                // cabezas (celda x 16)
    .code1_u, .code1_r, .code1_d, .code1_l,
    .code2_u, .code2_r, .code2_d, .code2_l, .codes_valid,          // a position_logic
    .req_tgl, .req_prepare,
    .req_old1, .req_old2, .req_new1, .req_new2, .ack_tgl, .nbr1, .nbr2);
// clk_pix
arena_ctrl u_arena_ctrl (.clk(clk_pix), .rst(rst_pix),
    .req_tgl, .req_prepare,
    .req_old1, .req_old2, .req_new1, .req_new2, .ack_tgl, .nbr1, .nbr2,
    .a_addr, .a_we, .a_wdata, .a_rdata);
arena_map u_arena_map (.clk(clk_pix), .a_addr, .a_we, .a_wdata, .a_rdata,
    .b_addr(arena_addr), .b_rdata(arena_code));                    // puerto B: drawcon
```

`game_top_timing.xdc` tiene además estas líneas para el cruce:

```tcl
## Cruce de la arena. clk_juego y clk_pix no tienen periodo común que Vivado pueda expandir
## (divide_by 1390932), así que esas rutas se tratan como asíncronas: los toggles van a
## sync_2ff y el pedido y los códigos se copian solo después de su toggle; aquí se acota su retardo.
set_max_delay -datapath_only 11.982 -from [get_cells u_arena_link/req_q_reg] -to [get_cells u_arena_ctrl/u_sync_req/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_arena_link/req_*_reg*}] -to [get_cells {u_arena_ctrl/*_q_reg*}]
set_max_delay -datapath_only 11.982 -from [get_cells u_arena_ctrl/ack_q_reg] -to [get_cells u_arena_link/u_sync_ack/meta_reg]
set_max_delay -datapath_only 11.982 -from [get_cells {u_arena_ctrl/codes_reg[*]}] -to [get_cells {u_arena_link/codes_reg[*]}]
```

Lo que hace cada lado (en el PR #40; Roman revisa los cambios a sus módulos):

- **`position_logic`:** saca `load` y `step` (el paso que se dio) y recibe los 8 códigos y `codes_valid`. La arena no necesita `crash1`/`crash2`: una moto que chocó no se mueve, y su celda queda como cabeza. `pending_turn` es interno de `bike_move`: la vecina se elige comparando `next_cx/next_cy` con `cx/cy`. Se pasa solo a una celda con 0 (vacía) o 8–10 (premio); todo lo demás choca, también el 7 reservado. Siguen haciendo falta las comparaciones de mismo destino y de cruce entre motos, porque los códigos son de antes del paso.
- **`drawcon`:** `arena_addr = {cy[5:0], cx[6:0]}` de la celda del píxel adelantado 2, y `arena_code` llega 2 ciclos después, como las ROM. Las filas del marcador (`cy` 0–3) tienen código WALL: el marcador se dibuja por coordenadas antes de colorear por código, y el borde blanco de 10 px va encima de todo. Por código se colorean **solo las estelas** (2 y 4), con el color de su moto. Las cabezas (3 y 5) no: la cabeza se marca en el paso, y la moto se dibuja deslizándose hacia ella durante el paso siguiente (ADR 0010), así que pintarla la mostraría adelante del sprite (probado en la tarjeta el 16 nov). La moto tapa su cabeza; durante la pausa de choque, la celda de la moto que choca puede pintarse con su color cuando el estado del juego llegue a `clk_pix` (X1). El parpadeo también sale de ese estado, no del código. Si el puerto A escribe la misma celda en ese ciclo, el puerto B puede dar el código viejo o el nuevo: un píxel, nada depende de eso. Al configurar la FPGA la BRAM está en 0 (vacía) hasta la primera preparación, unos 4 ticks; un reset no la borra, así que la arena vieja se ve hasta esa preparación. La limpieza dura 98 µs, unas 5 líneas de video.
- **Premios (después):** el código de la celda elige la imagen del premio en su ROM, así que esas dos lecturas van en serie (2 + 2 ciclos) y no caben en una sola anticipación de 2 píxeles. Además, un premio colocado después de leer las vecinas cambiaría la arena entre la lectura y el paso; G4 necesita definir cuándo coloca y cómo reporta qué premio tomó cada moto.

**Entradas** — **Pendiente** en detalle.

- P1: `btn_debounce` entrega pulsos de los botones; se respeta el orden en que se muestrean. Si dos pedidos válidos caen en la misma muestra, gana **UP > RIGHT > DOWN > LEFT** (esto no da prioridad a ningún jugador).
- P2 y Start remoto: `uart_rx` entrega bytes; un decodificador los convierte en pedidos de giro y Start, en el orden en que llegan. El código de Enter en el cable está **pendiente**.
- Los pedidos cruzan al dominio `clk_juego` sin perderse y en orden.

**Juego → video y display** — Video **pendiente**: el juego entrega la posición y dirección de cada moto (ya en `pos_link`, PR #48), si parpadea por el choque y los tres premios. Los anchos de los puntos deben aguantar el total del último paso sin desbordarse (por ejemplo, 39 + 3 + 3).

Display (Paso 7d): `score_unit` y `seg7_view` en `clk_juego` → `seg7_link` → `seg7_driver` en `clk_pix`. Cada tick, `seg7_link` carga 20 bits (puntos 6 + 6, vidas 2 + 2, vista 2 y meta 2) y cambia un toggle; en `clk_pix` el toggle pasa por `sync_2ff` y los 20 bits se copian cuando cambia, el mismo patrón que la respuesta de la arena. El toggle y su sincronizador no se resetean. `game_top_timing.xdc` acota las dos rutas a un píxel y `build_game_top.tcl` revisa que existan.

## 4. Interfaz módulo por módulo

Cada módulo tiene un responsable (sección 7) y los puertos de abajo son su contrato: si alguien necesita cambiarlos, avisa al equipo antes de tocar el código. Los que dicen **propuesta** todavía se pueden ajustar al revisar este contrato.

| Módulo | Resp. | Qué hace | Estado |
| --- | --- | --- | --- |
| Clocking Wizard + contador de `clk_juego` | Roman | `clk_pix` de 83.46 MHz; `clk_juego` de ~60 Hz desde un contador sobre `clk_pix` (ADR 0006) | Un solo Wizard en el código desde el 5 nov: testbenches y temporización ruteada pasan; falta probar el bitstream en la tarjeta |
| `vga_out` | Roman | Contadores, pulsos de sync, blanking y `curr_x`/`curr_y` | Escrito; `vga_out_tb` pasa en XSim. Falta decidir `tick_60hz` |
| `drawcon` | Roman | Color de cada píxel: borde, arena, premios y motos | Paredes, HUD y dos motos en colores planos (PR #25); estelas desde `arena_map` (PR #40); faltan premios, sprites y borde de 10 px |
| `pos_link` | Roman | Lleva a `clk_pix` las posiciones dibujadas y las direcciones de las motos, una vez por cuadro (X1) | `pos_link_tb` pasa en XSim; en `game_top`, `report_cdc` sin filas críticas y temporización ruteada cumplida (PR #48). Falta probarlo en la tarjeta |
| `sprite_rom` | Roman | Motos de 32 × 32 (1024 palabras) y premios de 16 × 16 (256 palabras), `.coe` RGB444 | Por hacer |
| Movimiento y choques (G1/G2) | Roman | Giros, giro pendiente, lectura de las dos celdas destino y resultado de cada moto | Dos motos con giros, giro pendiente y choques con pared y entre motos en `position_logic` (PR #25); choque con estelas por las vecinas de `arena_map` (PR #40). Faltan los premios |
| Rondas, partida, vidas y puntos (G3/G5) | Alan | Estados de la partida, Start, choque, meta, bono y empate | `match_fsm` (estados de la partida, Start, reinicio de `position_logic`) y `score_unit` (vidas, bono, fin de partida y empate) con sus pruebas (PR #46), conectados en `game_top` (Paso 7d); `match_tb` juega partidas enteras. `round_fsm` de Roman sigue dentro de `position_logic` y recibe Start de `match_fsm`. Faltan la meta y los premios (G4) y el parpadeo del choque (X1) |
| `arena_map` + controlador (A1/A2) | Alan | BRAM de 8192 × 4 bits y servicio de pedidos del juego | `arena_map`, `arena_ctrl` y `arena_link` con sus pruebas (propuesta, sección 3); conectados en `game_top` (PR #40) y probados en la tarjeta el 16 nov |
| Premios (G4) | Alan | Generador pseudoaleatorio y colocación de los tres premios | Por hacer; generador **pendiente** |
| `btn_debounce` | Alan | Sincroniza los 5 botones, quita rebotes y genera un pulso al presionar | Por hacer |
| `uart_rx` + decodificador | Alan | Bytes de la UART a pedidos de giro de P2 y Start | Por hacer; Enter **pendiente** |
| Página web de control | Alan | WASD, Espacio/Enter por Web Serial | Por hacer |
| `seg7_driver` | Alan | Display alternado de puntos y vidas; meta de puntos antes de una partida (ADR 0008) | `sevenseg` y `multidigit` (tarea 1 del curso, con P, L, G, A y blanco; barrido en `clk_pix` con habilitación), `seg7_view` y `seg7_driver` pasan en XSim (Pasos 7a y 7b). En `game_top` desde el Paso 7d, con `seg7_link` como cruce a `clk_pix`; `game_top_tb` lee los dígitos de los pines. Probado en la tarjeta el 17 nov |
| `game_top` + XDC | Alan | Instancia y conecta todo; relojes, reset, pines, automatización del build | Conecta el Wizard, el contador de `clk_juego`, los sincronizadores, las motos, la arena, la partida y el marcador; `build_game_top.tcl` corre las pruebas (`quick`, `sim`) y construye el bitstream (`full`). Faltan la UART y los LED |
| Marcador en pantalla (`texto_capa`, `font_rom`) | Roman | Puntos y vidas en la franja de 64 px, con texto de 32 px | Después del núcleo (*Should*) |

Los testbenches oficiales de cada módulo los escribe la otra persona (sección 7).

**`vga_out`** (Roman)

```systemverilog
module vga_out (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [10:0] curr_x,
    output logic [10:0] curr_y,
    output logic        tick_60hz,   // pendiente: con ADR 0002 el juego usa clk_juego
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync
);
```

Un cuadro dura 1680 × 828 = 1,391,040 ciclos de `clk_pix` (~60 Hz). Con el ADR 0002 el reloj del juego sale del divisor, así que `tick_60hz` ya no mueve el juego; hay que decidir si se queda como señal de video (por ejemplo, para animaciones de `drawcon`) o se quita. Hoy vale 0 en `vga_out.sv`.

**`drawcon`** (Roman). Sigue el dibujo combinacional del handout, con coordenadas alineadas a la salida. Capas, de abajo hacia arriba: fondo, arena (paredes y estelas en el color de su jugador), premios, motos y, más adelante, el marcador. El **borde blanco de 10 px va encima de todo**: ninguna capa lo tapa. Las paredes lo cubren en la arena, y una moto de 32 × 32 centrada en una celda de la orilla (por ejemplo `cx = 1`) se sale hasta los píxeles `x = 8..9`; esa parte del sprite se recorta. Una moto que chocó parpadea en su última celda válida durante la pantalla de choque. Los puertos hacia la arena y el juego dependen de la sección 3 (**pendiente**).

**`pos_link`** (Roman, X1, [issue #30](https://github.com/romanmg00/FPGA/issues/30)). Lleva a `clk_pix` las posiciones dibujadas (`glide*` de `bike_glide`) y las direcciones (`heading*` de `position_logic`): 48 bits. En `clk_juego`, `pos_tgl` se invierte en cada tick. En `clk_pix`, pasa por `sync_2ff`; cuando cambia, los 48 bits se copian a `pend*`, y en `curr_y == 800` pasan a `draw*`, que es lo que lee `drawcon`. Así todo un cuadro se dibuja con las mismas posiciones (sin cortes) y nunca con bits mezclados. Después de un reset, las posiciones de salida llegan a `drawcon` en hasta dos cuadros. `rst_pix` pone `pend*` y `draw*` en 0, así que hasta la primera copia `drawcon` recibe 0, nunca un valor indefinido. La copia a `pend*` supone que los 48 bits cambian solo en el flanco de `clk_juego` que invierte `pos_tgl` y quedan quietos todo el tick (~16.7 ms), mucho más que los 3 a 4 ciclos de `clk_pix` que tarda el toggle en cruzar.

**Sprites.** Datos `.coe` de 12 bits RGB444 al tamaño real: 1024 palabras por moto y 256 por premio. `000` es transparente y `0F0` se reemplaza por el color del jugador (P1 cian, P2 naranja). No hay clave especial `080` de brillo en el formato base. La ROM puede guardar la moto mirando hacia arriba y sacar las otras direcciones intercambiando e invirtiendo bits de la dirección.

**`arena_map`** (Alan). Latencia: **1 ciclo** en el puerto A y **2** en el puerto B (sección 3)

```systemverilog
module arena_map (
    input  logic        clk,            // reloj rápido de memoria (pendiente; clk_pix o uno adecuado)
    // Puerto A: controlador de la arena (lee y escribe)
    input  logic [12:0] a_addr,
    input  logic        a_we,
    input  logic [3:0]  a_wdata,
    output logic [3:0]  a_rdata,         // 1 ciclo
    // Puerto B: drawcon (solo lee)
    input  logic [12:0] b_addr,
    output logic [3:0]  b_rdata          // 2 ciclos, como las ROM de sprites
);
```

Lectura síncrona en los dos puertos, para que Vivado la infiera como BRAM (8192 × 4 = 32 Kb). `clk` es `clk_pix` en los dos puertos. Una BRAM no se puede poner en cero con `rst`: el controlador la limpia al preparar cada ronda (sección 6). Los puertos de `arena_ctrl` y `arena_link` están en sus archivos y en la conexión de la sección 3.

**Movimiento y choques** (Roman) y **rondas y puntos** (Alan). Corren en `clk_juego`. Cada paso:

1. **Giros:** se guarda **un solo giro pendiente**, el último pedido válido contra la dirección actual; uno nuevo reemplaza al anterior. Los giros de 180° y los que repiten la dirección se ignoran sin borrar el pendiente. Fuera del juego (pantalla de choque, espera de Start, pausa) se ignoran.
2. **Lecturas:** se leen las dos celdas destino **antes de escribir nada**. Chocar con pared, con cualquier estela o con la otra moto es fatal. Ir a la misma celda o cruzarse es choque para las dos.
3. **Escrituras:** si ninguna choca, en cada moto la cabeza vieja pasa a estela y se escribe la nueva; puede tomar un premio. Si alguna choca, **ninguna se mueve** en ese paso ([ADR 0011](../docs/adr/0011-a-crash-stops-both-bikes.md), propuesto): la que chocó se queda en su **última celda válida** y pierde una vida, y la otra se queda en su celda sin tomar premio.
4. **Puntos:** premio tomado (+1, +1 o +3) y bono de +3 si solo el otro chocó. Después se revisa la meta.
5. **Fin:** si alguien llegó a la meta, termina la partida. Si los dos, gana el de más puntos; con los mismos puntos es empate. Si nadie llegó y los dos perdieron su última vida en el mismo paso, se decide igual por puntos.

El movimiento reporta qué pasó con cada moto; rondas y puntos es dueño del ciclo de la partida, las vidas y los puntos. Los registros de cada dueño quedan explícitos.

**Puertos de `position_logic` hacia la partida** (Roman, [issue #44](https://github.com/romanmg00/FPGA/issues/44)). Se suman a los de hoy (botones, `turn_req2`, posiciones, direcciones y la conexión con la arena de la sección 3). Son aditivos: con `pause` y `match_over` en 0, `position_logic` funciona como antes, y así los conecta `game_top` hasta que entren `match_fsm` y `score_unit`.

```systemverilog
    input  logic pause,              // SW0 sincronizado: sin pasos ni giros; la pausa de choque se detiene
    input  logic match_over,         // de score_unit: la partida terminó; round_fsm se queda en s_crash
    output logic crash1, crash2,     // choque de cada moto, en el tick del paso
    output logic crash_done,         // fin de los 2 s de choque (u_crash_timer)
```

- **Pausa:** los dos `step_counter` (pasos y choque) congelan su cuenta y no dan pulso, y `bike_move` recibe `run && !pause`, así que no guarda giros. La ronda sigue en su estado. Al quitar la pausa, la cuenta sigue donde iba.
- **Fin de partida:** `round_fsm` recibe `t = crash_done && !match_over`. Después del choque que termina la partida, se queda en `s_crash`: las motos y las estelas quedan como chocaron, y no se prepara otra ronda. Sale solo con `rst` (el `restart` de `match_fsm`).
- **Start** sigue entrando por `btn[4]`; con la partida, `match_fsm` lo manda como pulso de 1 tick.

**`step_counter`** (Roman) agrega `input logic pause`. Prioridad: `rst || !run` reinicia, `pause` mantiene la cuenta, la última cuenta vuelve a 0 y si no cuenta. `step = (counter == LAST) && !pause`.

**Estados de la partida** (nombres en `game_pkg.sv`, propuesta):

- `G_IDLE`: al encender, espera Start. Start toma la meta, pone 3 vidas y 0 puntos, prepara paredes, motos y los **tres** premios, y arranca la primera ronda, sin cuenta regresiva.
- `G_PLAY`: un paso cada `STEP_TICKS` ticks (8, ADR 0007 y ADR 0010).
- `G_CRASH`: choque que no termina la partida: el juego se congela y las motos chocadas parpadean **~2 s**; Start y los giros se ignoran. Luego se prepara la siguiente ronda y se pasa a `G_READY`.
- `G_READY`: espera un Start nuevo, sin giros previos ni cuenta regresiva.
- `G_MATCH`: fin de la partida, con puntos y vidas finales. Si terminó por choque, primero se muestran los 2 s de choque. Un Start nuevo prepara y arranca otra partida.
- La pausa (`SW0`) congela cualquier estado y los temporizadores del juego; el video y el display siguen.

**`match_fsm`** (Alan, Paso 7d) implementa estos estados con los códigos 0–4 de arriba (`G_IDLE` 0, `G_PLAY` 1, `G_CRASH` 2, `G_READY` 3, `G_MATCH` 4) y tres estados de 1 tick para una partida nueva: 5 `G_NEW` (`new_match` y `restart`: `score_unit` a 0 puntos y 3 vidas, `position_logic` al reset), 6 `G_GO` (Start en 0 un tick, para que `round_fsm` salga de `s_release`) y 7 `G_START` (Start de 1 tick a `round_fsm`). Desde `G_READY` se pasa directo a `G_START`. Un Start es un flanco de subida de BTNC: un botón sostenido durante `CPU_RESETN`, durante la pausa o durante los 2 s de choque no cuenta. Los 2 s los mide el temporizador de choque de `round_fsm` (`crash_done`); al terminar la partida, `match_over` deja a `round_fsm` en `s_crash`. Todavía sin parpadeo (X1, issue #30) y, sin premios, sin meta alcanzable (máximo 9 puntos).

**Premios** (Alan) — generador **pendiente**. Tres espacios independientes (+1, +1, +3). Los tres iniciales se preparan antes de soltar la ronda. Al tomar uno, el reemplazo puede tardar mientras el hardware busca; el juego sigue. Un premio solo va en una celda jugable vacía (sin pared, estela, moto, marcador ni otro premio) y se revalida antes de escribirlo si el juego cambió. Si no hay celda libre, ese espacio queda vacío hasta la siguiente ronda. La colocación es pseudoaleatoria, con semilla que depende de cuándo se presiona Start y un modo de semilla fija para pruebas. El modelo y el HDL usarán la misma secuencia y el mismo calendario cuando se elijan.

**`btn_debounce`** (Alan)

```systemverilog
module btn_debounce (
    input  logic       clk,
    input  logic       rst,
    input  logic [4:0] btn,                // directo de los pines
    output logic [4:0] btn_pulse           // 1 ciclo al presionar
);
```

**`uart_rx`** (Alan, propuesta)

```systemverilog
module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,                 // uart_rx, ya sincronizado
    output logic [7:0] rx_byte,
    output logic       rx_valid            // pulso de 1 ciclo
);
```

115200 baudios, 8N1. El decodificador de bytes a pedidos (W A S D, Espacio, Enter) y su cruce a `clk_juego` están **pendientes**.

**`seg7_driver`** (Alan, propuesta). Los 8 dígitos, de izquierda a derecha: P2 en `an[7:4]` y P1 en `an[3:0]`. Cada lado muestra dos letras y dos dígitos decimales: `P2 nn  P1 nn` durante 3 s y `L2 nn  L1 nn` durante 3 s, los dos lados juntos y sin apagarse. Mientras se espera una partida nueva (antes de la primera y al terminar una), se agrega una tercera vista, `GOAL  nn` en los 8 dígitos (`GOAL` en el lado de P2, dos dígitos en blanco y la meta que tomaría Start: 10, 20, 30 o 40), y las vistas rotan puntos → vidas → meta, 3 s cada una. Mover `{SW15, SW14}` en esa espera salta a la vista de meta y reinicia sus 3 s. Durante la partida solo se alternan puntos y vidas ([ADR 0008](../docs/adr/0008-scoreboard-goal-page-before-a-match.md)). Una partida nueva empieza en la vista de puntos. El multiplexado rápido de dígitos es aparte del temporizador de 3 s. El decodificador del proyecto necesita las letras P, L, G y A (la O es el mismo glifo que el 0); la referencia de la tarea del curso no se toca.

Se arma con los módulos de la tarea 1 del curso, en copias del proyecto y con el mismo estilo (números con un comentario, sin paquetes ni constantes con nombre). `sevenseg` recibe `num` de 4 bits como en la tarea: 0–9 son los dígitos y, en lugar de las letras hex A–F, 10–13 son P, L, G y A, y 14–15 quedan en blanco. `multidigit` conserva el contador `sel` de 3 bits, el mux 8:1 y el decodificador 3:8 de la tarea, con `dig0`..`dig7` de 4 bits (`dig0` a la derecha) y `a`..`g` y `an` activos en bajo. La tarea usaba el bit 16 de un contador de 17 bits como reloj; aquí ese contador corre en `clk_pix` y `sel` pasa al siguiente dígito cada vez que se llena (ADR 0006: sin relojes nuevos). Son 2^17 ciclos, 1.57 ms por dígito y 12.6 ms por vuelta de los 8. En `game_top`, `seg[0]` es `a` y `seg[6]` es `g`.

**`seg7_view`** (Alan, propuesta). En `clk_juego`, elige la vista cada `VIEW_TICKS` ticks (180, ~3 s) con las reglas de arriba. Las vistas son 0 puntos, 1 vidas y 2 meta, los mismos números en `seg7_driver`. Sigue a `PageTimer` del modelo (`prototipos/tron_fpga/model/seg7.py`). No tiene entrada de pausa, así que las vistas siguen durante la pausa, el choque y la espera de ronda. Si al salir del reset los switches de la meta no están en `00`, su valor sincronizado cambia y aparece la vista de meta, como en el modelo.

```systemverilog
module seg7_view #(
    parameter int VIEW_TICKS = 180                 // ~3 s
) (
    input  logic       clk,                        // clk_juego
    input  logic       rst,
    input  logic       new_match,                  // 1 en el tick en que Start empieza una partida nueva
    input  logic       waiting,                    // esperando una partida nueva (G_IDLE o G_MATCH)
    input  logic [1:0] goal_sel,                   // {SW15, SW14} sincronizados
    output logic [1:0] view                        // 0 puntos, 1 vidas, 2 meta
);
```

**`seg7_driver`** (Alan, propuesta). En `clk_pix`, arma los 8 dígitos de la vista y los barre con `multidigit`. Las entradas tienen que llegar a `clk_pix` como registros que cambian juntos: el cruce desde `clk_juego` va en `game_top`, con el mismo patrón que el issue #30. Los puntos usan 6 bits porque el total legal más alto es 45 (39 + 3 + 3).

```systemverilog
module seg7_driver #(
    parameter int COUNT_BITS = 17                  // contador del barrido de multidigit
) (
    input  logic       clk,                        // clk_pix
    input  logic       rst,
    input  logic [5:0] points_p1, points_p2,       // 0-45 en una partida
    input  logic [1:0] lives_p1, lives_p2,         // 0-3
    input  logic [1:0] view,                       // de seg7_view: 0 puntos, 1 vidas, 2 meta
    input  logic [1:0] goal_sel,                   // {SW15, SW14}
    output logic [6:0] seg,                        // seg[0] = a ... seg[6] = g, activo en bajo
    output logic [7:0] an                          // activo en bajo; an[0] es el dígito de la derecha
);
```

**`game_top`** (Alan) conecta el Clocking Wizard y el contador de `clk_juego`, los dos puertos de `arena_map`, sincroniza botones, switches y `uart_rx`, e invierte `cpu_resetn`. Cada quien agrega la instancia de sus propios módulos.

## 5. Constantes compartidas (`game_pkg.sv`)

Todos leen tamaños, códigos y tablas desde un solo archivo. Si cada quien escribe sus números, el dibujo, la lógica y los testbenches se desfasan. El modelo de reglas usará los mismos valores.

```systemverilog
package game_pkg;

    // Timing VGA 1280x800 (diapositiva 7)
    localparam int H_SYNC = 136, H_BP = 200, H_ACTIVE = 1280, H_FP = 64;
    localparam int H_TOTAL = H_SYNC + H_BP + H_ACTIVE + H_FP;      // 1680
    localparam int V_SYNC = 3, V_BP = 24, V_ACTIVE = 800, V_FP = 1;
    localparam int V_TOTAL = V_SYNC + V_BP + V_ACTIVE + V_FP;      // 828
    localparam int BORDER_PX = 10;                                 // borde blanco

    // Cuadrícula: celdas de 16x16 px
    localparam int TILE_SHIFT = 4;
    localparam int GRID_W = 80, GRID_H = 50, HUD_ROWS = 4;         // 64 px de marcador
    localparam int CX_W = 7, CY_W = 6, ADDR_W = 13;               // dirección = {cy, cx}
    localparam int PLAY_CX_MIN = 1, PLAY_CX_MAX = 78;             // 78 x 44 celdas jugables
    localparam int PLAY_CY_MIN = 5, PLAY_CY_MAX = 48;

    // Contenido de una celda (igual en el modelo y en el HDL)
    localparam logic [3:0] CELL_EMPTY    = 4'd0;
    localparam logic [3:0] CELL_WALL     = 4'd1;
    localparam logic [3:0] CELL_P1_TRAIL = 4'd2;
    localparam logic [3:0] CELL_P1_HEAD  = 4'd3;
    localparam logic [3:0] CELL_P2_TRAIL = 4'd4;
    localparam logic [3:0] CELL_P2_HEAD  = 4'd5;
    localparam logic [3:0] CELL_CRASH    = 4'd6;
    localparam logic [3:0] CELL_RESERVED = 4'd7;
    localparam logic [3:0] CELL_REWARD0  = 4'd8;
    localparam logic [3:0] CELL_REWARD1  = 4'd9;
    localparam logic [3:0] CELL_REWARD2  = 4'd10;

    // Direcciones: girar a la derecha = sumar 1 (mod 4)
    localparam logic [1:0] DIR_UP = 2'd0, DIR_RIGHT = 2'd1, DIR_DOWN = 2'd2, DIR_LEFT = 2'd3;

    // Estados de la partida (propuesta, sección 4)
    localparam logic [2:0] G_IDLE = 3'd0, G_PLAY = 3'd1, G_CRASH = 3'd2, G_READY = 3'd3, G_MATCH = 3'd4;

    // Botones
    localparam int BTN_U = 0, BTN_D = 1, BTN_L = 2, BTN_R = 3, BTN_C = 4;

    // Reglas (en ticks de clk_juego, ~60 Hz)
    localparam int STEP_TICKS     = 8;     // un paso cada 8 ticks (ADR 0007, ADR 0010: prueba en la tarjeta)
    localparam int LIVES_START    = 3;
    localparam int REWARD_PTS0    = 1, REWARD_PTS1 = 1, REWARD_PTS2 = 3;
    localparam int SURVIVAL_BONUS = 3;
    localparam int CRASH_TICKS    = 120;   // ~2 s de parpadeo
    localparam int SCORE_VIEW_TICKS = 180; // ~3 s por vista del display
    // Meta según {SW15, SW14}: 10, 20, 30, 40

    // Salidas: P1 en (20, 27) hacia la derecha, P2 en (59, 27) hacia la izquierda
    localparam logic [6:0] SAL_P1_CX = 7'd20, SAL_P2_CX = 7'd59;
    localparam logic [5:0] SAL_CY    = 6'd27;

    // Sprites RGB444
    localparam logic [11:0] COLOR_TRANSPARENT = 12'h000;
    localparam logic [11:0] COLOR_TINT_KEY    = 12'h0F0;

endpackage
```

Nadie ha compilado este paquete. Corre una síntesis rápida en Vivado al agregarlo.

**Quién edita `game_pkg.sv`:** Roman fija los tiempos VGA, el borde, los sprites y los colores; Alan, la cuadrícula, los códigos de celda y las reglas de la partida. Los dos acuerdan los estados. Un cambio no se da por bueno hasta que pasan los testbenches de los módulos que lo usan.

## 6. Reglas de integración y puntos de fricción

Estos son los errores que más suelen romper la integración entre módulos escritos por personas distintas.

- **Un solo escritor en `arena_map`:** solo el controlador rápido escribe, por el puerto A. `drawcon` solo lee, por el puerto B.
- **Dos relojes:** el juego corre en `clk_juego` y la memoria y el video en un reloj rápido. Ningún pedido, resultado o foto para dibujar cruza sin un CDC explícito; se prueban colisiones de lectura y escritura, la latencia, la contrapresión, el reset y la pausa. No se supone que el reloj de juego cae en el borrado vertical.
- **Primero leer, luego escribir:** en cada paso se leen las dos celdas destino antes de cualquier escritura. Si se procesa una moto completa y luego la otra, el resultado depende del orden y los choques de frente salen mal.
- **Giro de 180°:** se compara contra la dirección actual de la moto, no contra la última tecla. Así, arriba y luego izquierda rápido, entre dos pasos, no deja que la moto se dé la vuelta sobre su estela.
- **Limpiar la arena:** al preparar cada ronda, el controlador recorre las 8192 direcciones: `CELL_EMPTY` solo en las celdas jugables (`cx` 1–78, `cy` 5–48) y `CELL_WALL` en todas las demás, también las filas del marcador y el relleno (3,432 vacías y 4,760 paredes, como `clear_word` del modelo). Antes decía vacía salvo las paredes; con WALL, cualquier lectura fuera de lo jugable choca. Tarda 8,192 ciclos de `clk_pix` (98 µs).
- **Restar sin signo en el borde:** `cx = 0` menos 1 da 127, no -1. Las paredes impiden llegar ahí, pero el cálculo no debe depender de eso.
- **Asignaciones:** `always_ff` usa `<=` (non-blocking) y `always_comb` usa `=`. En `always_comb` todas las ramas deben asignar todas las salidas; si no, Vivado infiere un latch.
- **Latencia de las ROM:** las lecturas empiezan con la anticipación que pide la latencia real de la IP generada; los 2 ciclos del curso son un ejemplo.
- **Blanking:** fuera del área visible los tres canales de color valen 0. Lo fuerza `vga_out`.
- **Probar `vga_out` primero:** en simulación, `hsync` dura 136 ciclos, una línea dura 1680, un cuadro dura 828 líneas y el color es 0 fuera de los 1280 × 800 visibles. Sin esto, el resto del diseño no se puede depurar (diapositiva 25).
- **Cambios al contrato:** cualquier cambio de nombre, ancho o significado de una señal se anota en este documento y se avisa antes de modificar el código. Un cambio de regla va además como ADR nuevo.

## 7. Reparto entre 2 personas

El equipo es **Roman y Alan**. Los dos diseñan módulos y escriben testbenches; 30 de los 40 puntos son individuales (pre-demo y reporte), así que cada quien tiene diseño propio que mostrar y explicar.

| Persona | Diseña |
| --- | --- |
| **Roman** | Clocking Wizard y video (`vga_out`), `drawcon`, ROM de sprites y, después, el marcador en pantalla; en el juego, movimiento, giros y choques (G1/G2) |
| **Alan** | Rondas, partida, vidas y puntos (G3/G5); arena y memoria rápida, colocación de premios (A1/A2/G4); botones, UART y página web, display; `game_top`, restricciones y automatización del build; modelo de reglas compartido y adaptadores de los visores |
| **Los dos** | Este contrato, el límite entre juego, servicio y dibujo, integración y pruebas en la placa, testbenches oficiales de los bloques del otro, revisión de timing, CDC y DRC, y la evidencia de cada reporte |

**Reglas de trabajo**

- Cada dueño hace pruebas rápidas de su propio módulo mientras lo escribe.
- Cada quien escribe los testbenches **oficiales** de los bloques del otro, partiendo de **este contrato** y no del código. Si los dos entienden distinto una señal, el testbench lo detecta antes de llegar a la placa.
- Un módulo se considera terminado cuando pasa su testbench oficial. Si falla, el dueño y quien escribió el testbench deciden si el error está en el módulo, en el testbench o en el contrato; si es el contrato, se corrige aquí primero.
- Para el juego, la referencia es el modelo de reglas compartido, cuando exista; los casos se comparan paso a paso.
- `game_top` es de Alan, pero **cada quien agrega la instancia de sus propios módulos**.

## 8. Fechas

Las fechas del curso (diapositiva 2) son fijas y mandan sobre todo lo demás:

| Fecha | Entrega | Puntos | Tipo |
| --- | --- | --- | --- |
| Jue 19 nov 2026 | Pre-demo con el TA | 15 | Individual |
| Lun 30 nov 2026 | Demo del juego en clase | 10 | En grupo |
| Jue 10 dic 2026 | Reporte del diseño | 15 | Individual |

Las metas del equipo son **tentativas** y se ajustan al avance: una versión para la pre-demo hacia el **domingo 15 de noviembre** y el código congelado hacia el **lunes 23 de noviembre**. Las semanas de trabajo van de domingo a jueves. El plan semana por semana está en el [plan de desarrollo](../docs/plan/CS-256%20Tron%20Development%20Plan.md); el timeline anterior de 3 personas quedó en [`deprecated/`](deprecated/).

## 9. Preguntas abiertas

- [x] ¿Cuántos en el equipo? **Dos: Roman y Alan**, como indicaron los TAs.
- [x] ¿Qué placa exacta usamos? Nexys A7-100T.
- [x] ¿Resolución? **1280 × 800** (`hcnt` 0–1679, `vcnt` 0–827). `counters.sv` ya cuenta así.
- [x] ¿Reloj de píxel? **83.46 MHz**, el que pide el curso. Los 106.5 MHz del issue #10 no se adoptan (ADR 0006).
- [x] ¿Un solo reloj o reloj de juego aparte? Reloj de juego aparte de **~60 Hz** ([ADR 0002](../docs/adr/0002-follow-ta-divided-game-clock.md)), que sale de un contador de 20 bits sobre `clk_pix`, sin segundo Clocking Wizard ([ADR 0006](../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md)).
- [x] ¿Polaridad de `hsync` y `vsync`? La del handout: `hsync` en 0 durante 0–135 y `vsync` en 1 durante 0–2.
- [x] ¿Teclado? Ya no: P1 con botones y P2 por UART desde la página web.
- [x] ¿Celdas de 16 px? Sí, con 78 × 44 celdas jugables (revisable después de probar).
- [x] Interfaz entre el juego y la memoria rápida: pedidos, resultados y CDC propuestos en la sección 3 (issue #38). La foto coherente de posiciones y direcciones para dibujar la hace `pos_link` (X1, issue #30, PR #48); el parpadeo del choque sigue pendiente.
- [ ] Generador pseudoaleatorio, captura de la semilla y calendario de colocación de premios.
- [ ] Código de Enter en la UART y el búfer de eventos.
- [ ] Qué hacer con `tick_60hz` en `vga_out`.
- [x] Base del modelo compartido: `prototipos/tron_fpga/model/` (ADR 0004).
- [ ] Adaptar el otro visor al modelo compartido y verificar equivalencia.
