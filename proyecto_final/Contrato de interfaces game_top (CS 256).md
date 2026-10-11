# Contrato de interfaces: game\_top (CS 256)

Oct 11, 2026 · @Román · Juego: **Tron** (motos de luz, 2 jugadores) · Fuente: `cs256-project1-fall26.pdf` (las diapositivas citadas son de esa presentación)

## 0. El juego

Dos motos de luz avanzan solas por una arena y dejan una estela detrás. Cada jugador las dirige con un teclado: P1 con W A S D y P2 con las flechas. Quien choca con una pared o con cualquier estela, incluida la suya, pierde una vida y empieza otra ronda. Siempre hay un **rayo** en algún lugar de la arena: tomarlo da puntos. Gana quien llegue primero a la meta de puntos; quien se queda sin vidas, pierde.

- **Menú principal** con los botones de la placa: Jugar, Configuración y Cómo jugar.
- **Configuración:** vidas, meta de puntos, puntos por rayo, espera del rayo y largo de la estela (infinita, 64, 32 o 16 celdas).
- **Switches** (se pueden cambiar en cualquier momento, incluso jugando): `sw[1:0]` velocidad, `sw[3:2]` colores de las motos y sus estelas (4 temas), `sw[5:4]` fondo del mapa (rejilla, puntos, tablero o liso).
- **Display de 7 segmentos:** 4 dígitos por jugador: vidas, un dígito apagado y 2 de puntaje (`3 07  3 12`).

**Arena en cuadrícula.** La pantalla se divide en **celdas de 16 × 16 px (80 × 50 celdas)** y el contenido de cada celda se guarda en una memoria, `arena_map`:

- **Dibujar** la arena es una lectura por píxel: `drawcon` pregunta qué hay en la celda actual y elige el color.
- **Mover** una moto son unas pocas escrituras por paso: la cabeza nueva, la cabeza vieja que pasa a estela y, si la estela tiene largo fijo, la cola que se borra.
- **Detectar un choque** es leer la celda a la que va a entrar la moto, antes de moverla.

Las motos y el rayo se dibujan encima, como sprites en posiciones guardadas en registros. La moto avanza de celda en celda, pero su sprite se desliza entre ellas para que el movimiento se vea suave.

**Prototipo y modelo de referencia:** `prototipos/tron/` (se corre con `python3 main.py`). `juego.py` implementa exactamente las reglas de este contrato, y `test_juego.py` es la lista mínima de casos que deben cubrir los testbenches. La ventana del prototipo es la imagen VGA tal como la dibujará `drawcon`: colores RGB444, rectángulos, patrones que salen de bits de x/y, sprites de la ROM al doble y letras de la ROM de 8 × 8 (`fuente.py`) ampliadas por bloques. El display de 7 segmentos y los switches, que son de la placa, se ven en el título de la ventana.

## 1. Convenciones generales

Todo el diseño vive en un solo reloj (`clk_pix`) y cada señal tiene un único productor; así nadie depende de supuestos ajenos.

- **Reloj:** `clk` (100 MHz de la placa) solo entra al Clocking Wizard. De ahí sale `clk_pix`, y todos los módulos usan `clk_pix`. Esto evita cruces de dominio de reloj.
- **Frecuencia de `clk_pix`:** con los tiempos de la diapositiva 7 (1680 × 828 píxeles por cuadro a 60 Hz) salen unos **83.5 MHz**. El diagrama de las diapositivas 11 y 12 dice "106 MHz", que corresponde al estándar 1280 × 800 a 75 Hz y no a estos totales. Se usa **83.5 MHz** salvo que `/classproject/` diga otra cosa; hay que confirmarlo antes de configurar el wizard.
- **Reset:** `rst` es síncrono y activo en alto. Si se usa el botón CPU\_RESET de la placa (activo en bajo), se invierte una sola vez en `game_top`.
- **Coordenadas de píxel:** sin signo, origen (0,0) arriba a la izquierda, x crece a la derecha, y crece hacia abajo. Área visible de 1280 × 800.
- **Coordenadas de celda:** `cx` 0–79 (7 bits) y `cy` 0–49 (6 bits). De píxel a celda se pasa con un corrimiento: `cx = x >> 4`, `cy = y >> 4`. La dirección de una celda en `arena_map` es `{cy, cx}` (13 bits), sin multiplicaciones. Las filas 0 y 1 son la franja del marcador; la arena va de `cy = 2` a `cy = 49`.
- **Tipos y nombres:** `logic`, `snake_case`, un módulo por archivo con el mismo nombre. Los anchos están en las tablas de este documento y se usan tal cual en el código. Para que compile también en Icarus, nada de arreglos en los puertos: una señal por jugador (`_p1`, `_p2`).
- **Entradas asíncronas:** botones, switches, `ps2_clk` y `ps2_data` pasan por un sincronizador de 2 flip-flops antes de usarse. `ps2_clk` **nunca** se usa como reloj: se detecta su flanco de bajada dentro de `clk_pix`.

## 2. Puertos externos de `game_top`

`game_top` expone 14 pines VGA como mínimo (diapositiva 3), más las entradas de control; todo lo demás suma a la rúbrica de E/S extra. Placa confirmada: **Nexys A7-100T** (XC7A100T-1CSG324C). Los nombres de pin físicos están en `nexys-a7-100t-master.xdc`, en la raíz del repo.

| Puerto | Dir | Ancho | Descripción | Obligatorio |
| --- | --- | --- | --- | --- |
| `clk` | in | 1 | Reloj de la placa, 100 MHz | Sí |
| `rst` | in | 1 | Reset, activo en alto | Sí |
| `btn` | in | 5 | `[0]` arriba, `[1]` abajo, `[2]` izquierda, `[3]` derecha, `[4]` centro. Manejan los menús | Sí |
| `sw` | in | 6 | `sw[1:0]` velocidad (lenta, normal, rápida, turbo), `sw[3:2]` colores de las motos, `sw[5:4]` fondo del mapa | Sí |
| `ps2_clk`, `ps2_data` | in | 1 c/u | Teclado USB conectado al puerto USB HOST; el microcontrolador de la placa lo entrega como PS/2 (pines F4 y B2) | Sí |
| `vga_r`, `vga_g`, `vga_b` | out | 4 c/u | Color | Sí |
| `vga_hs`, `vga_vs` | out | 1 c/u | Sincronía horizontal y vertical | Sí |
| `seg` | out | 7 | Segmentos del display: vidas y puntos | Sí |
| `an` | out | 8 | Selección de dígito del display | Sí |
| `led` | out | 16 | Libres; `led[5:0]` repiten `sw[5:0]` | No |

