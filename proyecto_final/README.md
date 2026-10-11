# Proyecto final: Tron en VGA

Tarjeta Nexys A7-100T, salida VGA **1280x800** (diapositiva 7 del curso).

- Contrato de interfaces (módulos, señales, reparto y fechas):
  `Contrato de interfaces game_top (CS 256).md`
- Modelo de referencia en Python: `../prototipos/tron/`
- Presentación del curso: `cs256-project1-fall26.pdf`

## Avance (un paso a la vez)

- [x] **Paso 1:** contador horizontal en simulación (hecho para 640x480, de 0 a 799)
- [ ] **Paso 1b:** cambiar el contador a 1280x800: cuenta de 0 a 1679 y necesita 11 bits; el testbench debe medir 1680 ciclos por vuelta
- [ ] Paso 2: contador vertical (0 a 827, avanza cuando el horizontal da la vuelta)
- [ ] Paso 3: `vga_out` completo: pulsos de sync, blanking, `curr_x`/`curr_y` y `tick_60hz`

## Archivos

- `counters.sv`: contador horizontal (todavía 0–799)
- `counters_tb.sv`: testbench del contador
- `Contrato de interfaces game_top (CS 256).md`: contrato del equipo
- `cs256-project1-fall26.pdf`: presentación del proyecto
