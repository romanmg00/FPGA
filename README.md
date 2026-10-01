# Prototipos de videojuego para FPGA

Nuestro primer proyecto de FPGA: un videojuego que se mostrará por **VGA 640x480**.
Antes de elegir cuál construir en hardware, tenemos varias ideas jugables en
Python. Cada prototipo está escrito para que traducirlo a Verilog sea directo.

- **Tarjeta:** Digilent Nexys A7-100T (Artix-7, XC7A100T-1CSG324C)
- **Herramienta:** Vivado, Verilog
- **Salida:** VGA 4 bits por canal + display de 7 segmentos para el puntaje

## Los juegos

| Juego | Idea | Entrada en la tarjeta |
|---|---|---|
| **Mountain Crash** | Un avión vuela entre montañas; se esquivan inclinando la tarjeta | Acelerómetro ADXL362 (SPI) + BTNC |
| **Zombie Crossing** | Tipo Crossy Road con tema de Plantas vs Zombies: un zombie cruza el jardín | Botones BTNU, BTND, BTNL, BTNR |

### Otras ideas (sin prototipo todavía)

**Mano virtual con IMUs.** Varios sensores de movimiento (IMU: giroscopio +
acelerómetro) en el dorso de la mano y en los dedos; la FPGA los lee todos al
mismo tiempo y se reconstruye la pose de la mano en 3D.

- **Qué se puede lograr:** la pose (cómo están doblados los dedos y hacia dónde
  apunta la mano). La posición de la mano en el cuarto no se puede saber solo con
  IMUs: integrar la aceleración acumula error en segundos.
- **Reparto de trabajo:** la FPGA lee los sensores en paralelo por SPI (un CS por
  sensor) y manda los datos por UART; la fusión de sensores (filtro complementario
  o Madgwick) y el dibujo 3D se hacen en la PC con Python.
- **Hardware extra:** hay que comprar IMUs; el ADXL362 de la Nexys A7 es solo
  acelerómetro. Se conectarían por los puertos Pmod (32 pines libres).
- **Etapas:** 1) un IMU mostrando su orientación en pantalla, 2) un dedo
  (2-3 sensores encadenados), 3) la mano completa.

## Correr los prototipos

```bash
cd prototipos
pip3 install -r requirements.txt
python3 lanzador.py        # menú para elegir juego
python3 correr_pruebas.py  # pruebas de todos los juegos
```

También se puede correr cada juego directo: `python3 mountain_crash/main.py` o
`python3 zombie_crossing/main.py`.

## Estructura

```
prototipos/
  lanzador.py            Menú para elegir juego (cada juego corre en su propio proceso)
  correr_pruebas.py      Corre las pruebas de todos
  mountain_crash/
    config.py            Constantes: resolución, tiles, paleta RGB444, reglas
    juego.py             Lógica pura (sin pygame): LFSR, terreno, filtro, colisiones, FSM
    main.py              Dibujo y simulación del acelerómetro con pygame
    test_juego.py        Pruebas
  zombie_crossing/
    config.py            Constantes
    juego.py             Lógica pura: carriles, guisantes, nenúfares, podadora, FSM
    sprites.py           Pixel art 16x16 en RGB444 (serán ROMs en la FPGA)
    main.py              Dibujo con pygame; usa assets/ si hay imágenes
    test_juego.py        Pruebas
    assets/              Imágenes opcionales locales (no se suben; ver LEEME.md)
```

## Mountain Crash

Controles en la PC: el mouse a izquierda o derecha (o las flechas) simula la
inclinación de la tarjeta. Espacio = BTNC. Esc para salir.

- El avión avanza solo y cada vez más rápido (de 2 a 6 px por frame).
- La inclinación mueve el avión de lado, proporcional a cuánto se incline.
  Cerca de plano hay una zona muerta donde no se mueve.
- Si cualquier píxel del avión toca una montaña: **CRASH**.
- Siempre existe un pasillo libre que serpentea y se va angostando.
- Cada fila de montañas superada = 1 punto.

## Zombie Crossing

Controles: flechas o WASD. Esc para salir.

| Carril | Qué hay | Cómo se pierde |
|---|---|---|
| Césped | Nueces que bloquean el paso | — |
| Tierra (carril de tiro) | Un lanzaguisantes en la orilla dispara guisantes; los carriles rápidos son de hielaguisantes | Si un guisante te toca |
| Piscina | Nenúfares que flotan y te arrastran | Si caes al agua o la corriente te saca de la pantalla |

- Cada fila que avanzas = 1 punto.
- Si pasas 8 s sin avanzar, llega la podadora (se ve venir 1.5 s antes).
- Los dibujos son pixel art propio inspirado en Plantas vs Zombies. Para una
  presentación se pueden poner imágenes en `zombie_crossing/assets/`; esa carpeta
  no se sube a GitHub.

## Decisiones pensadas para la FPGA

| En Python | En Verilog |
|---|---|
| Pantalla 640x480 a 60 FPS | `vga_sync` con reloj de píxel de 25 MHz (Clocking Wizard) |
| Tiles de 32 px | `columna = x[9:5]`: solo cortar bits, sin dividir |
| Buffer circular de 16 filas | 16 registros, índice `fila[3:0]` |
| Carril de Zombie Crossing = patrón de 32 bits + offset de 10 bits | Un registro de 32 bits y un contador que se desborda solo |
| `Juego.montana_en(x, y)` / `Carril.ocupado(x)` | Lo que calcula el módulo de render para cada píxel |
| Sprites 16x16 dibujados al doble | ROM de sprite con dirección `(x - x0) >> 1` |
| Posiciones en punto fijo Q4 (Mountain Crash) | Registros con 4 bits fraccionarios |
| `accel += (x - accel) >> 2` | Filtro pasa-bajas de un solo registro |
| `velocidad_lateral(a)` = `(a + 2a) >> 1` | Comparador + restador + sumador, sin multiplicar |
| Colisión píxel a píxel | Flag que se activa si sprite opaco **y** obstáculo en el mismo píxel |
| `LFSR16` | Registro de desplazamiento con 3 XOR |
| `Juego.paso()` = un frame | Se ejecuta una vez por pulso de vsync |
| Estados `INICIO / JUGANDO / CHOQUE o MUERTO` | Máquina de estados finitos |
| Paleta RGB444 | Salida VGA de la Nexys A7 (4 bits por canal) |

## Módulos de hardware planeados

Comunes a los dos juegos:

1. `clk_wiz`: 100 MHz → 25 MHz
2. `vga_sync`: hsync, vsync y contadores `(x, y)`
3. `logica_juego`: estado del juego, LFSR, FSM (actualiza en cada vsync)
4. `render`: color de cada píxel (fondo, obstáculos, personaje, HUD)
5. `display_7seg`: puntaje
6. `top.v` + `Nexys-A7-100T.xdc`

Según el juego elegido:

- **Mountain Crash:** `spi_master` + `adxl362` (lee el eje X, registro `XDATA`) y `filtro_entrada`.
- **Zombie Crossing:** `antirrebote` para los 4 botones de dirección.

## Siguientes pasos

1. Elegir el juego.
2. Barras de color por VGA en la Nexys A7.
3. Entrada: leer el ADXL362 o los botones y mostrar el valor en los LEDs.
4. Fondo y obstáculos estáticos, luego en movimiento.
5. Personaje controlado, colisiones, puntaje y máquina de estados.
6. Testbenches que comparen el Verilog contra vectores generados con el prototipo.