La polaridad real de `vga_hs` y `vga_vs` queda como pregunta abierta (sección 9).

## 3. Señales internas entre bloques

Los anchos de video salen de los contadores de la diapositiva 7: `hcnt` llega a 1679, que necesita 11 bits (2^10 = 1024 no alcanza), y `vcnt` llega a 827, que cabe en 10 bits.

**Video**

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `clk_pix` | Clocking Wizard → todos | 1 | Único reloj del diseño |
| `tick_60hz` | `vga_out` → `tron_engine`, `menu_ctrl` | 1 | Pulso de 1 ciclo por cuadro, **al empezar el borrado vertical** (sección 4) |
| `curr_x`, `curr_y` | `vga_out` → `drawcon` | 11 / 10 | Píxel que se está dibujando (0–1279, 0–799) |
| `draw_r`, `draw_g`, `draw_b` | `drawcon` → `vga_out` | 4 c/u | Color del píxel, `DRAW_LATENCY` ciclos después de `curr_x`/`curr_y` |

**Arena**

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `map_rd_addr` | `drawcon` → `arena_map` (puerto B) | 13 | `{cy, cx}` de la celda que se está dibujando |
| `map_rd_data` | `arena_map` → `drawcon` | 4 | Tipo de celda, **1 ciclo después** de la dirección |
| `map_addr`, `map_we`, `map_wdata` | `tron_engine` → `arena_map` (puerto A) | 13 / 1 / 4 | Celda que se lee o escribe |
| `map_rdata` | `arena_map` → `tron_engine` | 4 | Tipo de celda leída, 1 ciclo después |

**Entradas**

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `ps2_byte`, `ps2_valid` | `ps2_rx` → `teclado` | 8 / 1 | Byte recibido (ya revisada la paridad) y pulso de 1 ciclo |
| `dir_p1`, `dir_p2` | `teclado` → `tron_engine` | 2 c/u | `DIR_*`; se quedan guardadas hasta que se presiona otra tecla |
| `btn_pulse` | `btn_debounce` → `menu_ctrl`, `tron_engine` | 5 | Pulso de 1 ciclo al presionar cada botón (con antirrebote) |
| `vel` | `game_top` → `tron_engine` | 2 | `sw[1:0]` sincronizado |
| `tema`, `fondo` | `game_top` → `drawcon` | 2 c/u | `sw[3:2]` y `sw[5:4]` sincronizados: eligen una fila de las tablas de color |
| `rnd` | `lfsr` → `tron_engine` | 16 | Avanza **una vez por `tick_60hz`**, así el hardware puede compararse cuadro a cuadro con el modelo de Python |

**Menús y configuración**

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `pantalla` | `menu_ctrl` → `drawcon` | 2 | `P_MENU`, `P_CONFIG`, `P_AYUDA` (solo cuenta si `partida_activa = 0`) |
| `menu_sel` | `menu_ctrl` → `drawcon` | 2 | Opción resaltada del menú principal |
| `cfg_sel` | `menu_ctrl` → `drawcon` | 3 | Opción resaltada de la configuración |
| `cfg_vidas` | `menu_ctrl` → `tron_engine`, `drawcon` | 4 | 1–9 |
| `cfg_meta` | `menu_ctrl` → `tron_engine`, `drawcon` | 7 | 5–95, de 5 en 5 |
| `cfg_valor_rayo` | `menu_ctrl` → `tron_engine`, `drawcon` | 3 | 1–5 |
| `cfg_espera_rayo` | `menu_ctrl` → `tron_engine`, `drawcon` | 3 | 0–5 s |
| `cfg_largo` | `menu_ctrl` → `tron_engine`, `drawcon` | 7 | 0 (infinita), 64, 32 o 16 |
| `start_partida` | `menu_ctrl` → `tron_engine` | 1 | Pulso: se eligió "Jugar" |
| `partida_activa` | `tron_engine` → `menu_ctrl`, `drawcon` | 1 | 1 desde `start_partida` hasta que se sale de la pantalla final con el botón central |

**Juego → video y display**

| Señal | De → A | Ancho | Nota |
| --- | --- | --- | --- |
| `game_state` | `tron_engine` → `drawcon` | 3 | `G_IDLE`, `G_READY`, `G_PLAY`, `G_ROUND`, `G_MATCH` |
| `cab_p1`, `prev_p1`, `cab_p2`, `prev_p2` | `tron_engine` → `drawcon` | 13 c/u | Celda de la cabeza y celda anterior de cada moto |
| `dir_m1`, `dir_m2` | `tron_engine` → `drawcon` | 2 c/u | Dirección en que va cada moto (orienta el sprite) |
| `viva_p1`, `viva_p2` | `tron_engine` → `drawcon` | 1 c/u | Si es 0, no se dibuja su sprite |
| `desliz` | `tron_engine` → `drawcon` | 4 | Píxeles (0–15) que el sprite ya avanzó de `prev` hacia `cab` |
| `rayo_pos`, `rayo_activo` | `tron_engine` → `drawcon` | 13 / 1 | Esquina de arriba a la izquierda del rayo (2 × 2 celdas) |
| `cuenta` | `tron_engine` → `drawcon` | 2 | Segundos que faltan en `G_READY` |
| `perdio` | `tron_engine` → `drawcon` | 2 | Quién chocó en la última ronda (bit 0 = P1, bit 1 = P2) |
| `ganador` | `tron_engine` → `drawcon` | 2 | 0 = empate, 1 = P1, 2 = P2 |
| `vidas_p1`, `vidas_p2` | `tron_engine` → `seg7_driver`, `drawcon` | 4 c/u | 0–9 |
| `puntos_p1`, `puntos_p2` | `tron_engine` → `seg7_driver`, `drawcon` | 7 c/u | 0–99 (se satura en 99) |

