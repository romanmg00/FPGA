# Tron en FPGA

Nuestro proyecto final de CS 256: **Tron** (motos de luz) para 2 jugadores,
en una Nexys A7-100T con salida **VGA 1280x800**.

- **Tarjeta:** Digilent Nexys A7-100T (Artix-7, XC7A100T-1CSG324C)
- **Herramientas:** Vivado y SystemVerilog; Icarus Verilog para simular en la Mac
- **Entradas:** teclado USB en el puerto USB HOST (llega como PS/2), los 5 botones
  para los menús y los switches para la velocidad, los colores y el fondo
- **Salidas:** VGA de 4 bits por canal y el display de 7 segmentos con vidas y puntos

El diseño en hardware está en `proyecto_final/`. Su contrato de interfaces
(módulos, señales, reparto del equipo y fechas) es
`proyecto_final/Contrato de interfaces game_top (CS 256).md`.

## Documentación y decisiones (Documentation and decisions)

- [`docs/README.md`](docs/README.md): índice de la documentación, orden de lectura y
  autoridad.
- [`docs/decisions/`](docs/decisions/): la especificación acordada y el registro de
  decisiones del 20 de octubre, **bloqueados** (no se editan; sus SHA-256 están en
  [`docs/decisions/README.md`](docs/decisions/README.md)). Donde este README o el
  contrato digan otra cosa, mandan estas reglas hasta que se reconcilie el contrato.
- [`docs/adr/`](docs/adr/): decisiones de arquitectura. Las nuevas decisiones del
  equipo van como ADR 0003 en adelante.
- `prototipos/tron_fpga/`: el Tron de Alan modelado sobre el hardware del Nexys A7
  (reglas en `model/` por bloques de hardware, visor `juego/` con pygame-ce, pruebas
  y métricas). Usa su propio entorno virtual; ver
  [`prototipos/tron_fpga/README.md`](prototipos/tron_fpga/README.md).
- `AGENTS.md` y `CLAUDE.md`: instrucciones para agentes; `CLAUDE.md` importa
  `AGENTS.md`.

## El juego

- Dos motos de luz avanzan solas y dejan una estela. P1 maneja con W A S D y P2 con
  las flechas.
- Chocar con una pared o con cualquier estela, incluida la propia, cuesta una vida y
  empieza otra ronda. Si chocan de frente, los dos pierden una vida.
- Siempre hay un **rayo** (2x2 celdas) en algún lugar: tomarlo da puntos.
- Gana quien llegue primero a la meta de puntos. Quien se queda sin vidas, pierde
  (si los dos al mismo tiempo, gana el de más puntos).
- **Menú principal** con los botones de la tarjeta: Jugar, Configuración y Cómo jugar.
- **Configuración:** vidas, meta de puntos, puntos por rayo, espera del rayo y largo
  de la estela (infinita, 64, 32 o 16 celdas).
- **Switches** (en cualquier momento, incluso jugando): `sw[1:0]` velocidad, `sw[3:2]`
  colores de las motos y estelas (clásico, neón, hielo y fuego, retro), `sw[5:4]`
  fondo del mapa (rejilla, puntos, tablero, liso).
- **Display de 7 segmentos:** 4 dígitos por jugador: vidas, un dígito apagado y
  2 de puntaje (`3 07  3 12`).

## Prototipo en Python

Antes de escribir el hardware, el juego está hecho en Python. El prototipo sirve
para probar las reglas y como **modelo de referencia** para los testbenches: cada
módulo del contrato tiene su equivalente en `prototipos/tron/juego.py`.

```bash
cd prototipos
pip3 install -r requirements.txt
python3 tron/main.py       # el juego
python3 correr_pruebas.py  # las pruebas
```

Controles en la PC: P1 = WASD, P2 = flechas. En los menús, las flechas y Enter
hacen de botones de la tarjeta; las teclas 1 a 6 hacen de switches `sw0` a `sw5`.
C = P2 lo maneja la computadora (para probar solo).

La ventana es la imagen VGA de 1280x800 tal como la dibujará la FPGA: colores
RGB444, letras de una ROM de 8x8 ampliadas por bloques y sprites de 16x16 al doble.
El display de 7 segmentos y los switches, que son de la tarjeta, se ven en el
título de la ventana.

```
prototipos/
  lanzador.py            Menú de prototipos
  correr_pruebas.py      Corre las pruebas de los prototipos del lanzador
  tron/
    config.py            Constantes: las mismas de game_pkg.sv (y las tablas de colores)
    fuente.py            ROM de letras de 8x8 (font_rom)
    juego.py             Modelo de referencia: motor, menús, teclado PS/2, display y un bot
    main.py              Dibujo con pygame, como lo hará drawcon
    test_juego.py        Pruebas: también son los casos para los testbenches
```

Las carpetas `mountain_crash/`, `zombie_crossing/` y `slither/` son ideas
anteriores; ya no están en el lanzador.

## Decisiones pensadas para la FPGA

| En Python | En hardware |
|---|---|
| Arena de 80x50 celdas de 16 px, dirección `{cy, cx}` | `arena_map`: BRAM de 8192 x 4 bits; `cx = x[10:4]`, sin multiplicar |
| `Juego.paso()` = un cuadro | Se ejecuta una vez por `tick_60hz`, durante el borrado vertical |
| Leer las dos celdas destino antes de escribir | El resultado no depende del orden: un choque de frente es empate |
| Estela de largo fijo con búfer circular | 64 registros por moto con punteros de cabeza y cola |
| `rotar_sprite()` | La ROM guarda la moto mirando hacia arriba; las otras direcciones salen de intercambiar e invertir bits de la dirección |
| `pos_sprite()` | El sprite se desliza entre celdas con una tabla chica por velocidad |
| `TecladoPS2` | `ps2_rx` + `teclado`: prefijos `E0` (flechas) y `F0` (soltar) |
| `Config` | `menu_ctrl`: un índice por opción y una tabla con los valores |
| `digitos_display()` | `seg7_driver`: binario a BCD y multiplexado |
| `LFSR16` | Registro de desplazamiento con 3 XOR; avanza una vez por cuadro |
| Paleta RGB444 | Salida VGA de la Nexys A7 (4 bits por canal) |
| `TEMAS_MOTO`, `FONDOS` | Tablas de color en `drawcon` indexadas por los switches; los fondos salen de bits de x/y |
| `fuente.py` y textos ampliados x2, x4, x8 | `font_rom` de 8x8; ampliar es quitar bits a `curr_x`/`curr_y` |

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
