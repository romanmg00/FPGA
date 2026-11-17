# Proyecto final: Tron en VGA

Tarjeta Nexys A7-100T, salida VGA **1280x800** (diapositiva 7 del curso) con reloj de
píxel de **83.46 MHz**. El estado del juego corre con un reloj aparte de **~60 Hz**
([ADR 0002](../docs/adr/0002-follow-ta-divided-game-clock.md)). Según la reunión con
los TAs ([ADR 0006](../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md)),
ese reloj sale de un contador de 20 bits sobre `clk_pix`, sin segundo Clocking Wizard,
y el handout es una guía general. El código ya lo hace (Paso 4c), y su bitstream se probó en la tarjeta el 12 de noviembre.

- Reglas: [especificación acordada del 20 de octubre](../docs/decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md)
  (bloqueada; manda sobre este README y el contrato, salvo en los puntos que cambian los
  ADR aceptados después, como el [ADR 0006](../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md) en los relojes)
- Contrato de interfaces (módulos, señales, reparto y fechas):
  [`Contrato de interfaces game_top (CS 256).md`](Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md).
  Las interfaces que la especificación deja abiertas están marcadas como pendientes
- Diseño de video y sprites: [plan de VGA y sprites](../docs/design/CS-256%20VGA%20and%20Sprite%20Design%20Plan.md)
  y [prácticas de código del curso](../docs/design/CS-256%20Official%20FPGA%20Coding%20Practices.md)
- Modelo de referencia: [ADR 0004](../docs/adr/0004-shared-headless-model-base.md)
  selecciona `../prototipos/tron_fpga/model/` como base compartida. Falta adaptar
  el otro visor; la selección no valida los supuestos de timing/CDC del prototipo.
- Presentación del curso: `cs256-project1-fall26.pdf`
- Pines: `../nexys-a7-100t-master.xdc`
- Versiones anteriores de este README y del contrato: [`deprecated/`](deprecated/)

## Avance (un paso a la vez)

- [x] **Paso 1:** contador horizontal en simulación
- [x] **Paso 1b:** contador horizontal de 0 a 1679 (11 bits), en `counters.sv`
- [x] **Paso 2:** contador vertical de 0 a 827, avanza cuando el horizontal da la
  vuelta, en `counters.sv`
- [x] **Paso 3a:** `vga_out` con pulsos de sync, blanking y `curr_x`/`curr_y`. `vga_out_tb.sv`
  revisa el pulso de `hsync`, las 1680 cuentas por línea y el color fuera del área visible,
  y pasa en XSim dentro de `build_game_top.tcl`
- [ ] **Paso 3b:** decidir qué pasa con `tick_60hz`, que hoy siempre vale 0 y nadie usa: quitar
  el puerto o hacerlo un pulso por cuadro. Con el ADR 0002 el reloj de juego sale del
  divisor, no de `vga_out`
- [x] **Paso 4a:** Clocking Wizard (se piden 83.46 MHz y se logran 83,455,882 Hz), segundo
  Wizard con el divisor a ~60 Hz e imagen estable en la tarjeta