**Regla de latencia:** `drawcon` tarda `DRAW_LATENCY` ciclos: uno para leer `arena_map` o la ROM de fuente y otro para leer la ROM de sprites. `vga_out` debe retrasar `hsync`, `vsync` y el blanking esos mismos ciclos, o la imagen se corre en pantalla. El valor vive en `game_pkg.sv` y los dos módulos lo usan desde ahí.

## 4. Interfaz módulo por módulo

Cada módulo tiene un responsable (A, B o C; ver sección 7) y los puertos de abajo son su contrato: si alguien necesita cambiarlos, avisa al equipo antes de tocar el código.

| Módulo | Resp. | Qué hace | En el prototipo |
| --- | --- | --- | --- |
| `vga_out` | A | Contadores, pulsos de sync, blanking, `curr_x`/`curr_y`, `tick_60hz` y el retraso de `DRAW_LATENCY` | — |
| `drawcon` | A | Color de cada píxel en capas: arena, rayo, motos y textos (marcador, menús, mensajes) | `main.dibujar()` |
| `sprite_rom` | A | Sprites de 16 × 16 (moto mirando hacia arriba y rayo) en índices de color | `MOTO`, `RAYO` en `main.py` |
| `font_rom` | A | Letras de 8 × 8 (mayúsculas, dígitos, signos, acentos y Ñ) para los textos en pantalla | `fuente.py` |
| `arena_map` | B | Memoria de doble puerto de 8192 × 4 bits | `Juego.arena` |
| `tron_engine` | B | Rondas, motos, estelas, choques, rayo, vidas, puntos y fin de la partida | `Juego.paso()` en estados de juego, `Juego.mover()` |
| `ps2_rx` | C | Recibe tramas PS/2 de 11 bits (inicio, 8 datos, paridad impar, fin) | — |
| `teclado` | C | Decodifica los prefijos `E0`/`F0` y guarda `dir_p1`/`dir_p2` | `TecladoPS2` |
| `btn_debounce` | C | Sincroniza los 5 botones, quita rebotes y genera un pulso al presionar | — |
| `menu_ctrl` | C | Menú principal, configuración y ayuda; registros de configuración | `Juego.paso()` en estados de menú, `Config` |
| `lfsr` | C | Generador pseudoaleatorio de 16 bits | `LFSR16` |
| `seg7_driver` | C | Vidas y puntos en el display (binario a BCD y multiplexado) | `digitos_display()` |
| `game_top` | C | Instancia y conecta todo; reloj, reset, pines y XDC | — |
| Testbenches de integración | C | Prueban cada módulo de A y B contra este contrato y contra el modelo de Python | `test_juego.py` |

**`vga_out`** (A)

```systemverilog
module vga_out (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [10:0] curr_x,
    output logic [9:0]  curr_y,
    output logic        tick_60hz,   // 1 ciclo al empezar el borrado vertical
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync
);
```

`tick_60hz` sale de `vga_out` (en el diagrama de la diapositiva 11 es un bloque aparte, `clk_div_60hz`): un cuadro dura 1680 × 828 = 1,391,040 ciclos de `clk_pix`, así que es equivalente a dividir hasta 60 Hz y nunca se desfasa del video. Se genera **al terminar la última línea visible**, para que `tron_engine` actualice la arena mientras no se dibuja nada: quedan unas 28 líneas (unos 47,000 ciclos) y un paso completo usa menos de 30 accesos a la memoria.

**`drawcon`** (A)

```systemverilog
module drawcon (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [10:0] curr_x,
    input  logic [9:0]  curr_y,
    // Arena
    output logic [12:0] map_rd_addr,         // {curr_y[9:4], curr_x[10:4]}
    input  logic [3:0]  map_rd_data,         // llega 1 ciclo después
    // Juego
    input  logic [2:0]  game_state,
    input  logic        partida_activa,
    input  logic [12:0] cab_p1, prev_p1, cab_p2, prev_p2,
    input  logic [1:0]  dir_m1, dir_m2,
    input  logic        viva_p1, viva_p2,
    input  logic [3:0]  desliz,
    input  logic [12:0] rayo_pos,
    input  logic        rayo_activo,
    input  logic [1:0]  cuenta, perdio, ganador,
    input  logic [3:0]  vidas_p1, vidas_p2,
    input  logic [6:0]  puntos_p1, puntos_p2,
    // Menús
    input  logic [1:0]  pantalla, menu_sel,
    input  logic [2:0]  cfg_sel,
    input  logic [3:0]  cfg_vidas,
    input  logic [6:0]  cfg_meta, cfg_largo,
    input  logic [2:0]  cfg_valor_rayo, cfg_espera_rayo,
    // Estética (switches)
    input  logic [1:0]  tema, fondo,
    output logic [3:0]  draw_r, draw_g, draw_b   // DRAW_LATENCY ciclos después de curr_x/curr_y
);
```

Las capas, de abajo hacia arriba, son estas:

1. Fondo, según `fondo`: rejilla (`x[5:0] == 0` o `y[5:0] == 0`), puntos (`x[4:1] == 0` y `y[4:1] == 0`), tablero (`x[6] ^ y[6]`) o liso. Sin memoria: solo bits de `curr_x`/`curr_y`.
2. Arena: color plano según el tipo de celda. Las estelas toman el color de su jugador en el tema `tema`. El choque es una X: `x[3:0] == y[3:0]` o `x[3:0] == ~y[3:0]`. `CELL_P*_HEAD` y `CELL_RAYO` no se pintan en esta capa.
3. Rayo: sprite de 32 × 32 en `rayo_pos`.
4. Motos: sprite de 32 × 32 centrado en su celda, en la posición `prev + dirección × desliz`. La ROM guarda índices de color (color, sombra, brillo, llanta) y el tema decide los colores reales.
5. Textos con la ROM de 8 × 8, ampliados × 2, × 4, × 8 o × 16 (solo potencias de 2: ampliar es quitar bits a `curr_x`/`curr_y`): marcador en la franja de arriba ("P1 VIDAS 3 PUNTOS 07", la meta y P2), menús y mensajes. Los mensajes encima de la arena llevan un rectángulo negro detrás.

