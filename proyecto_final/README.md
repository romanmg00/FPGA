# Proyecto final: Tron en VGA

Tarjeta Nexys A7-100T, salida VGA **1280x800** (diapositiva 7 del curso) con reloj de
píxel de **83.46 MHz**. El estado del juego corre con un reloj de **~60 Hz** que sale
del segundo Clocking Wizard más un divisor, como pidieron los TAs
([ADR 0002](../docs/adr/0002-follow-ta-divided-game-clock.md)).

- Reglas: [especificación acordada del 20 de octubre](../docs/decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md)
  (bloqueada; manda sobre este README y el contrato)
- Contrato de interfaces (módulos, señales, reparto y fechas):
  [`Contrato de interfaces game_top (CS 256).md`](Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md).
  Las interfaces que la especificación deja abiertas están marcadas como pendientes
- Diseño de video y sprites: [plan de VGA y sprites](../docs/design/CS-256%20VGA%20and%20Sprite%20Design%20Plan.md)
  y [prácticas de código del curso](../docs/design/CS-256%20Official%20FPGA%20Coding%20Practices.md)
- Modelo de referencia: el equipo eligió **un solo modelo de reglas sin gráficos** en
  el repositorio. Mientras se migra, `../prototipos/tron/` y `../prototipos/tron_fpga/model/`
  son puntos de partida y todavía siguen las reglas anteriores
- Presentación del curso: `cs256-project1-fall26.pdf`
- Pines: `../nexys-a7-100t-master.xdc`
- Versiones anteriores de este README y del contrato: [`deprecated/`](deprecated/)

## Avance (un paso a la vez)

- [x] **Paso 1:** contador horizontal en simulación
- [x] **Paso 1b:** contador horizontal de 0 a 1679 (11 bits), en `counters.sv`
- [x] **Paso 2:** contador vertical de 0 a 827, avanza cuando el horizontal da la
  vuelta, en `counters.sv`
- [ ] **Paso 3:** `vga_out`. Ya tiene pulsos de sync, blanking y `curr_x`/`curr_y`, y
  `vga_out_tb.sv` revisa el pulso de `hsync`, las 1680 cuentas por línea y el color
  fuera del área visible. Falta correr y anotar el testbench en Icarus y en Vivado,
  y decidir qué pasa con `tick_60hz` (hoy siempre vale 0): con el ADR 0002 el reloj
  de juego sale del divisor, no de `vga_out`
- [ ] **Paso 4:** Clocking Wizard a 83.46 MHz y segundo reloj con divisor a ~60 Hz;
  imagen estable en la tarjeta con el borde blanco de 10 px
- [ ] **Paso 5:** `drawcon` con la arena en colores planos; después, sprites desde ROM
  (`.coe` RGB444, motos de 32x32 y premios de 16x16)

## Archivos

- `counters.sv`: contadores horizontal (0–1679) y vertical (0–827)
- `counters_tb.sv`: testbench de los contadores
- `vga_out.sv`: sync, blanking y `curr_x`/`curr_y` (`tick_60hz` todavía en 0)
- `vga_out_tb.sv`: testbench de `vga_out`
- `Contrato de interfaces game_top (CS 256).md`: contrato del equipo
- `cs256-project1-fall26.pdf`: presentación del proyecto
- `deprecated/`: versiones anteriores de este README y del contrato, solo como referencia
