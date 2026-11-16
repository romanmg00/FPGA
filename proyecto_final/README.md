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
- [ ] **Paso 5b:** `drawcon` lee de `arena_map` lo que hay en cada celda
- [ ] **Paso 5c:** sprites desde ROM (`.coe` RGB444, motos de 32x32 y premios de 16x16)
- [x] **Paso 6a:** una moto que avanza sola en rondas (`round_fsm`, `step_counter`, `bike_move`):
  Start con BTNC, giros de 90°, choque con la pared y pausa de 2 s. Probada en la tarjeta el
  12 de noviembre (PR #21)
- [x] **Paso 6b:** segunda moto y choques entre motos (mismo destino, cabeza de la otra,
  intercambio). P2 sale de (59, 27) hacia la izquierda y por ahora avanza recto; su entrada
  `turn_req2` espera el teclado. `position_logic_tb` pasa en Verilator; probada en la tarjeta
  el 15 de noviembre con `game_top_two_bikes.bit` (PR #25)
- [x] **Paso 6c:** intervalo del paso (ADR 0007, issue #22). En la tarjeta, el 15 de noviembre,
  8 ticks se veían lentos y a saltos; se eligió **6** (unas 10 celdas/s) con las motos
  deslizándose entre celdas ([ADR 0010](../docs/adr/0010-six-tick-steps-and-bikes-sliding-between-cells.md),
  propuesto; PR #28). `STEP_TICKS` vive en `game_top`; cambiarlo de nuevo es una línea
- [x] **Paso 6e:** `bike_glide` dibuja cada moto avanzando unos píxeles por tick (0, 3, 5, 8, 11,
  13, 16 con 6 ticks) hacia su celda; el juego sigue por celdas y lo dibujado va un paso atrás.
  Su salida es un registro, así que la cuenta no entra a la ruta de `clk_pix`
- [ ] **Paso 6d:** choque con estelas y premios, leyendo las celdas destino de `arena_map`
- [ ] **Paso 7:** marcador físico en los 8 dígitos de 7 segmentos (especificación, *Physical
  Scoreboard*, y [ADR 0008](../docs/adr/0008-scoreboard-goal-page-before-a-match.md)), por partes:
  - [x] **7a:** `sevenseg` y `multidigit` de la tarea 1 del curso, con las letras P, L, G, A y
    el dígito en blanco (códigos 16–20 de `game_pkg.sv`; 0–F siguen siendo hex). `multidigit`
    barre en `clk_pix` y avanza de dígito con una habilitación cada 10,432 ciclos (~1 kHz por
    dígito), sin reloj nuevo (ADR 0006). Solo en simulación: `sevenseg_tb` y `multidigit_tb`
    pasan en XSim; todavía no están en `game_top`
  - [x] **7b:** las vistas. `seg7_view`, en `clk_juego`, cambia de vista cada 180 ticks (3 s):
    puntos → vidas y, mientras se espera una partida nueva, → meta; mover `{SW15, SW14}` en esa
    espera salta a la meta y reinicia sus 3 s, y una partida nueva empieza en puntos. Sigue a
    `PageTimer` del modelo. `seg7_driver`, en `clk_pix`, arma los 8 dígitos (`P2nnP1nn`,
    `L20nL10n`, `G0AL  n0`) y los barre con `multidigit`. Solo en simulación: `seg7_view_tb`
    (una prueba por regla del ADR 0008) y `seg7_driver_tb` pasan en XSim
  - [ ] **7c:** partida, vidas y puntos (G3/G5), sin premios
  - [ ] **7d:** en `game_top`: `sw[15:0]`, pines `seg`, `dp` y `an`, y el cruce de los valores a
    `clk_pix` (issue #30)

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
- `round_fsm.sv`: ronda provisional: espera Start, corre, pausa tras un choque y espera que se suelte Start
- `step_counter.sv`: un pulso cada `STEP_TICKS` ticks; marca el paso (6, ADR 0010) y la pausa de choque (120)
- `bike_glide.sv`: posición dibujada de una moto, que se desliza de su celda anterior a la nueva durante un paso (ADR 0010); una instancia por moto
- `bike_move.sv`: celda, dirección y giro pendiente de una moto; se instancia una vez por moto
- `drawcon.sv`: color de cada píxel: paredes, HUD, P1 en azul (`0DF`) y P2 en naranja (`F80`)
- `game_pkg.sv`: constantes compartidas del contrato (sección 5). Por ahora solo las del marcador: códigos de glifo, `SCORE_VIEW_TICKS` y las vistas; cada constante se agrega cuando un módulo la usa
- `sevenseg.sv`: decodificador de 7 segmentos de la tarea 1, activo en bajo: códigos de 5 bits, 0–F como en la tarea y P, L, G, A y blanco del marcador
- `multidigit.sv`: los 8 dígitos con un solo juego de segmentos, como en la tarea 1, en `clk_pix` con una habilitación (~1 kHz por dígito)
- `seg7_view.sv`: qué vista muestra el marcador (puntos, vidas o meta), en `clk_juego`, cada 3 s (ADR 0008)
- `seg7_driver.sv`: el marcador en `clk_pix`: de puntos, vidas, vista y meta a los 8 dígitos, con `multidigit`
- `counters.sv`: contadores horizontal (0–1679) y vertical (0–827)
- `vga_out.sv`: sync, blanking y `curr_x`/`curr_y` (`tick_60hz` todavía en 0)
- `sync_2ff.sv`: sincronizador de 2 flip-flops para botones y switches
- `board_reset_sync.sv`: lleva CPU_RESET a cada dominio de reloj
- `game_top.xdc`: pines y configuración de la tarjeta para `game_top`
- `game_top_timing.xdc`: reloj generado de `clk_juego` y excepciones de temporización; solo para implementación
- `ip/clk_wiz_0/clk_wiz_0.xci`: IP del reloj de píxel para el proyecto de Roman; `build_game_top.tcl` no lo lee y genera el Wizard. Ver el [inventario de IP](../docs/design/CS-256%20Vivado%20IP%20Inventory.md)
- `game_top_tb.sv`: revisa `game_top` desde sus pines, con 6 escenarios. Todavía describe el bloque de antes del PR #21 (issue #24)
- `position_logic_tb.sv`, `round_fsm_tb.sv`, `step_counter_tb.sv`, `bike_move_tb.sv`, `sevenseg_tb.sv`, `multidigit_tb.sv`, `seg7_view_tb.sv`, `seg7_driver_tb.sv`, `sync_2ff_tb.sv`, `board_reset_sync_tb.sv`, `vga_out_tb.sv`, `counters_tb.sv`: testbenches de cada bloque. `counters_tb.sv` no corre en `build_game_top.tcl`
- `sim_clocks/`: relojes ideales **solo para simulación**. La síntesis usa siempre la IP que genera Vivado; ver el [inventario de IP](../docs/design/CS-256%20Vivado%20IP%20Inventory.md)
- `build_game_top.tcl`: corre los testbenches y construye `game_top` desde el repositorio. Requiere Linux y Vivado completo. Desde la raíz, con una carpeta de salida nueva: `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR [sim|full]`. Corre también `round_fsm_tb`, `step_counter_tb`, `bike_move_tb`, `bike_glide_tb` y los 7 escenarios de `game_top_tb` (PR #28), y `sevenseg_tb`, `multidigit_tb`, `seg7_view_tb` y `seg7_driver_tb` (Pasos 7a y 7b)
- `bitstreams/`: bitstreams probados y lo que se comprobó de cada uno
- `prototypes/vga_106mhz/`: experimento a 106.5 MHz, fuera del hito; conserva el error del reset de PR 11
- `Contrato de interfaces game_top (CS 256).md`: contrato del equipo
- `cs256-project1-fall26.pdf`: presentación del proyecto
- `deprecated/`: versiones anteriores de este README y del contrato, solo como referencia