Si `partida_activa = 0`, solo se dibujan el fondo y la pantalla de menú que indique `pantalla`.

Los sprites se guardan en la ROM a 16 × 16 y se dibujan al doble: la dirección de la ROM es `(x - x0) >> 1`. La moto se guarda una sola vez, mirando hacia arriba. Para las otras 3 direcciones se intercambian e invierten los bits de la dirección (`15 - s = ~s` en 4 bits), como en `rotar_sprite()`. Al inicio basta con colores planos sin sprites: `DRAW_LATENCY` vale 1 y sube a 2 cuando entran las ROM.

**`arena_map`** (B)

```systemverilog
module arena_map (
    input  logic        clk_pix,
    // Puerto A: tron_engine (lee y escribe)
    input  logic [12:0] a_addr,
    input  logic        a_we,
    input  logic [3:0]  a_wdata,
    output logic [3:0]  a_rdata,         // 1 ciclo después
    // Puerto B: drawcon (solo lee)
    input  logic [12:0] b_addr,
    output logic [3:0]  b_rdata          // 1 ciclo después
);
```

Lectura síncrona en los dos puertos, para que Vivado la infiera como BRAM (8192 × 4 = 32 Kb, una sola BRAM36). Una BRAM no se puede poner en cero con `rst`: `tron_engine` la limpia al empezar cada ronda (sección 6).

**`tron_engine`** (B)

```systemverilog
module tron_engine (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic        tick_60hz,
    input  logic [1:0]  dir_p1, dir_p2,
    input  logic [4:0]  btn_pulse,           // solo usa el centro, para salir de G_MATCH
    input  logic [1:0]  vel,
    input  logic [15:0] rnd,
    input  logic        start_partida,
    input  logic [3:0]  cfg_vidas,
    input  logic [6:0]  cfg_meta, cfg_largo,
    input  logic [2:0]  cfg_valor_rayo, cfg_espera_rayo,
    // arena_map, puerto A
    output logic [12:0] map_addr,
    output logic        map_we,
    output logic [3:0]  map_wdata,
    input  logic [3:0]  map_rdata,
    // Estado para drawcon y el display
    output logic        partida_activa,
    output logic [2:0]  game_state,
    output logic [12:0] cab_p1, prev_p1, cab_p2, prev_p2,
    output logic [1:0]  dir_m1, dir_m2,
    output logic        viva_p1, viva_p2,
    output logic [3:0]  desliz,
    output logic [12:0] rayo_pos,
    output logic        rayo_activo,
    output logic [1:0]  cuenta, perdio, ganador,
    output logic [3:0]  vidas_p1, vidas_p2,
    output logic [6:0]  puntos_p1, puntos_p2
);
```

Así cambia de estado:

- `G_IDLE` → `G_READY` con `start_partida`. Las vidas se cargan con `cfg_vidas` y los puntos quedan en 0.
- `G_READY` dura 2 s de cuenta regresiva. Durante la cuenta, cada jugador ya puede elegir hacia dónde arranca, salvo hacia atrás.
- `G_PLAY`: cada `MOVE_FRAMES[vel]` cuadros, las dos motos dan un paso.
- `G_ROUND` dura 2 s y después empieza otra ronda o, si alguien se quedó sin vidas, `G_MATCH`.
- `G_MATCH` → `G_IDLE` con el botón central.

Cada paso sigue esta secuencia (`Juego.mover()`):

1. **Direcciones:** cada moto toma la dirección del teclado, salvo un giro de 180°. Se compara contra la dirección del último paso, no contra la última tecla.
2. **Colas:** si la estela tiene largo fijo y ya está completa, se borra la celda más vieja. Así se puede entrar a la celda que se libera en ese mismo paso.
3. **Lecturas:** se leen las dos celdas destino **antes de escribir nada**. Una moto sobrevive si su destino está vacío o tiene el rayo, y si las dos no van a la misma celda. Chocar de frente o cruzarse cuenta como choque para las dos.
4. **Rayo:** si alguien lo toma, se borran sus 4 celdas, se suma `cfg_valor_rayo` (si los dos lo toman a la vez, los dos suman) y empieza la espera de `cfg_espera_rayo` segundos.
5. **Escrituras:** en una moto que sobrevive, la cabeza vieja pasa a estela y se escribe la nueva. En una que chocó, se escribe `CELL_CRASH` en su cabeza y pierde una vida.
6. **Meta:** si alguien llegó a `cfg_meta`, termina la partida en ese momento. Si llegaron los dos, gana el de más puntos; si tienen los mismos, es empate.
7. **Choque:** si alguien chocó, se pasa a `G_ROUND`. Al terminar esa pantalla, si alguien tiene 0 vidas pierde; si los dos, gana el de más puntos y, si empatan en puntos, es empate.

Cada moto guarda su estela en un búfer circular de `MAX_LARGO` = 64 celdas (la cabeza y la cola son dos punteros). Con estela infinita, la cola nunca se borra.

**Rayo.** En cada cuadro sin rayo, pasada la espera, se hace **un** intento de ponerlo. La esquina sale de `rnd`: `cx = rnd[6:0]` y `cy = rnd[12:7]`. Si las 4 celdas están dentro de la arena y vacías, se escriben como `CELL_RAYO`; si no, se intenta en el siguiente cuadro.

**`desliz`.** Vale `(periodo - mov) × 16 / periodo` y se saca de una tabla pequeña indexada por `vel` y el avance; no hace falta un divisor. Si `vel` sube a mitad de un paso, `mov` se recorta al nuevo periodo.

**`ps2_rx`** (C)

```systemverilog
module ps2_rx (
    input  logic       clk_pix,
    input  logic       rst,
    input  logic       ps2_clk, ps2_data,   // directo de los pines
    output logic [7:0] ps2_byte,
    output logic       ps2_valid           // pulso de 1 ciclo
);
```

