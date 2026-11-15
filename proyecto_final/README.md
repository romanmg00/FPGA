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
- [ ] **Paso 6b:** segunda moto y choques entre motos (mismo destino, cabeza de la otra,
  intercambio). P2 sale de (59, 27) hacia la izquierda y por ahora avanza recto; su entrada
  `turn_req2` espera el teclado. `position_logic_tb` pasa en Verilator; falta la tarjeta (PR #25)
- [ ] **Paso 6c:** paso de 8 a 10 ticks en vez de 6 (ADR 0007, issue #22)
- [ ] **Paso 6d:** choque con estelas y premios, leyendo las celdas destino de `arena_map`

## Hito: bloque en movimiento (revisión del 12 de noviembre)

> Este hito describe el bloque de antes del PR #21. Desde entonces `game_top` muestra motos
> que avanzan solas en rondas (pasos 6a y 6b).

Según el código, `game_top` muestra un bloque de 16x16 que se mueve con los botones y se
detiene en las paredes. CPU_RESET lo regresa a (320, 432) si se mantiene al menos unos
17 ms; con menos, se reinicia el video, pero el bloque se puede quedar donde estaba. BTNC
lo lleva al centro, (632, 392). Su color sale de `SW0`–`SW11`: **con todos abajo es negro
y no se ve.**

El bitstream probado, los resultados en la tarjeta y los límites están en
[`bitstreams/README.md`](bitstreams/README.md). Es `game_top_one_wizard.bit`, con un solo
Wizard; en la tarjeta se probaron también las paredes y el reset repetido.

## Archivos

- `prototypes/uart_input/`: [experimento UART aislado](prototypes/uart_input/README.md), con receptor, decodificador y FIFO. Pasa las pruebas de XSim; genera bitstream con temporización verificada y revisión del catálogo IP. Los [resultados y límites](../docs/design/CS-256%20UART%20Input%20Prototype%20Findings.md) documentan las advertencias CDC y la integración pendiente con `game_top`.
- `game_top.sv`: tope del diseño. Conecta el Clocking Wizard, el contador de `clk_juego`, los sincronizadores y los bloques de abajo
- `position_logic.sv`: las dos motos, en `clk_juego`: control de ronda, ritmo del paso, giros y choques
- `round_fsm.sv`: ronda provisional: espera Start, corre, pausa tras un choque y espera que se suelte Start
- `step_counter.sv`: un pulso cada `STEP_TICKS` ticks; marca el paso (6) y la pausa de choque (120)
- `bike_move.sv`: celda, dirección y giro pendiente de una moto; se instancia una vez por moto
- `drawcon.sv`: color de cada píxel: paredes, HUD, P1 en azul (`0DF`) y P2 en naranja (`F80`)
- `counters.sv`: contadores horizontal (0–1679) y vertical (0–827)
- `vga_out.sv`: sync, blanking y `curr_x`/`curr_y` (`tick_60hz` todavía en 0)
- `sync_2ff.sv`: sincronizador de 2 flip-flops para botones y switches
- `board_reset_sync.sv`: lleva CPU_RESET a cada dominio de reloj
- `game_top.xdc`: pines y configuración de la tarjeta para `game_top`
- `game_top_timing.xdc`: reloj generado de `clk_juego` y excepciones de temporización; solo para implementación
- `ip/clk_wiz_0/clk_wiz_0.xci`: IP del reloj de píxel para el proyecto de Roman; `build_game_top.tcl` no lo lee y genera el Wizard. Ver el [inventario de IP](../docs/design/CS-256%20Vivado%20IP%20Inventory.md)
- `game_top_tb.sv`: revisa `game_top` desde sus pines, con 6 escenarios. Todavía describe el bloque de antes del PR #21 (issue #24)
- `position_logic_tb.sv`, `round_fsm_tb.sv`, `step_counter_tb.sv`, `bike_move_tb.sv`, `sync_2ff_tb.sv`, `board_reset_sync_tb.sv`, `vga_out_tb.sv`, `counters_tb.sv`: testbenches de cada bloque. `counters_tb.sv` no corre en `build_game_top.tcl`
- `sim_clocks/`: relojes ideales **solo para simulación**. La síntesis usa siempre la IP que genera Vivado; ver el [inventario de IP](../docs/design/CS-256%20Vivado%20IP%20Inventory.md)
- `build_game_top.tcl`: corre los testbenches y construye `game_top` desde el repositorio. Requiere Linux y Vivado completo. Desde la raíz, con una carpeta de salida nueva: `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR [sim|full]`. Desde el PR #21 le faltan `round_fsm.sv`, `step_counter.sv` y `bike_move.sv` (issue #24)
- `bitstreams/`: bitstreams probados y lo que se comprobó de cada uno
- `prototypes/vga_106mhz/`: experimento a 106.5 MHz, fuera del hito; conserva el error del reset de PR 11
- `Contrato de interfaces game_top (CS 256).md`: contrato del equipo
- `cs256-project1-fall26.pdf`: presentación del proyecto
- `deprecated/`: versiones anteriores de este README y del contrato, solo como referencia
