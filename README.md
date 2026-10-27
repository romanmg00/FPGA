# Tron en FPGA

Nuestro proyecto final de CS 256: **Tron** (motos de luz) para 2 jugadores,
en una Nexys A7-100T con salida **VGA 1280x800**. Equipo: **Roman y Alan**.

- **Tarjeta:** Digilent Nexys A7-100T (Artix-7, XC7A100T-1CSG324C)
- **Herramientas:** Vivado y SystemVerilog; Icarus Verilog para simular en la Mac.
  La síntesis se hace en la estación remota de Vivado; Vivado Lab en cada laptop
  solo programa la tarjeta (ver la sección Toolchain de [`docs/README.md`](docs/README.md#toolchain))
- **Entradas:** P1 usa los botones de dirección de la tarjeta; P2 usa W A S D en una
  página web que manda los comandos por USB-UART (115200 baudios, 8N1). Start con
  el botón central (BTNC) o con Espacio/Enter en la página. `SW0` pausa y
  `{SW15, SW14}` eligen la meta de puntos
- **Salidas:** VGA de 4 bits por canal (RGB444) y los 8 dígitos del display de
  7 segmentos con puntos y vidas

Las reglas que valen son las de la **especificación acordada del 20 de octubre**
([`docs/decisions/`](docs/decisions/)). El contrato de interfaces
(`proyecto_final/Contrato de interfaces game_top (CS 256).md`) ya está alineado con
ella en las reglas, las entradas, el reloj y el reparto; las interfaces que la
especificación deja abiertas están marcadas como **pendientes** en el contrato.
Las versiones anteriores de este README y del contrato están en
[`deprecated/`](deprecated/) y [`proyecto_final/deprecated/`](proyecto_final/deprecated/).

## Documentación y decisiones (Documentation and decisions)

- [`docs/README.md`](docs/README.md): índice de la documentación, orden de lectura y
  autoridad.
- [`docs/decisions/`](docs/decisions/): la especificación acordada y el registro de
  decisiones del 20 de octubre, **bloqueados** (no se editan; sus SHA-256 están en
  [`docs/decisions/README.md`](docs/decisions/README.md)). Donde este README o el
  contrato digan otra cosa, mandan estas reglas.
- [`docs/adr/`](docs/adr/): decisiones de arquitectura. La
  [0002](docs/adr/0002-follow-ta-divided-game-clock.md) fija el reloj de juego de
  ~60 Hz (segundo Clocking Wizard más un divisor), como pidieron los TAs. Las nuevas
  decisiones del equipo van como ADR 0003 en adelante.
- [`docs/design/`](docs/design/): plan de VGA y sprites, y las prácticas de código
  del curso.
- [`docs/domain/`](docs/domain/): glosario (Cell, Step, Trail, Reward…) y mecánicas.
- [Comparar los dos prototipos de Alan](prototipos/README.md): PR #2 en
  `prototipos/tron/fpga/` y el modelo nuevo en `prototipos/tron_fpga/`.
- `prototipos/tron_fpga/`: el Tron de Alan modelado sobre el hardware del Nexys A7
  (reglas en `model/` por bloques de hardware, visor `juego/` con pygame-ce, pruebas
  y métricas). Usa su propio entorno virtual; ver
  [`prototipos/tron_fpga/README.md`](prototipos/tron_fpga/README.md).
- `AGENTS.md` y `CLAUDE.md`: instrucciones para agentes; `CLAUDE.md` importa
  `AGENTS.md`.

## El juego (especificación del 20 de octubre)

- Dos motos de luz avanzan solas, una celda de 16 px cada 6 ticks del reloj de juego
  (unas 10 celdas por segundo), y dejan una **estela permanente**. Los giros son de
  90°; se guarda un solo giro pendiente y la vuelta en U se ignora.
- Cada partida empieza con **3 vidas y 0 puntos** por jugador. Chocar con una pared,
  con cualquier estela o con la otra moto cuesta una vida y termina la ronda. Si
  chocan de frente o se cruzan, los dos pierden una vida.
- Hay **tres premios** de una celda a la vez: **+1, +1 y +3** puntos. Si solo uno
  choca, el otro gana **+3** de bono por sobrevivir.
- Gana quien llegue primero a la **meta** (o la pase): 10, 20, 30 o 40 puntos según
  `{SW15, SW14}` (10 por defecto); la meta se toma al empezar la partida. Si no,
  pierde quien se queda sin vidas. Si pasa a los dos en el mismo paso, gana el de
  más puntos; con los mismos puntos es empate. Ya no hay tope de 99.
- **Start** empieza la partida y cada ronda. Después de un choque, las motos chocadas
  parpadean unos 2 s y se espera otro Start. `SW0` arriba pausa; `CPU_RESETN`
  regresa a esperar Start.
- **Display de 7 segmentos:** los 4 dígitos de la izquierda son de P2 y los 4 de la
  derecha de P1. Cada 3 s cambian juntos entre puntos y vidas: `P2 07  P1 12`, luego
  `L2 03  L1 02`.
- **Pantalla:** franja de 64 px arriba para el marcador, pared de 16 px y una arena
  jugable de **78 x 44 celdas**. Motos de 32 x 32 y premios de 16 x 16, desde ROM
  (`.coe` RGB444). P1 cian sale de `(20,27)` hacia la derecha; P2 naranja sale de
  `(59,27)` hacia la izquierda. El acomodo se puede ajustar después de probarlo.
- **Núcleo:** movimiento, estelas, choques, rondas y vidas, premios, bono y meta,
  sprites desde memoria, botones y UART, y el display. El marcador en pantalla
  viene justo después (prioridad *Should*). Menús, estelas de largo fijo, movimiento suave, temas y fondos con
  switches, brillo y scanlines son **extras**.

## Prototipos en Python

Los dos prototipos son **anteriores a la especificación** y todavía siguen las
reglas viejas. El equipo decidió tener **un solo modelo de reglas sin gráficos** en
este repositorio, que usen los dos visores y los testbenches; dónde vive y de cuál
prototipo se parte está pendiente. Hasta entonces, ninguno de los dos es el modelo
de referencia de las reglas nuevas.

**`prototipos/tron/` (Roman).** Motor, menús, teclado PS/2, display y un bot, con la
imagen VGA de 1280x800 tal como la dibujaría la FPGA: colores RGB444, letras de una
ROM de 8x8 ampliadas por bloques y sprites de 16x16 al doble.

```bash
cd prototipos
pip3 install -r requirements.txt
python3 tron/main.py       # el juego
python3 correr_pruebas.py  # las pruebas
```

Controles en la PC: P1 = WASD, P2 = flechas. En los menús, las flechas y Enter
hacen de botones de la tarjeta; las teclas 1 a 6 hacen de switches `sw0` a `sw5`.
C = P2 lo maneja la computadora (para probar solo). El display de 7 segmentos y los
switches se ven en el título de la ventana.

**`prototipos/tron_fpga/` (Alan).** Las reglas en `model/` siguen los bloques de
hardware (BRAM de la arena, control del paso, LFSR) y el visor `juego/` (pygame-ce)
compara arte, tamaños y marcadores. Necesita **su propio entorno virtual**, porque
`pygame-ce` y `pygame` usan el mismo módulo:

```bash
cd prototipos/tron_fpga
python3 -m venv ~/.venvs/cs256-tron && source ~/.venvs/cs256-tron/bin/activate
pip install -r requirements.txt
python -m juego                          # el visor
python -m unittest discover -s tests     # las pruebas
```

```
prototipos/
  lanzador.py            Menú de prototipos
  correr_pruebas.py      Corre las pruebas de los prototipos del lanzador
  requirements.txt       pygame (para tron/ y los demás del lanzador)
  tron/
    config.py            Constantes (y las tablas de colores)
    fuente.py            ROM de letras de 8x8 (font_rom)
    juego.py             Motor, menús, teclado PS/2, display y un bot
    main.py              Dibujo con pygame, como lo hará drawcon
    test_juego.py        Pruebas
  tron_fpga/
    model/               Reglas sin gráficos, por bloques de hardware
    juego/               Visor con pygame-ce
    tests/, metrics/     Pruebas y mediciones del visor
```

Las carpetas `mountain_crash/`, `zombie_crossing/` y `slither/` son ideas
anteriores; ya no están en el lanzador.

## Decisiones pensadas para la FPGA

| Idea | En hardware, según la especificación |
|---|---|
| Arena en celdas de 16 px, dirección `{cy, cx}` | `arena_map`: BRAM de 8192 x 4 bits con dirección `{cy[5:0], cx[6:0]}` (cuadrícula de 128 x 64 con relleno); `cx = x[10:4]`, sin multiplicar |
| Códigos de celda | 0 vacía, 1 pared, 2/3 estela/cabeza P1, 4/5 estela/cabeza P2, 6 choque, 7 reservado, 8/9/10 premios 0/1/2; iguales en el modelo y en el HDL |
| Un paso del juego | Reloj de juego de ~60 Hz del segundo Clocking Wizard más un divisor (ADR 0002); un paso cada 6 ticks. **No** está alineado con el borrado vertical |
| Video y memoria | Reloj de píxel de 83.46 MHz para `vga_out`, `drawcon` y las ROM; el controlador rápido de la arena es el único que escribe. El cruce entre el reloj lento y el rápido está **pendiente** de diseñar y probar |
| Leer las dos celdas destino antes de escribir | El resultado no depende del orden: un choque de frente es empate |
| Estelas | Permanentes; el largo fijo con búfer circular es un extra |
| `rotar_sprite()` | La ROM guarda la moto mirando hacia arriba; las otras direcciones salen de intercambiar e invertir bits de la dirección |
| Entradas | P1 con los botones (con antirrebote); P2 por UART desde la página web, en el orden en que llegan. El teclado PS/2 ya no es la entrada |
| `digitos_display()` | `seg7_driver`: binario a BCD y multiplexado; letras P y L; vista de puntos y de vidas cada 3 s |
| Generador aleatorio | Pseudoaleatorio, con semilla que depende de cuándo se presiona Start y un modo de semilla fija para pruebas. El generador exacto está **pendiente** |
| Paleta RGB444 | Salida VGA de la Nexys A7 (4 bits por canal); `000` es transparente y `0F0` toma el color del jugador |
| Temas y fondos con switches | Extras, después del núcleo |
| `fuente.py` y textos ampliados x2, x4, x8 | `font_rom` de 8x8; ampliar es quitar bits a `curr_x`/`curr_y`. Para el marcador, que viene después del núcleo |

## Fechas

| Fecha | Entrega |
|---|---|
| Jue 19 nov 2026 | Pre-demo con el TA (individual) |
| Lun 30 nov 2026 | Demo del juego en clase (en grupo) |
| Jue 10 dic 2026 | Reporte del diseño (individual) |

Las metas del equipo son tentativas: una versión para la pre-demo hacia el 15 de
noviembre y el código congelado hacia el 23 de noviembre.

## Pendiente

1. Pasar los prototipos a un solo modelo de reglas y adaptar los dos visores.
2. Elegir y verificar el generador aleatorio, la semilla y cuándo se colocan los premios.
3. Diseñar y medir el cruce entre el reloj de juego y la memoria rápida, el dibujo
   coherente, el reset y la pausa.
4. Terminar el Enter por UART, las letras P y L del display, el arte y los `.coe`, y
   el Clocking Wizard, la IP y las restricciones.
5. Probar el modelo contra el HDL, los sprites y su latencia, el reset y la pausa,
   y en la tarjeta; anotar las versiones de Vivado y los reportes de timing.

## Otras ideas (sin prototipo todavía)

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