Sincroniza `ps2_clk` y `ps2_data`, detecta los flancos de bajada de `ps2_clk` (unos 10–16 kHz) y en cada uno toma un bit: inicio (0), 8 datos con el bit menos significativo primero, paridad impar y fin (1). Si la paridad o el bit de fin están mal, descarta el byte. Conviene un temporizador que reinicie la trama si pasa más de ~1 ms sin flancos.

**`teclado`** (C)

```systemverilog
module teclado (
    input  logic       clk_pix,
    input  logic       rst,
    input  logic [7:0] ps2_byte,
    input  logic       ps2_valid,
    input  logic       nueva_ronda,       // vuelve a las direcciones de salida
    output logic [1:0] dir_p1, dir_p2
);
```

Funciona igual que `TecladoPS2` en el modelo:

- `E0` marca la siguiente tecla como extendida y `F0` la marca como "soltada".
- Solo cambia la dirección al **presionar** una tecla; soltarla no hace nada. Por eso varias teclas a la vez no son problema.
- `0x75` sin `E0` es el 8 del teclado numérico, no la flecha arriba.

Los códigos están en `game_pkg.sv`. `nueva_ronda` se puede tomar de `game_state` entrando a `G_READY`.

**`btn_debounce`** (C)

```systemverilog
module btn_debounce (
    input  logic       clk_pix,
    input  logic       rst,
    input  logic [4:0] btn,                // directo de los pines
    output logic [4:0] btn_pulse           // 1 ciclo al presionar
);
```

**`menu_ctrl`** (C)

```systemverilog
module menu_ctrl (
    input  logic       clk_pix,
    input  logic       rst,
    input  logic [4:0] btn_pulse,
    input  logic       partida_activa,
    output logic [1:0] pantalla, menu_sel,
    output logic [2:0] cfg_sel,
    output logic [3:0] cfg_vidas,
    output logic [6:0] cfg_meta, cfg_largo,
    output logic [2:0] cfg_valor_rayo, cfg_espera_rayo,
    output logic       start_partida
);
```

Solo responde a los botones mientras `partida_activa = 0`:

- **`P_MENU`:** arriba y abajo mueven `menu_sel`, dando la vuelta. El botón central entra: "Jugar" manda `start_partida`, "Configuración" pasa a `P_CONFIG` y "Cómo jugar" a `P_AYUDA`.
- **`P_CONFIG`:** arriba y abajo mueven `cfg_sel`; izquierda y derecha cambian el valor dentro de sus límites, sin dar la vuelta. El botón central regresa a `P_MENU`.
- **`P_AYUDA`:** el botón central regresa a `P_MENU`.

Cada opción se guarda como un índice, y una tabla en `game_pkg.sv` lo convierte en el valor.

**`lfsr`** (C)

```systemverilog
module lfsr (
    input  logic        clk_pix,
    input  logic        rst,          // carga una semilla distinta de 0
    input  logic        tick_60hz,    // avanza un paso por cuadro
    output logic [15:0] rnd
);
```

LFSR de Galois de 16 bits con el polinomio x^16 + x^14 + x^13 + x^11 + 1 (máscara `16'hB400`), igual que `LFSR16` en el prototipo.

**`seg7_driver`** (C)

```systemverilog
module seg7_driver (
    input  logic       clk_pix,
    input  logic       rst,
    input  logic [3:0] vidas_p1, vidas_p2,
    input  logic [6:0] puntos_p1, puntos_p2,
    output logic [6:0] seg,
    output logic [7:0] an
);
```

Los 8 dígitos son, de izquierda a derecha: `vidas_p1`, apagado, decenas y unidades de `puntos_p1`, `vidas_p2`, apagado, decenas y unidades de `puntos_p2`. Convierte los puntos de binario a BCD y multiplexa los dígitos a ~1 kHz.

**`game_top`** (C) conecta además el Clocking Wizard (entrada de 100 MHz, salida `clk_pix`), los dos puertos de `arena_map`, sincroniza los switches (`vel`, `tema`, `fondo`) y pone `led[5:0] = sw[5:0]`.

## 5. Constantes compartidas (`game_pkg.sv`)

Todos leen tamaños, códigos y tablas desde un solo archivo. Si cada quien escribe sus números, el dibujo, la lógica y los testbenches se desfasan. Los valores son los mismos de `prototipos/tron/config.py`.

```systemverilog
package game_pkg;

    // Timing VGA 1280x800 (diapositiva 7). Verificar contra /classproject/
    localparam int H_SYNC = 136, H_BP = 200, H_ACTIVE = 1280, H_FP = 64;
    localparam int H_TOTAL = H_SYNC + H_BP + H_ACTIVE + H_FP;      // 1680
    localparam int V_SYNC = 3, V_BP = 24, V_ACTIVE = 800, V_FP = 1;
    localparam int V_TOTAL = V_SYNC + V_BP + V_ACTIVE + V_FP;      // 828

    // Ciclos entre curr_x/curr_y y draw_*: 1 con colores planos, 2 con ROM
    localparam int DRAW_LATENCY = 1;

    // Cuadrícula: celdas de 16x16 px
    localparam int TILE_SHIFT = 4;
    localparam int GRID_W = 80, GRID_H = 50, HUD_ROWS = 2;
    localparam int CX_W = 7, CY_W = 6, ADDR_W = 13;               // dirección = {cy, cx}

    // Contenido de una celda
    localparam logic [3:0] CELL_EMPTY    = 4'd0;
    localparam logic [3:0] CELL_WALL     = 4'd1;
    localparam logic [3:0] CELL_P1_TRAIL = 4'd2;
    localparam logic [3:0] CELL_P1_HEAD  = 4'd3;
    localparam logic [3:0] CELL_P2_TRAIL = 4'd4;
    localparam logic [3:0] CELL_P2_HEAD  = 4'd5;
    localparam logic [3:0] CELL_CRASH    = 4'd6;
    localparam logic [3:0] CELL_RAYO     = 4'd7;

    // Direcciones: girar a la derecha = sumar 1 (mod 4)
    localparam logic [1:0] DIR_UP = 2'd0, DIR_RIGHT = 2'd1, DIR_DOWN = 2'd2, DIR_LEFT = 2'd3;

    // Estados
    localparam logic [2:0] G_IDLE = 3'd0, G_READY = 3'd1, G_PLAY = 3'd2, G_ROUND = 3'd3, G_MATCH = 3'd4;
    localparam logic [1:0] P_MENU = 2'd0, P_CONFIG = 2'd1, P_AYUDA = 2'd2;

    // Botones
    localparam int BTN_U = 0, BTN_D = 1, BTN_L = 2, BTN_R = 3, BTN_C = 4;

    // Reglas
    localparam int MAX_LARGO    = 64;    // búfer circular de cada moto
    localparam int RAYO_CELDAS  = 2;     // el rayo ocupa 2x2 celdas
    localparam int FRAMES_READY = 120;
    localparam int FRAMES_ROUND = 120;
    localparam int SCORE_MAX    = 99;
    // Cuadros por celda según sw[1:0]: lenta, normal, rápida, turbo
    localparam logic [2:0] MOVE_FRAMES [4] = '{3'd6, 3'd4, 3'd3, 3'd2};

    // Estética: colores RGB444 de cada tema (sw[3:2]) y fondo (sw[5:4]).
    // Los valores están en TEMAS_MOTO y FONDOS, en config.py; A los copia como tablas.

    // Salidas: P1 en (12, 26) hacia la derecha, P2 en (67, 26) hacia la izquierda
    localparam logic [6:0] SAL_P1_CX = 7'd12, SAL_P2_CX = 7'd67;
    localparam logic [5:0] SAL_CY    = 6'd26;

    // Teclado PS/2 (Set 2)
    localparam logic [7:0] PS2_EXT = 8'hE0, PS2_BREAK = 8'hF0;
    localparam logic [7:0] K_W = 8'h1D, K_A = 8'h1C, K_S = 8'h1B, K_D = 8'h23;   // P1
    localparam logic [7:0] K_UP = 8'h75, K_LEFT = 8'h6B, K_DOWN = 8'h72, K_RIGHT = 8'h74;  // P2, con E0

endpackage
```

