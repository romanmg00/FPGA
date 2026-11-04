# Bitstreams

Los bitstreams van aquí para llevarlos a la revisión con el TA y poder repetir las pruebas. Programar por JTAG no se guarda: con el botón PROG o al apagar la tarjeta, la FPGA carga lo que tenga en su flash. En la tarjeta de Alan eso es la prueba vieja de cuatro cuadrantes, no una falla del diseño.

## `game_top_fixes.bit`

`v4/moving-block-fixes` con las correcciones de PR 11. **Este es el probado en la tarjeta, pero ya no coincide con el código actual:** viene de `a8827e1`, donde con todos los switches abajo el bloque es cian. Ahora el bloque se queda negro, como en PR 11, así que con todos los switches abajo no se ve. Este archivo se reemplaza cuando el build nuevo pase la prueba en la tarjeta.

| | |
|---|---|
| SHA-256 | `e3b324cc79eaac91554048e09a3c6999a15ed069b0214ea7cf4f73196bfb49c2` |
| Fuente | Commit `a8827e1`: los archivos del diseño son idénticos byte por byte a los de este build |
| Cómo se construye | `vivado -mode batch -source proyecto_final/build_game_top.tcl -tclargs OUT_DIR full`, en el contenedor Ubuntu 24.04 de `alan-desktop` |
| Herramienta | Vivado 2025.2, 4 de noviembre de 2026 |
| Parte | `xc7a100tcsg324-1` |
| `clk_pix` lograda | 83,455,882 Hz |
| `clk_juego` lograda | 59.9995 Hz (4,999,995 Hz / (2 × 41,667)) |

Los dos Wizards son IP generada por Vivado. Los ajustes de `clk_wiz_1` son deducidos, porque el `.xci` de Roman no está en el repositorio ([inventario de IP](../../docs/design/CS-256%20Vivado%20IP%20Inventory.md)).

### Prueba en la tarjeta

Nexys A7 serial `210292B1820D`, programada por JTAG (DONE en alto). Observó Alan el 4 de noviembre de 2026, en su monitor.

| Prueba | Esperado | Resultado |
|---|---|---|
| Arranque con todos los switches abajo | HUD gris, paredes blancas, bloque cian en (320, 432) | Pasa |
| Subir `SW0`–`SW11` | El bloque cambia de color | Pasa |
| Los cuatro botones de dirección | Se mueve y se detiene en cada pared | Pasa |
| CPU_RESET, varias veces | Negro mientras se presiona; el bloque regresa a (320, 432) | Pasa |
| BTNC | El bloque va al centro, (632, 392) | Pasa |

### Simulación y reportes

- **Testbenches:** `vga_out_tb`, `position_logic_tb` y `game_top_tb` pasan. Son pruebas de quien hizo el código, no las oficiales del contrato (sección 7). Usan `sim_clocks/`, relojes ideales, así que no prueban los Wizards.
- **Temporización con el diseño ya ruteado:** setup +5.215 ns, hold +0.121 ns, ancho de pulso +2.991 ns. 0 registros sin reloj, 0 extremos internos sin restricción y 0 relojes múltiples.
- **DRC:** sin violaciones. **Metodología:** solo `TIMING-9`, por el cruce de abajo.
- **Log de construcción:** sin warnings.

### Lo que falta

- **Tearing.** `blkpos` sigue cruzando directo de `clk_juego` a `clk_pix`, sin un cruce explícito (X1), así que el bloque se puede ver cortado. Las 12 filas críticas de `report_cdc` y `TIMING-9` son este cruce: la restricción limita el retardo, pero no lo hace seguro.
- **Salidas VGA.** No tienen retardo de salida, porque el monitor no da una especificación de tiempos. No se inventó una.
- **`clk_wiz_1` encadenado.** Sigue saliendo de `clk_pix` como en PR 11; se discute en el issue 10.
- **Botones.** Se leen a 60 Hz: una pulsación de menos de unos 17 ms se puede perder.
- **`CFGBVS`.** El valor no se encontró en un documento oficial de Digilent (ver `game_top.xdc`).

## `game_top_pr11_asis.bit`

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
