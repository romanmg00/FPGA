# Mountain Crash

Nuestro primer proyecto de FPGA: un videojuego donde un avión vuela entre
montañas (vista desde arriba). Se controla **inclinando la tarjeta**: el
acelerómetro mide la inclinación y el avión gira a la izquierda o derecha, más
rápido mientras más se incline. Se muestra por **VGA 640x480**.

- **Tarjeta:** Digilent Nexys A7 (Artix-7)
- **Herramienta:** Vivado, Verilog
- **Entrada:** acelerómetro ADXL362 integrado (SPI) + botón central BTNC
- **Salida:** VGA 4 bits por canal + display de 7 segmentos para el puntaje

## Estructura

```
prototipo_python/   Prototipo jugable en Python (modelo de referencia)
  config.py         Constantes: resolución, tiles, paleta RGB444, reglas
  juego.py          Lógica pura (sin pygame): LFSR, terreno, filtro, colisiones, FSM
  main.py           Dibujo y simulación del acelerómetro con pygame
  test_juego.py     Pruebas de la lógica
```

## Correr el prototipo

```bash
cd prototipo_python
pip3 install -r requirements.txt
python3 main.py        # mouse o flechas para inclinar, Espacio = BTNC, Esc para salir
python3 test_juego.py  # pruebas
```

En la PC el acelerómetro se simula: la posición horizontal del mouse equivale a
la inclinación (centro = tarjeta plana). Con las flechas la inclinación sube poco
a poco mientras se mantienen presionadas.

## Reglas

- El avión avanza solo y cada vez más rápido (de 2 a 6 px por frame).
- La inclinación mueve el avión de lado, proporcional a cuánto se incline.
  Cerca de plano hay una zona muerta donde no se mueve.
- Si cualquier píxel del avión toca una montaña: **CRASH**.
- Siempre existe un pasillo libre que serpentea y se va angostando.
- Cada fila de montañas superada = 1 punto.

## Decisiones pensadas para la FPGA

| En Python | En Verilog |
|---|---|
| Pantalla 640x480 a 60 FPS | `vga_sync` con reloj de píxel de 25 MHz (Clocking Wizard) |
| Tiles de 32 px | `columna = x[9:5]`: solo cortar bits, sin dividir |
| Buffer circular de 16 filas de 20 bits | 16 registros de 20 bits, índice `fila[3:0]` |
| `Juego.montana_en(x, y)` | Lo que calcula el módulo de render para cada píxel |
| Sprites 16x16 dibujados al doble | ROM de sprite con dirección `(x - x0) >> 1` |
| Posiciones en punto fijo Q4 | Registros con 4 bits fraccionarios |
| `accel += (x - accel) >> 2` | Filtro pasa-bajas de un solo registro |
| `velocidad_lateral(a)` = `(a + 2a) >> 1` | Comparador + restador + sumador, sin multiplicar |
| Colisión píxel a píxel | Flag que se activa si sprite opaco **y** montaña en el mismo píxel |
| `LFSR16` | Registro de desplazamiento con 3 XOR |
| `Juego.paso()` = un frame | Se ejecuta una vez por pulso de vsync |
| Estados `INICIO / JUGANDO / CHOQUE` | Máquina de estados finitos |
| Paleta RGB444 | Salida VGA de la Nexys A7 (4 bits por canal) |

## Módulos de hardware planeados

1. `clk_wiz`: 100 MHz → 25 MHz
2. `vga_sync`: hsync, vsync y contadores `(x, y)`
3. `spi_master` + `adxl362`: configura el sensor y lee el eje X (registro `XDATA`, 8 bits)
4. `filtro_entrada`: pasa-bajas, zona muerta, velocidad lateral
5. `logica_juego`: avión, scroll, terreno, LFSR, FSM (actualiza en cada vsync)
6. `render`: color de cada píxel (terreno, avión, HUD)
7. `display_7seg`: puntaje
8. `top.v` + `Nexys-A7.xdc`

## Siguientes pasos

1. Barras de color por VGA en la Nexys A7.
2. Leer el ADXL362 y mostrar el valor en los LEDs / 7 segmentos.
3. Terreno estático, luego con scroll.
4. Avión controlado por la inclinación.
5. Colisiones, puntaje y máquina de estados.
6. Testbenches que comparen el Verilog contra vectores generados con el prototipo.