Los valores de cada opción de configuración (vidas 1–9, meta 5–95 de 5 en 5, puntos por rayo 1–5, espera 0–5 s, largo 0/64/32/16, con sus valores iniciales 3, 20, 1, 1 e infinita) están en `CONFIG`, en `config.py`. `menu_ctrl` los copia como tablas.

No compilé este paquete. Corre `iverilog -g2012` y una síntesis rápida en Vivado al agregarlo. El arreglo `MOVE_FRAMES` es lo que tiene más probabilidades de dar problemas en Icarus; si falla, cámbialo por un `case`.

**Quién edita `game_pkg.sv`:** A fija los tiempos VGA y `DRAW_LATENCY`, B fija la cuadrícula, los códigos de celda y las reglas, y C los códigos de teclado. C revisa que cualquier cambio siga pasando los testbenches.

## 6. Reglas de integración y puntos de fricción

Estos son los errores que más suelen romper la integración entre módulos escritos por personas distintas.

- **Un solo escritor en `arena_map`:** solo `tron_engine` escribe, por el puerto A. `drawcon` solo lee, por el puerto B.
- **Lectura con 1 ciclo de retraso:** los dos puertos entregan el dato un ciclo después de la dirección. `tron_engine` necesita un estado de espera entre poner `map_addr` y usar `map_rdata`. `drawcon` retrasa `curr_x[3:0]`/`curr_y[3:0]` para que coincidan con el dato.
- **Primero leer, luego escribir:** en cada paso se leen las dos celdas destino antes de cualquier escritura (sección 4). Si se procesa una moto completa y luego la otra, el resultado depende del orden y los choques de frente salen mal. Los casos están en `test_frente_a_frente` y `test_orden_no_importa`.
- **La cola se borra antes de leer:** con estela de largo fijo, entrar a la celda que la cola deja en ese mismo paso es válido (`test_entrar_a_la_celda_que_deja_la_cola`).
- **Giro de 180°:** se compara contra la dirección del último paso. Si se compara contra la última tecla, presionar arriba y luego izquierda rápido, entre dos pasos, deja que la moto se dé la vuelta sobre su propia estela.
- **Actualizar durante el borrado:** `tron_engine` hace sus lecturas y escrituras justo después de `tick_60hz`, cuando no se dibuja nada.
- **Limpiar la arena:** al empezar cada ronda, `tron_engine` recorre las 8192 direcciones escribiendo `CELL_EMPTY`, y `CELL_WALL` en el borde. Tarda 8192 ciclos (unos 0.1 ms).
- **PS/2:** `ps2_clk` es una entrada lenta y asíncrona, no un reloj. Se sincroniza y se detecta su flanco dentro de `clk_pix`.
- **Teclado y teclas simultáneas:** dos jugadores en un mismo teclado presionan varias teclas a la vez. Algunos teclados baratos no reportan ciertas combinaciones; hay que probar WASD con las flechas en el teclado que se va a usar en la demo.
- **Restar sin signo en el borde:** `cx = 0` menos 1 da 127, no -1. Las paredes del borde impiden llegar ahí, pero el cálculo no debe depender de eso.
- **Asignaciones:** `always_ff` usa `<=` (non-blocking) y `always_comb` usa `=`. En `always_comb` todas las ramas deben asignar todas las salidas; si no, Vivado infiere un latch.
- **Un solo reloj:** nadie genera un reloj con lógica. `tick_60hz` y los pulsos de botón son habilitaciones dentro de `clk_pix`.
- **Latencia de `drawcon`:** cuando `DRAW_LATENCY` pasa de 1 a 2, `vga_out` y `drawcon` cambian juntos. A es dueño de los dos, así que el ajuste queda en una sola persona.
- **Blanking:** fuera del área visible los tres canales de color valen 0. Lo fuerza `vga_out`.
- **Probar `vga_out` primero:** en simulación, `hsync` dura 136 ciclos, una línea completa dura 1680, un cuadro dura 828 líneas y el color es 0 fuera de los 1280 × 800 visibles. Sin esto, el resto del diseño no se puede depurar (diapositiva 25).
- **Cambios al contrato:** cualquier cambio de nombre, ancho o significado de una señal se anota en este documento y se avisa antes de modificar el código.

## 7. Reparto entre 3 personas

