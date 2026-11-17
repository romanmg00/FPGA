# Bitstreams

Aquí va solo el último bitstream probado, para llevarlo a la revisión con el TA y poder repetir las pruebas. Los anteriores se borran de la carpeta, pero su registro se queda abajo y el archivo se recupera del historial de Git. Programar por JTAG no se guarda: con el botón PROG o al apagar la tarjeta, la FPGA carga lo que tenga en su flash. En la tarjeta de Alan eso es la prueba vieja de cuatro cuadrantes, no una falla del diseño.

## `game_top_match_scoreboard.bit`

El bitstream para mostrar: la partida y el marcador físico (Pasos 7c y 7d, PRs #46 y #47) sobre las dos motos, la arena y los sprites. Start con BTNC empieza la partida; cada choque quita una vida y da +3 a la moto que no chocó; con 3 vidas perdidas la partida termina y las motos se quedan donde chocaron; otro Start empieza una partida nueva. El display muestra puntos y vidas, y la meta mientras se espera una partida. `SW0` pausa; `{SW15, SW14}` eligen la meta. P2 sigue yendo recto (`turn_req2` en 0, sin UART). **Este es el probado en la tarjeta.**

| | |
|---|---|
| SHA-256 | `adc1c04091c8357562a3eba754fbe21dbc056c2901527342656c03a789f73bba` |
| Fuente | Rama `feat/scoreboard-game-top`, commit `efdbb72`. El diseño (`.sv` fuera de las pruebas, `.xdc`, IP) es el mismo desde `7b3b106` |
| Cómo se construye | `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR full`, en el contenedor Ubuntu 24.04 de `alan-desktop` (corrida `run-20261117-161640-Lw7Hgc`) |
| Herramienta | Vivado 2025.2, 17 de noviembre de 2026 |
| Parte | `xc7a100tcsg324-1` |

### Prueba en la tarjeta

Nexys A7 serial `210292B1820D`, programada por JTAG desde `alan-desktop` (DONE en alto). Observó Alan el 17 de noviembre de 2026. Todas pasan.

| Prueba | Esperado |
|---|---|
| Arranque, switches abajo | Motos en sus salidas; el display rota `P2 00 P1 00` → `L2 03 L1 03` → `GOAL  10`, 3 s cada una, sin puntos decimales |
| `SW14` arriba | Salta a `GOAL  20` (`SW15` 30, los dos 40) |
| BTNC | Empieza la ronda; el display solo alterna puntos y vidas |
| P1 contra una pared o estela | Las dos motos se detienen; a los 2 s vuelven a la salida; P1 con 2 vidas y P2 con 3 puntos |
| Tres choques de P1 | Las motos se quedan donde chocaron y BTNC ya no arranca ronda; `P2 09`, `P1 00`, `L1 00`, y vuelve la vista de meta |
| BTNC | Partida nueva: estelas borradas, motos en la salida, `00` y `03` |
| `SW0` a media ronda | Las motos se congelan y los botones no giran; el display sigue; al bajarlo siguen |
| BTNC sostenido durante CPU_RESET | No arranca nada hasta soltarlo y presionarlo de nuevo |
| Choque de frente | Las dos pierden una vida, sin +3 |

### Simulación y reportes

- **Testbenches:** los 29 de `build_game_top.tcl` pasan, entre ellos `match_tb` y los escenarios `match` y `pause` de `game_top_tb`, que leen el display de los pines.
- **Temporización con el diseño ya ruteado:** setup +3.950 ns (WNS), hold +0.122 ns (WHS), ancho de pulso +3.000 ns; `check_timing` sin entradas ni extremos sin restricción.
- **`report_cdc`:** las mismas 12 filas CDC-1 de las posiciones (issue #30) y 20 CDC-13 de los sprites que en `main`; CDC-3 sube de 9 a 13 (pausa, los dos bits de la meta y el toggle de `seg7_link`) y CDC-15 de 59 a 79 (los 20 bits que copia `seg7_link`). **Metodología:** `TIMING-8` y `TIMING-9`, como en `main`.

## Bitstreams anteriores

Ya no están en la carpeta. Para recuperar uno: `git show COMMIT:proyecto_final/bitstreams/NOMBRE.bit > NOMBRE.bit`, con `586b16e` para `game_top_two_bikes.bit`, `80b55f2` para `game_top_one_wizard.bit` y `dc029bf` para los demás.

## `game_top_two_bikes.bit` (anterior)

El bitstream para mostrar: dos motos que avanzan solas en rondas, con choques contra la pared y entre motos (PR 25). P1 gira con los botones; P2 va recto, porque `turn_req2` está fijo en `4'b0000` hasta que llegue el teclado. Fue el probado en la tarjeta hasta el `game_top_match_scoreboard.bit`.

| | |
|---|---|
| SHA-256 | `ab46d0e8d52e19e16dd05d44a3d41c4bfdef7f40f364ef16a21e76083a88fb92` |
| Fuente | Rama `hdl/second-bike`. El diseño (`.sv`, `.xdc`, IP) es el mismo desde `01cdcc8` hasta `80b55f2`; los commits de en medio solo cambian documentos. No se registró el commit exacto del checkout |
| Cómo se construye | Proyecto de Vivado en la estación remota `myws.kaust.edu.sa`, con las fuentes cargadas desde un clon del repo como en [comandos_vivado_myws.md](../comandos_vivado_myws.md). No usa `build_game_top.tcl`, que todavía describe el diseño de antes de PR 21 (issue 24) |
| Herramienta | Vivado 2020.2 de la estación remota, 15 de noviembre de 2026. Es otra versión que la 2025.2 de `alan-desktop`, con la que se hicieron los bitstreams anteriores |
| Parte | `xc7a100tcsg324-1` |

### Prueba en la tarjeta

Nexys A7 serial `210292B1820D`, programada por JTAG con `openFPGALoader` desde la Mac de Roman (DONE en alto). Observó Roman el 15 de noviembre de 2026. Todas pasan.

| Prueba | Esperado |
|---|---|
| Arranque | P1 (azul claro) a la izquierda avanza a la derecha; P2 (naranja) a la derecha avanza a la izquierda |
| Sin tocar nada | P2 va recto; las motos se encuentran de frente y la ronda termina |
| P1 contra una pared, con los botones | P1 se detiene, P2 completa su paso y la ronda termina |
| CPU_RESET | Las dos motos regresan a sus posiciones de inicio |

**Observación sin confirmar:** a Roman le pareció que P1 se dibuja unos píxeles más abajo que P2. En el código las dos salen en la misma fila (`START_CY = 27`, píxel y = 432) y `drawcon` las dibuja igual, así que puede ser una impresión por los colores. Para confirmarlo, dejar que choquen de frente y comparar los bordes de arriba con las dos juntas.

### Simulación y reportes

- **Testbenches:** `position_logic_tb`, `bike_move_tb` y `round_fsm_tb` pasan en Verilator 5.052 (ver PR 25). `game_top_tb` no se corrió: todavía describe el diseño de antes de PR 21 (issue 24).
- **Capturas de Vivado:** [setup y uso](evidencia/game_top_two_bikes_setup.png), [hold y critical warnings](evidencia/game_top_two_bikes_hold_y_mensajes.png).
- **Temporización con el diseño ya ruteado** (*Project Summary* de Vivado): setup +3.828 ns (WNS), TNS 0 ns, 0 de 110 extremos fallan; hold +0.156 ns (WHS), THS 0 ns, 0 de 110 extremos fallan. El ancho de pulso no se registró.
- **DRC:** sin violaciones. **CDC:** no se corrió `report_cdc`.
- **Mensajes:** síntesis con 5 warnings e implementación con 2 warnings, sin revisar todavía. Los 2 critical warnings de la implementación son `[Designutils 20-1280] Could not find module 'clk_wiz_1'`, uno por cada `.xdc` del IP (`clk_wiz_1.xdc` y `clk_wiz_1_board.xdc`). El proyecto de la estación todavía tiene el IP `clk_wiz_1`, que el diseño dejó de usar en el Paso 4c; como nada lo instancia, sus restricciones no se aplican y no afectan este build. Se quitan sacando el IP del proyecto (ver [comandos_vivado_myws.md](../comandos_vivado_myws.md)).

## `game_top_one_wizard.bit` (anterior)

El Paso 4c del [ADR 0006](../../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md), con un solo Clocking Wizard y `clk_juego` de un contador sobre `clk_pix`. Fue el probado en la tarjeta hasta `game_top_two_bikes.bit`.

| | |
|---|---|
| SHA-256 | `78411635b5c13bde1889155db73e5707b47c5b6113af913dd07bf9b666ecd0bd` |
| Fuente | Commit `dc029bf` de `main` |
| Cómo se construye | `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR full`, en el contenedor Ubuntu 24.04 de `alan-desktop` |
| Herramienta | Vivado 2025.2, 12 de noviembre de 2026 |
| Parte | `xc7a100tcsg324-1` |
| `clk_pix` lograda | 83,455,882 Hz (un solo MMCM, `clk_wiz_0`) |
| `clk_juego` lograda | 59.99997 Hz: alterna cada 695,466 ciclos de `clk_pix` y pasa por un `BUFG` |

### Prueba en la tarjeta

Nexys A7 serial `210292B1820D`, programada por JTAG (DONE en alto). Observó Alan el 12 de noviembre de 2026, en su monitor. Todas pasan.

| Prueba | Esperado |
|---|---|
| Arranque con todos los switches abajo | HUD gris y paredes blancas; el bloque es negro y no se ve |
| Subir algún switch de `SW0`–`SW11` | El bloque aparece en (320, 432) con ese color |
| Botones de dirección | El bloque se mueve y se detiene en las paredes |
| BTNC | El bloque va al centro, (632, 392) |
| CPU_RESET sostenido, varias veces | El bloque regresa a (320, 432) |
| Imagen | Estable, sin parpadeo |

### Simulación y reportes

- **Testbenches:** los 10 de `build_game_top.tcl` pasan (`sync_2ff_tb`, `board_reset_sync_tb`, `vga_out_tb`, `position_logic_tb` y 6 escenarios de `game_top_tb`). Son pruebas de quien hizo el código y usan `sim_clocks/`, así que no prueban el Wizard.
- **Temporización con el diseño ya ruteado:** setup +6.210 ns, hold +0.111 ns, ancho de pulso +3.000 ns. 0 registros sin reloj, 0 extremos internos sin restricción y 0 relojes múltiples.
- **DRC:** sin violaciones. **Metodología:** solo `TIMING-9`. **`report_cdc`:** las mismas 12 filas críticas de `blkpos` (ver *Tearing* abajo).
- **Log de construcción:** sin warnings.

Siguen pendientes los puntos de [Lo que falta](#lo-que-falta), salvo el de `clk_wiz_1`.

## `game_top_fixes.bit` (anterior)

El bitstream de las correcciones de PR 11, con dos Wizards. Fue el probado en la tarjeta hasta el `game_top_one_wizard.bit`.

| | |
|---|---|
| SHA-256 | `3553e9b59d4fef5fb14bfc71150346fb48029372c6e88cf090a0a1ea3ef9e511` |
| Fuente | Commit `9b78418`. Los commits posteriores cambian testbenches, el script y documentos, y agregan una restricción para el experimento `prototypes/vga_106mhz/`. Hasta el Paso 4c (ADR 0006), el diseño de `game_top` y sus restricciones no cambian; el Paso 4c cambia `game_top.sv`, `game_top_timing.xdc` y el script para quitar `clk_wiz_1` |
| Cómo se construye | Desde un checkout de `9b78418`: `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR full`, en el contenedor Ubuntu 24.04 de `alan-desktop`. Desde el Paso 4c, el mismo comando construye el diseño de un solo Wizard, no este bitstream |
| Herramienta | Vivado 2025.2, 4 de noviembre de 2026 |
| Parte | `xc7a100tcsg324-1` |
| `clk_pix` lograda | 83,455,882 Hz |
| `clk_juego` lograda | 59.9995 Hz (4,999,995 Hz / (2 × 41,667)) |

Los dos Wizards son IP generada por Vivado. Los ajustes de `clk_wiz_1` son deducidos, porque el `.xci` de Roman no está en el repositorio ([inventario de IP](../../docs/design/CS-256%20Vivado%20IP%20Inventory.md)).

### Prueba en la tarjeta

Nexys A7 serial `210292B1820D`, programada por JTAG (DONE en alto). Observó Alan el 4 de noviembre de 2026, en su monitor.

| Prueba | Esperado | Resultado |
|---|---|---|
| Arranque con todos los switches abajo | HUD gris y paredes blancas; el bloque es negro y no se ve | Pasa |
| Subir `SW0`–`SW11` | El bloque aparece en (320, 432) con ese color | Pasa |
| CPU_RESET | El bloque regresa a (320, 432) | Pasa |
| BTNC | El bloque va al centro, (632, 392) | Pasa |

Las paredes se probaron en la tarjeta con el build anterior (`e3b324cc…`, de `a8827e1`), junto con CPU_RESET varias veces. Entre ese build y este solo cambió el color del bloque con todos los switches abajo, en `drawcon.sv`. Este build no se volvió a probar en las paredes ni con reset repetido.

**Para la demostración: hay que subir algún switch de `SW0`–`SW11`.** Con todos abajo el bloque no se ve.

### Simulación y reportes

- **Testbenches:** `vga_out_tb`, `position_logic_tb`, `game_top_tb`, `sync_2ff_tb` y `board_reset_sync_tb` pasan con el mismo diseño. Son pruebas de quien hizo el código, no las oficiales del contrato (sección 7). Usan `sim_clocks/`, relojes ideales, así que no prueban los Wizards.
- **Temporización con el diseño ya ruteado:** setup +5.657 ns, hold +0.122 ns, ancho de pulso +2.991 ns. 0 registros sin reloj, 0 extremos internos sin restricción y 0 relojes múltiples.
- **DRC:** sin violaciones. **Metodología:** solo `TIMING-9`, por el cruce de abajo.
- **Log de construcción:** sin warnings.

### Reconstruir no da el mismo archivo

Otro build del mismo diseño y las mismas restricciones (`02d28845…`) dio la misma temporización peor, pero difiere en 950 de los 3,825,744 bytes de configuración. No se investigó la causa. **El probado en la tarjeta de este diseño es `3553e9b5…`;** cualquier otro `.bit` necesita su propia prueba.

### Lo que falta

- **CPU_RESET muy corto.** Con un pulso de menos de unos 17 ms, en simulación se reinicia el video pero el bloque se queda donde estaba, porque puede no llegar un flanco de `clk_juego` (5, 10 y 15 ms fallan; 17 y 35 ms pasan). Se corrige alargando el reset, lo que cambia el hardware y pide otro build y otra prueba en la tarjeta.
- **Tearing.** `blkpos` sigue cruzando directo de `clk_juego` a `clk_pix`, sin un cruce explícito (X1), así que el bloque se puede ver cortado. Las 12 filas críticas de `report_cdc` y `TIMING-9` son este cruce: la restricción limita el retardo, pero no lo hace seguro.
- **Testbench colgado.** Ningún testbench tiene límite de tiempo real. Si uno se cuelga, `build_game_top.tcl` no publica el bitstream, pero tampoco termina con error.
- **Diagonales.** Se prueban en `position_logic_tb`, pero no en `game_top_tb`, así que un error de conexión que afecte solo a las diagonales no se detecta.
- **Salidas VGA.** No tienen retardo de salida, porque el monitor no da una especificación de tiempos. No se inventó una.
- **`clk_wiz_1` encadenado.** Resuelto en `game_top_one_wizard.bit`. Este bitstream todavía lo tiene, saliendo de `clk_pix` como en PR 11. El código actual ya no lo usa: por el [ADR 0006](../../docs/adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md) (issue 10), `clk_juego` sale de un contador de 20 bits sobre `clk_pix` (Paso 4c); su estado está en el [mapa de arquitectura](../../docs/CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md#architecture-and-ownership).
- **Botones.** Se leen a 60 Hz, sin quitar rebotes: una pulsación de menos de unos 17 ms se puede perder. `btn_debounce` sigue por hacer.
- **Borde blanco de 10 px.** Falta arriba: la franja del HUD llega en gris hasta la orilla de la pantalla. El handout y la especificación acordada piden el borde.
- **Tamaño del bloque.** Es de 16×16 por elección de PR 11, para coincidir con la celda. El handout pide unos 32×32.
- **`CFGBVS`.** El valor no se encontró en un documento oficial de Digilent (ver `game_top.xdc`).

## `game_top_pr11_asis.bit` (anterior)

Código de PR 11 **sin cambios**, para probarlo tal como está.

| | |
|---|---|
| SHA-256 | `2d54c47c94d467b4448dfcfee783248172fd6ce827f9d4e485ec8ab3781bdcca` |
| Fuente | Commit `e5407d8` de `v4/moving-block` |
| Herramienta | Vivado 2025.2, contenedor Ubuntu 24.04 de `alan-desktop`, 4 de noviembre de 2026 |
| Parte | `xc7a100tcsg324-1` |
| `clk_pix` lograda | 83,455,882 Hz |
| Base de `clk_juego` lograda | 4,999,995 Hz, que da unos 60 Hz |

**No es idéntico al bitstream de Roman.** `clk_wiz_1.xci` no está en el repositorio (solo en rsws08), así que se regeneró del catálogo con lo que se deduce de `game_top.sv`:

```tcl
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_1
set_property -dict [list CONFIG.PRIM_IN_FREQ 83.456 CONFIG.PRIM_SOURCE No_buffer \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 5.000 CONFIG.USE_RESET false CONFIG.USE_LOCKED false] [get_ips clk_wiz_1]
```

`clk_wiz_0.xci` se importó del repositorio y Vivado 2025.2 lo actualizó: es de Vivado 2020.2 y de otra parte (`xc7vx485t`).

### Hallazgo: CPU_RESET no regresa el bloque

PR 11 dice que CPU_RESET regresa el bloque a (320, 432). **Con este código no lo hace**, ni en simulación ni en la tarjeta. La prueba de PR 11 se hizo con `game_top_v3_botones.bit`, que no se pudo revisar, así que ese bitstream pudo venir de otra versión del código.

**Causa.** El divisor mantiene `clk_juego` en 0 mientras `rst` está activo. `position_logic` tiene reset síncrono en `clk_juego`, así que necesita un flanco de subida para ver el reset, y durante el reset no hay ninguno. Al soltar el botón, el siguiente flanco llega unos 8 ms después, con `rst` ya en 0.

| Prueba | Resultado |
|---|---|
| XSim, relojes ideales, reset de 20, 100 y 500 ms | 0 flancos de `clk_juego` durante el reset; el bloque se queda en (72, 72) |
| XSim, el mismo código con el divisor sin reset | El bloque regresa a (320, 432) con los tres tiempos |
| Tarjeta: CPU_RESET | La pantalla se pone negra mientras se presiona y el juego regresa con el bloque **en la misma posición** |
| Tarjeta: PROG | La pantalla se pone negra y aparecen los cuatro cuadrantes de la flash. No es de este código |

Tarjeta: Nexys A7 serial `210292B1820D`, programada por JTAG (DONE en alto). Observó Alan el 4 de noviembre de 2026. Por lo demás, el diseño funcionó en la tarjeta.

### Otros puntos que se siguen del código

No se registraron como prueba en la tarjeta.

- Sin reset que funcione, `blkpos` arranca en (0, 0), debajo de la pared y el HUD, así que el bloque no se ve hasta moverlo a la derecha y hacia abajo.
- Con todos los switches `sw[11:0]` abajo, el bloque es negro sobre negro.
- `btn[4]` (BTNC) no hace nada. El paso 12 del handout pide que centre el bloque.

### Reporte de Vivado

Setup +5.969 ns y hold +0.106 ns, con "All user specified timing constraints are met". **Eso no cubre la lógica del bloque**, porque `clk_juego` no tiene restricción:

- `check_timing`: 18 registros sin reloj y 54 extremos internos sin restricción.
- Metodología: `TIMING-17` y `TIMING-6` (críticas).
- `report_cdc`: 168 filas críticas. Botones, switches y reset no tienen sincronizador.
- `clk_juego` no pasa por un `BUFG`.

### Lo que esto no muestra

La simulación usó relojes ideales en lugar de los Wizards. No se midió el comportamiento con otro monitor ni se repitió con el `clk_wiz_1` real de Roman.