- [x] **Paso 4c:** quitar `clk_wiz_1` y sacar `clk_juego` de un contador de 20 bits sobre
  `clk_pix` (ADR 0006), que alterna cada 695,466 ciclos (59.99997 Hz). Build, pruebas e
  imagen en la tarjeta el 12 de noviembre; el estado está en el [mapa de arquitectura](../docs/CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md#architecture-and-ownership)
- [ ] **Paso 4b:** borde blanco de 10 px en la franja del HUD, que hoy llega en gris hasta la
  orilla: las 10 filas de arriba y las 10 columnas de cada lado. Abajo de `y = 64`, las
  paredes de 16 px ya lo cubren
- [x] **Paso 5a:** `drawcon` con paredes, HUD, bloque y fondo en colores planos
- [x] **Paso 5b:** `drawcon` lee de `arena_map` lo que hay en cada celda y pinta las estelas (PR #40)
- [ ] **Paso 5c:** sprites desde ROM (`.coe` RGB444, motos de 32x32 y premios de 16x16)
- [x] **Paso 6a:** una moto que avanza sola en rondas (`round_fsm`, `step_counter`, `bike_move`):
  Start con BTNC, giros de 90°, choque con la pared y pausa de 2 s. Probada en la tarjeta el
  12 de noviembre (PR #21)
- [x] **Paso 6b:** segunda moto y choques entre motos (mismo destino, cabeza de la otra,
  intercambio). P2 sale de (59, 27) hacia la izquierda y por ahora avanza recto; su entrada
  `turn_req2` espera el teclado. `position_logic_tb` pasa en Verilator; probada en la tarjeta
  el 15 de noviembre con `game_top_two_bikes.bit` (PR #25)
- [x] **Paso 6c:** intervalo del paso (ADR 0007, issue #22). En la tarjeta, el 15 de noviembre,
  8 ticks se veían lentos y a saltos. Con las motos deslizándose entre celdas se ven suaves, y
  Roman eligió **8** (7.5 celdas/s) el 16 de noviembre
  ([ADR 0010](../docs/adr/0010-bikes-sliding-between-cells.md), aceptado; PRs #28 y #35). `STEP_TICKS` vive en `game_top`; cambiarlo de nuevo es una línea
- [x] **Paso 6e:** `bike_glide` dibuja cada moto avanzando unos píxeles por tick (2 px por tick
  con 8 ticks) hacia su celda; el juego sigue por celdas y lo dibujado va un paso atrás.
  Su salida es un registro, así que la cuenta no entra a la ruta de `clk_pix`
- [x] **Paso 6d:** choque con estelas, leyendo de `arena_map` las 4 celdas vecinas de cada cabeza
  (sección 3 del contrato, issue #38; PR #40). Faltan los premios
- [x] **Paso 6f:** arena (A1/A2): `arena_map` (BRAM de 8192 × 4, puerto B con 2 ciclos),
  `arena_ctrl` (único que escribe, en `clk_pix`) y `arena_link` (lado del juego, en `clk_juego`).
  Después de cada paso devuelve las 4 vecinas de cada cabeza en el flanco *k*+4. Sus pruebas
  corren en `build_game_top.tcl`, y `game_top_tb` revisa las estelas en pantalla y la arena entera.
  Conectada en `game_top` (PR #40, sobre el #39); probada en la tarjeta el 16 de noviembre:
  estelas, choque con estelas y paredes, ronda nueva, reset y choque de frente
- [ ] **Paso 7:** marcador físico en los 8 dígitos de 7 segmentos (especificación, *Physical
  Scoreboard*, y [ADR 0008](../docs/adr/0008-scoreboard-goal-page-before-a-match.md)), por partes:
  - [x] **7a:** `sevenseg` y `multidigit` de la tarea 1 del curso, en su mismo estilo. En
    `sevenseg`, los códigos 10–13 son P, L, G y A en lugar de las letras hex, y 14–15 quedan en
    blanco. `multidigit` usa el contador de 17 bits de la tarea, ahora en `clk_pix`, sin reloj
    nuevo (ADR 0006): pasa al siguiente dígito cada vez que se llena (1.57 ms por dígito). Solo en simulación: `sevenseg_tb` y `multidigit_tb`
    pasan en XSim; todavía no están en `game_top`
  - [x] **7b:** las vistas. `seg7_view`, en `clk_juego`, cambia de vista cada 180 ticks (3 s):
    puntos → vidas y, mientras se espera una partida nueva, → meta; mover `{SW15, SW14}` en esa
    espera salta a la meta y reinicia sus 3 s, y una partida nueva empieza en puntos. Sigue a
    `PageTimer` del modelo. `seg7_driver`, en `clk_pix`, arma los 8 dígitos (`P2nnP1nn`,
    `L20nL10n`, `G0AL  n0`) y los barre con `multidigit`. Solo en simulación: `seg7_view_tb`
    (una prueba por regla del ADR 0008) y `seg7_driver_tb` pasan en XSim
  - [x] **7c:** partida, vidas y puntos (G3/G5), sin premios (PR #46). `match_fsm` (máquina de
    Moore de 8 estados, códigos 0–4 = `G_*` del contrato) decide cuándo llega Start a `round_fsm`
    y reinicia `position_logic` en cada partida nueva; `score_unit` quita una vida por moto
    chocada, da +3 a la única que sobrevive (ADR 0011) y decide quién gana o si hay empate.
    `match_fsm_tb` y `score_unit_tb` pasan en XSim. Sin premios no se llega a la meta (máximo
    9 puntos). Plan: [`docs/plan/CS-256 Match Lifecycle and Scoreboard Plan.md`](../docs/plan/CS-256%20Match%20Lifecycle%20and%20Scoreboard%20Plan.md)
  - [x] **7d:** en `game_top`: `sw[15:0]` (`SW0` pausa, `{SW15, SW14}` meta), pines `seg`, `dp`
    y `an`, y `seg7_link`, que cruza los 20 bits del marcador de `clk_juego` a `clk_pix` (toggle
    y copia, como la arena). `match_tb` juega partidas enteras en `clk_juego`; `game_top_tb` lee
    el marcador de los pines (escenarios `match` y `pause`). Falta probarlo en la tarjeta

## Hito: bloque en movimiento (revisión del 12 de noviembre)

> Este hito describe el bloque de antes del PR #21. Desde entonces `game_top` muestra motos
> que avanzan solas en rondas (pasos 6a y 6b).

Según el código, `game_top` muestra un bloque de 16x16 que se mueve con los botones y se
detiene en las paredes. CPU_RESET lo regresa a (320, 432) si se mantiene al menos unos
17 ms; con menos, se reinicia el video, pero el bloque se puede quedar donde estaba. BTNC
lo lleva al centro, (632, 392). Su color sale de `SW0`–`SW11`: **con todos abajo es negro
y no se ve.**

Ese hito se probó con `game_top_one_wizard.bit`, con un solo Wizard; en la tarjeta se
probaron también las paredes y el reset repetido. Ese archivo ya no está en el repositorio:
[`bitstreams/README.md`](bitstreams/README.md) guarda solo el último bitstream probado
(`game_top_two_bikes.bit`), con sus resultados y límites.

## Archivos

- `prototypes/core_blocks/`: [bloques básicos y núcleo jugable provisionales](prototypes/core_blocks/README.md) (29 oct 2026). **Solo prototipo:** muestra cómo se podría implementar el juego (con el look synthwave) y no se usa directamente en el diseño de `proyecto_final/` ni es lo que se entrega a los TAs. Pruebas por bloque, comparación con los 12 escenarios M2 del modelo y un bitstream `tron_top`, probado en la tarjeta y grabado en su flash el 12 de noviembre. Trae sus propios scripts de host en `prototypes/core_blocks/tools/`. No seleccionan interfaces (ADR 0005). Usan su propia copia de `vga_out` con salidas combinacionales (`video/vga_out.sv`), que todavía no es la de `game_top`.
- `prototypes/uart_input/`: [experimento UART aislado](prototypes/uart_input/README.md), con receptor, decodificador y FIFO. Pasa las pruebas de XSim; genera bitstream con temporización verificada y revisión del catálogo IP. Los [resultados y límites](../docs/design/CS-256%20UART%20Input%20Prototype%20Findings.md) documentan las advertencias CDC y la integración pendiente con `game_top`.
- `game_top.sv`: tope del diseño. Conecta el Clocking Wizard, el contador de `clk_juego`, los sincronizadores y los bloques de abajo
- `position_logic.sv`: las dos motos, en `clk_juego`: control de ronda, ritmo del paso, giros y choques
- `round_fsm.sv`: ronda de Roman: espera Start, corre, pausa tras un choque y espera que se suelte Start. Desde el Paso 7d su Start viene de `match_fsm`
- `step_counter.sv`: un pulso cada `STEP_TICKS` ticks; marca el paso (8, ADR 0010) y la pausa de choque (120)
- `bike_glide.sv`: posición dibujada de una moto, que se desliza de su celda anterior a la nueva durante un paso (ADR 0010); una instancia por moto
- `bike_move.sv`: celda, dirección y giro pendiente de una moto; se instancia una vez por moto
- `arena_map.sv`: memoria de la arena, una palabra de 4 bits por celda; puerto A de `arena_ctrl` (1 ciclo), puerto B de `drawcon` (2 ciclos)
- `arena_ctrl.sv`: en `clk_pix`, el único que escribe en `arena_map`: prepara la ronda (limpieza y cabezas) o escribe el paso, y lee las 4 vecinas de cada cabeza
- `arena_link.sv`: en `clk_juego`, manda las cabezas a `arena_ctrl` después de cada paso y al subir `load`, y entrega los 8 códigos con `codes_valid`
- `match_fsm.sv`: partida (G3) en `clk_juego`: espera Start, partida nueva, ronda, choque, siguiente ronda o fin de partida; manda Start a `round_fsm` como pulso de 1 tick y reinicia `position_logic` en cada partida nueva
- `score_unit.sv`: vidas, puntos (bono de supervivencia, ADR 0011) y resultado de la partida (G5), en `clk_juego`
- `seg7_link.sv`: cruce del marcador de `clk_juego` a `clk_pix` (toggle por `sync_2ff` y copia de los 20 bits)
- `drawcon.sv`: color de cada píxel: paredes, HUD, P1 en azul (`0DF`) y P2 en naranja (`F80`)
- `sevenseg.sv`: decodificador de 7 segmentos de la tarea 1, activo en bajo: 0–9, y P, L, G, A y blanco del marcador en 10–15
- `multidigit.sv`: los 8 dígitos con un solo juego de segmentos, como en la tarea 1; su contador de 17 bits corre en `clk_pix`
- `seg7_view.sv`: qué vista muestra el marcador (puntos, vidas o meta), en `clk_juego`, cada 3 s (ADR 0008)
- `seg7_driver.sv`: el marcador en `clk_pix`: de puntos, vidas, vista y meta a los 8 dígitos, con `multidigit`
- `counters.sv`: contadores horizontal (0–1679) y vertical (0–827)
- `vga_out.sv`: sync, blanking y `curr_x`/`curr_y` (`tick_60hz` todavía en 0)
- `sync_2ff.sv`: sincronizador de 2 flip-flops para botones y switches
- `board_reset_sync.sv`: lleva CPU_RESET a cada dominio de reloj
- `game_top.xdc`: pines y configuración de la tarjeta para `game_top`
- `game_top_timing.xdc`: reloj generado de `clk_juego` y excepciones de temporización; solo para implementación
- `ip/clk_wiz_0/clk_wiz_0.xci`: IP del reloj de píxel para el proyecto de Roman; `build_game_top.tcl` no lo lee y genera el Wizard. Ver el [inventario de IP](../docs/design/CS-256%20Vivado%20IP%20Inventory.md)
- `game_top_tb.sv`: revisa `game_top` desde sus pines, con 9 escenarios (`match` y `pause` leen el marcador de `seg` y `an`). Espera las motos dibujadas desde `bike_synth.coe`, giradas con su dirección, con el corrimiento de 2 px de `drawcon` (sin lectura adelantada) como desviación conocida: `SPRITE_SHIFT = 2`, que vuelve a 0 cuando `drawcon` lea adelantado
- `arena_map_tb.sv`, `arena_ctrl_tb.sv`, `arena_tb.sv`: pruebas de la arena; `arena_tb` usa los dos relojes y corre con 6 y 8 ticks por paso
- `match_tb.sv`: `match_fsm`, `score_unit` y `position_logic` juntos en `clk_juego`, un tick por flanco: partidas enteras, pausa y reset en cada estado
- `match_fsm_tb.sv`, `score_unit_tb.sv`, `seg7_link_tb.sv`, `position_logic_tb.sv`, `round_fsm_tb.sv`, `step_counter_tb.sv`, `bike_move_tb.sv`, `sevenseg_tb.sv`, `multidigit_tb.sv`, `seg7_view_tb.sv`, `seg7_driver_tb.sv`, `sync_2ff_tb.sv`, `board_reset_sync_tb.sv`, `vga_out_tb.sv`, `counters_tb.sv`: testbenches de cada bloque. `counters_tb.sv` no corre en `build_game_top.tcl`
- `sim_clocks/`: relojes ideales **solo para simulación**. La síntesis usa siempre la IP que genera Vivado; ver el [inventario de IP](../docs/design/CS-256%20Vivado%20IP%20Inventory.md)
- `sim_models/bike_rom.sv`: modelo de `bike_rom` **solo para simulación**, con los mismos puertos y 2 ciclos de latencia. Lee el `.mem` que `build_game_top.tcl` saca de `sprites/bike_synth.coe` (`-testplusarg bike_mem=<archivo>`)
- `build_game_top.tcl`: corre los testbenches y construye `game_top` desde el repositorio. Requiere Linux y Vivado completo. Desde la raíz, con una carpeta de salida nueva: `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR [quick|sim|full]`. `quick` corre las pruebas de cada módulo (unos 20 s) y salta `game_top_tb`, que tarda hasta 20 min; sirve mientras se trabaja. `sim` corre todas, y `full` además construye el bitstream; uno de los dos antes de un push o un PR. Corre también `round_fsm_tb`, `step_counter_tb`, `bike_move_tb`, `bike_glide_tb`, los 9 escenarios de `game_top_tb`, estos con `sim_models/bike_rom.sv`, las 4 pruebas de la arena, las del marcador y las de la partida (`match_fsm_tb`, `score_unit_tb`, `seg7_link_tb`, `match_tb`). En `full` genera `clk_wiz_0` y `bike_rom` del catálogo de IP
- `bitstreams/`: bitstreams probados y lo que se comprobó de cada uno
- `prototypes/vga_106mhz/`: experimento a 106.5 MHz, fuera del hito; conserva el error del reset de PR 11
- `Contrato de interfaces game_top (CS 256).md`: contrato del equipo
- `cs256-project1-fall26.pdf`: presentación del proyecto
- `deprecated/`: versiones anteriores de este README y del contrato, solo como referencia