El equipo es de tres (confirmado). Hay **dos desarrolladores (A y B)** y **una persona de verificación e integración (C)**. C no es un tester puro: también es dueño de las entradas, los menús, el display y `game_top`, porque 30 de los 40 puntos son individuales (pre-demo y reporte) y cada quien necesita diseño propio que mostrar y explicar.

| Persona | Módulos | Entregables | Rúbrica que cubre |
| --- | --- | --- | --- |
| **A: Video** | Clocking Wizard (configuración), `vga_out`, `drawcon`, `sprite_rom`, `font_rom` | Imagen estable; arena, sprites deslizándose y textos de menús | Imagen estable (diapositiva 25), sprites (2), creatividad (1) |
| **B: Lógica de juego** | `arena_map`, `tron_engine`, reglas en `game_pkg.sv` | Motos que se mueven y respetan las paredes; estelas, choques, rayo, vidas, puntos | Control con límites de pantalla (2.5), objetos e interacciones (2.5) |
| **C: Verificación, integración y periféricos** | `game_top`, XDC, `ps2_rx`, `teclado`, `btn_debounce`, `menu_ctrl`, `lfsr`, `seg7_driver`, testbenches de integración | Teclado, botones y switches funcionando; menús; display; un testbench por módulo de A y B; simulación de `game_top` | E/S extra (2): teclado, display, switches; base de la integración |

**Cómo se reparten las pruebas**

- Cada dueño hace pruebas rápidas de su propio módulo mientras lo escribe.
- C escribe el testbench **oficial** de cada módulo de A y B, partiendo de **este contrato**, no del código. Si C y el dueño leen distinto una señal, el testbench lo detecta antes de que llegue a la placa.
- Un módulo se considera terminado cuando pasa el testbench de C. Si falla, se decide entre los dos si el error está en el módulo, en el testbench o en el contrato; si es el contrato, se corrige aquí primero.
- Para `tron_engine`, el modelo de referencia es `prototipos/tron/juego.py`. C lo usa para generar las secuencias esperadas (`Juego.arena_hex()` saca la arena en formato `$readmemh`), y el testbench compara la arena después de cada paso. Los casos mínimos son los de `test_juego.py`.

**Orden de trabajo** (diapositiva 25; las fechas están en la sección 8). C tiene trabajo desde el primer día porque los testbenches salen del contrato:

1. A escribe `vga_out`; B escribe `arena_map` y diseña la secuencia de `tron_engine`; C escribe el testbench de `vga_out`, `btn_debounce` y `ps2_rx`.
2. C integra `vga_out` en `game_top` y lo baja a la placa: imagen estable. A dibuja la arena con colores planos. C comprueba el teclado en la placa.
3. B mueve las dos motos sobre la arena; después agrega choques, vidas y el rayo.
4. C agrega menús y display; A agrega sprites, el deslizamiento y los textos.

## 8. Timeline semanal

Las semanas van de lunes a domingo. El **hito** de cada semana vence el **domingo a las 23:59** y se revisa en una reunión corta del equipo ese mismo domingo. Las tres fechas fijas del curso (diapositiva 2) mandan sobre todo lo demás:

| Fecha | Entrega | Puntos | Tipo |
| --- | --- | --- | --- |
| Jue 19 nov 2026 | Pre-demo con el TA | 15 | Individual |
| Lun 30 nov 2026 | Demo del juego en clase | 10 | En grupo |
| Jue 10 dic 2026 | Reporte del diseño | 15 | Individual |

El plan deja el juego completo una semana antes de la pre-demo y el código congelado cuatro días antes de la demo. La diapositiva 27 menciona hitos del curso en `/classproject/`; cuando se publiquen, se ajustan estas fechas para que coincidan.

**Resumen**

| Sem. | Fechas | Hito del equipo (vence el domingo) |
| --- | --- | --- |
| 1 | 12–18 oct | `vga_out` y `arena_map` pasan los testbenches de C; `ps2_rx` y `btn_debounce` en simulación; secuencia de `tron_engine` revisada por el equipo |
| 2 | 19–25 oct | En el monitor: arena con paredes y las dos estelas moviéndose con el teclado; choque y vidas |
| 3 | 26 oct – 1 nov | Juego completo con colores planos: rayo, puntos, meta, fin de partida, largo de estela; vidas y puntos en el display |
| 4 | 2–8 nov | Sprites de motos y rayo, deslizamiento, menú principal y configuración en pantalla, temas y fondos con los switches |
| 5 | 9–15 nov | Juego completo y pulido; versión `predemo` etiquetada en git |
| 6 | 16–22 nov | **Pre-demo el jue 19**; correcciones a partir de los comentarios del TA |
| 7 | 23–29 nov | Código congelado el jue 26 (tag `demo`); guion de la demo ensayado |
| 8 | 30 nov – 6 dic | **Demo el lun 30**; borrador de cada reporte |
| 9 | 7–10 dic | **Reporte el jue 10** |

**Semana 1 (12–18 oct): VGA, arena y entradas en simulación**
- Equipo: repartir A, B y C el **lunes 12**.
- A: `vga_out` con `hcnt` 0–1679 y `vcnt` 0–827, pulsos de sync, blanking, `curr_x`/`curr_y` y `tick_60hz` al empezar el borrado vertical. Partir de `counters.sv`, cambiándolo a 11 bits y 1679.
- B: `arena_map` (doble puerto, lectura síncrona). Dibujar el diagrama de estados de `tron_engine` (la secuencia de la sección 4) y revisarlo con el equipo el **miércoles 14**.
- C: compilar `game_pkg.sv` en Icarus y en Vivado; testbench de `vga_out` (sección 6) y de `arena_map`; `btn_debounce` y `ps2_rx` en simulación, alimentando `ps2_rx` con los bytes de `bytes_ps2()`; confirmar el reloj y la polaridad en `/classproject/`.

