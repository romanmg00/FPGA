# `proyecto_final/`: step log (Pasos 1–7d)

Moved here from `proyecto_final/README.md` on 18 November 2026, when that README was rewritten in English. The text is unchanged and stays in Spanish; only the relative links were rebased for this folder. The current state of the hardware is in [`proyecto_final/README.md`](../../proyecto_final/README.md).

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
  imagen en la tarjeta el 12 de noviembre; el estado está en el [mapa de arquitectura](../CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md#architecture-and-ownership)
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
  ([ADR 0010](../adr/0010-bikes-sliding-between-cells.md), aceptado; PRs #28 y #35). `STEP_TICKS` vive en `game_top`; cambiarlo de nuevo es una línea
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
  Scoreboard*, y [ADR 0008](../adr/0008-scoreboard-goal-page-before-a-match.md)), por partes:
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
    9 puntos). Plan: [`docs/plan/CS-256 Match Lifecycle and Scoreboard Plan.md`](../plan/CS-256%20Match%20Lifecycle%20and%20Scoreboard%20Plan.md)
  - [x] **7d:** en `game_top`: `sw[15:0]` (`SW0` pausa, `{SW15, SW14}` meta), pines `seg`, `dp`
    y `an`, y `seg7_link`, que cruza los 20 bits del marcador de `clk_juego` a `clk_pix` (toggle
    y copia, como la arena). `match_tb` juega partidas enteras en `clk_juego`; `game_top_tb` lee
    el marcador de los pines (escenarios `match` y `pause`). Probado en la tarjeta el 17 de noviembre con [`game_top_match_scoreboard.bit`](../../proyecto_final/bitstreams/README.md)

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
[`bitstreams/README.md`](../../proyecto_final/bitstreams/README.md) guarda solo el último bitstream probado
(`game_top_two_bikes.bit`), con sus resultados y límites.