**Semana 2 (19–25 oct): las motos en el monitor**
- A: configurar el Clocking Wizard para `clk_pix`; `drawcon` lee `arena_map` y pinta un color plano por tipo de celda (`DRAW_LATENCY = 1`).
- B: `tron_engine` limpia la arena, pone las paredes y mueve las dos motos con estela infinita; choques (pared, estela, frente a frente) y vidas, con valores fijos en lugar de los de configuración.
- C: `game_top` y XDC; generar el bitstream y probarlo en la placa. **Probar el teclado USB en la placa** (mostrar `dir_p1`/`dir_p2` en los LEDs), incluido WASD con flechas a la vez. Escribir `teclado` y el testbench de `tron_engine`.
- Si la imagen no sale estable para el miércoles 21, los tres se enfocan en eso: sin VGA no hay nada que mostrar. Si el teclado no funciona, hay que avisar ese mismo día para ver alternativas.

**Semana 3 (26 oct – 1 nov): juego completo con colores planos**
- B: rayo (con `rnd`), puntos, meta, `G_ROUND`/`G_MATCH`, estela de largo fijo con búfer circular y velocidad con `vel`.
- A: pantalla de cuenta regresiva y de fin con colores o bloques simples, y el marcador en la franja de arriba.
- C: `lfsr`; `seg7_driver` con vidas y puntos; `menu_ctrl` (aún sin texto, con valores visibles en los LEDs); ampliar el testbench comparando contra `juego.py`.
- Con este hito ya quedan cubiertos los dos criterios de 2.5 puntos de la rúbrica (diapositiva 26).

**Semana 4 (2–8 nov): sprites y menús**
- A: `sprite_rom` con la moto y el rayo, orientación por bits, `desliz`; `font_rom` (copiar `fuente.py`) y textos de menú principal, configuración, cómo jugar y mensajes; temas de color y fondos con `tema`/`fondo`; `DRAW_LATENCY = 2`.
- B: `desliz` y los registros que necesita `drawcon` (`prev`, `cab`, `dir`); recorte de `mov` al cambiar la velocidad.
- C: integrar los menús de punta a punta; simulación completa de `game_top`.

**Semana 5 (9–15 nov): juego completo**
- Extensiones, solo si hay tiempo: rival de la computadora (`BotTron` en el prototipo), sonido por la salida de audio de la placa, efectos al tomar el rayo.
- Todos: integrar, corregir errores y preparar la explicación de sus módulos para la pre-demo (diagrama, puertos, decisiones de diseño y cómo lo probaron).
- Domingo 15: versión estable con tag `predemo`. Desde ese día solo se arreglan errores.

**Semana 6 (16–22 nov): pre-demo**
- Lunes 16 a miércoles 18: ensayo cruzado, en el que cada quien explica sus módulos ante los otros dos y responde preguntas.
- **Jueves 19:** pre-demo individual con el TA.
- Viernes 20 a domingo 22: anotar y corregir lo que haya señalado el TA.

**Semana 7 (23–29 nov): preparar la demo**
- Pulir y, si se puede, probar en un monitor como el del salón y con el teclado de la demo.
- **Jueves 26:** código congelado con tag `demo`. Después de eso solo se aceptan arreglos de errores graves, y pasan por C.
- Escribir y ensayar el guion de la demo: qué se muestra, quién lo presenta y cuánto dura.

**Semana 8 (30 nov – 6 dic): demo y reportes**
- **Lunes 30:** demo en grupo.
- El reporte es individual, así que cada quien escribe el suyo sobre su parte del diseño. Antes de reutilizar figuras o diagramas, confirmen con el profesor qué se puede compartir.
- Domingo 6: borrador completo de cada reporte.

**Semana 9 (7–10 dic): entrega final**
- Revisión cruzada de los reportes (ortografía y claridad, no contenido) a más tardar el martes 8.
- **Jueves 10:** entrega del reporte.

**Si un hito se atrasa**, se recorta alcance en este orden y nunca se mueve una fecha del curso:
1. Las extensiones de la semana 5.
2. Los temas de color y fondos extra (se quedan el tema y el fondo por defecto).
3. El deslizamiento de los sprites (la moto salta de celda en celda).
4. Los textos de los menús: la configuración se muestra en el display y los LEDs en vez de en pantalla.
5. El largo fijo de la estela (queda solo infinita).
6. El sprite del rayo; se conserva al menos el de la moto en ROM, porque los sprites desde memoria valen 2 puntos.

## 9. Preguntas abiertas

- [x] ¿Pueden ser tres en el equipo? Sí.
- [x] ¿Qué placa exacta usamos? Nexys A7-100T.
- [x] ¿Resolución? **1280 × 800**: la diapositiva 7 lo dice explícitamente (`hcnt` 0–1679, `vcnt` 0–827). El `README.md` y `counters.sv` de `proyecto_final/` todavía usan 640 × 480 (cuenta 0–799) y hay que actualizarlos: el contador horizontal llega a 1679 y necesita 11 bits.
- [x] ¿Qué juego hacemos? **Tron** para 2 jugadores, con teclado, rayos, vidas y menús (sección 0).
- [ ] ¿`clk_pix` es 83.5 MHz o 106 MHz? Con los contadores de la diapositiva 7, 1680 × 828 × 60 Hz da 83.5 MHz. El "106 MHz" del diagrama de las diapositivas 11 y 12 coincide con el estándar 1280 × 800 a 75 Hz, que usa otros totales, así que probablemente es un rótulo heredado. Confirmar en `/classproject/` (diapositiva 27).
- [ ] ¿Polaridad de `hsync` y `vsync`? El estándar VESA de 1280 × 800 a 60 Hz usa `hsync` en bajo y `vsync` en alto, pero los tiempos del curso no son idénticos a VESA (828 líneas en vez de 831). Confirmar en `/classproject/`.
- [ ] ¿Quién es A, quién es B y quién es C? **Vence el lunes 12 oct**, para que la semana 1 arranque con dueños claros.
- [ ] ¿Qué teclado se usará en la demo? Hay que probarlo en la placa en la semana 2: algunos teclados USB (sobre todo los de juego o los que traen un hub interno) no funcionan con el puerto USB HOST de la Nexys A7.
- [ ] ¿Celdas de 16 px y los valores iniciales de la configuración (3 vidas, meta 20, 1 punto por rayo, 1 s de espera, estela infinita) están bien? Se cambian en `config.py` y `game_pkg.sv`.
