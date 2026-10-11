# Contrato de interfaces: game\_top (CS 256)

Oct 11, 2026 · @Román · Fuente: `cs256-project1-fall26.pdf` (las diapositivas citadas son de esa presentación)

## 1. Convenciones generales

Todo el diseño vive en un solo reloj (`clk_pix`) y cada señal tiene un único productor; así nadie depende de supuestos ajenos.

- **Reloj:** `clk` (100 MHz de la placa) solo entra al Clocking Wizard. De ahí sale `clk_pix`, y todos los módulos usan `clk_pix`. Esto evita cruces de dominio de reloj.
- **Frecuencia de `clk_pix`:** con los tiempos de la diapositiva 7 (1680 × 828 píxeles por cuadro a 60 Hz) salen unos **83.5 MHz**. El diagrama de las diapositivas 11 y 12 dice "106 MHz", que corresponde al estándar 1280 × 800 a 75 Hz y no a estos totales. Se usa **83.5 MHz** salvo que `/classproject/` diga otra cosa; hay que confirmarlo antes de configurar el wizard.
- **Reset:** `rst` es síncrono y activo en alto. Si se usa el botón CPU\_RESET de la placa (activo en bajo), se invierte una sola vez en `game_top`.
- **Coordenadas:** sin signo, origen (0,0) arriba a la izquierda, x crece a la derecha, y crece hacia abajo. Área visible de 1280 × 800.
- **Tipos y nombres:** `logic`, `snake_case`, un módulo por archivo con el mismo nombre. Los anchos están en las tablas de este documento y se usan tal cual en el código.
- **Entradas asíncronas:** botones e interruptores pasan por sincronizador de 2 flip-flops antes de usarse. El antirrebote vive en `position_logic`.

## 2. Puertos externos de `game_top`

`game_top` expone 14 pines VGA como mínimo (diapositiva 3), más las entradas de control; todo lo demás es opcional y suma a la rúbrica de E/S extra. Placa confirmada: **Nexys A7-100T** (XC7A100T-1CSG324C). Los nombres de pin físicos están en `nexys-a7-100t-master.xdc`, en la raíz del repo.

| Puerto | Dir | Ancho | Descripción | Obligatorio |
| --- | --- | --- | --- | --- |
| `clk` | in | 1 | Reloj de la placa, 100 MHz | Sí |
| `rst` | in | 1 | Reset, activo en alto | Sí |
| `btn` | in | 5 | Botones: `[0]` arriba, `[1]` abajo, `[2]` izquierda, `[3]` derecha, `[4]` centro | Sí |
| `sw` | in | 16 | Interruptores (modo de juego, dificultad, etc.) | No |
| `vga_r` | out | 4 | Rojo | Sí |
| `vga_g` | out | 4 | Verde | Sí |
| `vga_b` | out | 4 | Azul | Sí |
| `vga_hs` | out | 1 | Sincronía horizontal | Sí |
| `vga_vs` | out | 1 | Sincronía vertical | Sí |
| `led` | out | 16 | LEDs (vidas, eventos) | No |
| `seg` | out | 7 | Segmentos del display de 7 segmentos | No |
| `an` | out | 8 | Selección de dígito del display | No |
| `acl_sclk`, `acl_mosi`, `acl_csn` | out | 1 c/u | SPI al acelerómetro ADXL362 de la placa (pines `ACL_*` del XDC) | No (solo si el juego usa inclinación) |
| `acl_miso` | in | 1 | Dato del acelerómetro | No (ídem) |

La polaridad real de `vga_hs` y `vga_vs` (pulso en alto o en bajo) queda como pregunta abierta: la diapositiva 7 dibuja el pulso en alto, pero conviene confirmarlo en `/classproject/`.

## 3. Señales internas entre bloques

Los anchos salen de los contadores de la diapositiva 7: `hcnt` llega a 1679, que necesita 11 bits (2^10 = 1024 no alcanza), y `vcnt` llega a 827, que cabe en 10 bits.

| Señal | De → A | Ancho | Rango | Nota |
| --- | --- | --- | --- | --- |
| `clk_pix` | Clocking Wizard → todos | 1 | — | Único reloj del diseño |
| `tick_60hz` | `vga_out` → `position_logic` | 1 | pulso de 1 ciclo | Una vez por cuadro; habilita la actualización de posiciones |
| `curr_x` | `vga_out` → `drawcon` | 11 | 0–1279 | Columna del píxel que se está dibujando |
| `curr_y` | `vga_out` → `drawcon` | 10 | 0–799 | Fila del píxel que se está dibujando |
| `blkpos_x` | `position_logic` → `drawcon` | 11 | 0–1279 | Esquina superior izquierda del objeto del jugador |
| `blkpos_y` | `position_logic` → `drawcon` | 10 | 0–799 | Ídem |
| `draw_r` | `drawcon` → `vga_out` | 4 | 0–15 | Color del píxel actual |
| `draw_g` | `drawcon` → `vga_out` | 4 | 0–15 | Ídem |
| `draw_b` | `drawcon` → `vga_out` | 4 | 0–15 | Ídem |
| `pix_r`, `pix_g`, `pix_b` | `vga_out` → pines | 4 c/u | 0–15 | Van a `vga_r`, `vga_g`, `vga_b` |
| `hsync`, `vsync` | `vga_out` → pines | 1 c/u | — | Van a `vga_hs`, `vga_vs` |

**Señales reservadas** (aún no obligatorias, pero con nombre y ancho fijos para no rehacer interfaces después):

| Señal | De → A | Ancho | Uso |
| --- | --- | --- | --- |
| `score` | `position_logic` → display | 8 | Puntaje en binario, 0–255 |
| `lives` | `position_logic` → LEDs | 3 | Vidas restantes |
| `game_over` | `position_logic` → `drawcon` | 1 | Cambia la pantalla al terminar |
| `tilt_x` | `accel_spi` → `position_logic` | 12 | Inclinación en X del ADXL362, con signo (complemento a 2); solo si el juego usa acelerómetro |

**Regla de latencia:** `vga_out` recibe `draw_*` y saca `pix_*` registrados. Si `drawcon` añade L ciclos de retraso (por ejemplo, al leer una ROM de sprites), `hsync` y `vsync` deben retrasarse los mismos L ciclos, o la imagen se corre en pantalla.

## 4. Interfaz módulo por módulo

Cada módulo tiene un responsable (A, B o C; ver sección 7) y los puertos de abajo son su contrato: si alguien necesita cambiarlos, avisa al equipo antes de tocar el código.

| Módulo | Resp. | Qué hace |
| --- | --- | --- |
| `vga_out` | A | Contadores `hcnt`/`vcnt`, pulsos de sync, blanking fuera del área visible, `curr_x`/`curr_y` y `tick_60hz` |
| `drawcon` | A | Decide el color de cada píxel: fondo, paredes, objetos y sprites |
| `position_logic` | B | Botones con antirrebote, movimiento, límites de pantalla, colisiones, estado del juego (FSM), puntaje y vidas |
| `seg7_driver` | C | Muestra `score` en el display de 7 segmentos |
| `accel_spi` | C | Lee el ADXL362 por SPI y entrega `tilt_x` (solo si el juego usa inclinación) |
| `game_top` | C | Instancia y conecta todo; reloj, reset, pines y XDC |
| Testbenches de integración | C | Prueban cada módulo de A y B contra este contrato, más una simulación de `game_top` completo |

**`vga_out`**

```systemverilog
module vga_out (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [10:0] curr_x,
    output logic [9:0]  curr_y,
    output logic        tick_60hz,   // 1 ciclo al inicio de cada cuadro
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync
);
```

Propuesta: `tick_60hz` sale de `vga_out` (en el diagrama de la diapositiva 11 es un bloque aparte, `clk_div_60hz`) (un pulso al inicio del cuadro) y no de un divisor aparte. Un cuadro dura 1680 × 828 = 1,391,040 ciclos de `clk_pix`, así que es equivalente a dividir hasta 60 Hz, y nunca se desfasa del video.

**`position_logic`**

```systemverilog
module position_logic (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic        tick_60hz,
    input  logic [4:0]  btn,
    input  logic [15:0] sw,
    output logic [10:0] blkpos_x,
    output logic [9:0]  blkpos_y,
    output logic [7:0]  score,
    output logic [2:0]  lives,
    output logic        game_over
);
```

El objeto solo se mueve cuando `tick_60hz` vale 1. Las colisiones se calculan aquí, comparando `blkpos_x`/`blkpos_y` contra los rectángulos de `game_pkg` (sección 5), así `drawcon` no tiene que devolver ninguna señal.

**`drawcon`**

```systemverilog
module drawcon (
    input  logic        clk_pix,     // sin uso al inicio; se reserva para la ROM de sprites
    input  logic        rst,
    input  logic [10:0] curr_x,
    input  logic [9:0]  curr_y,
    input  logic [10:0] blkpos_x,
    input  logic [9:0]  blkpos_y,
    input  logic        game_over,
    output logic [3:0]  draw_r, draw_g, draw_b
);
```

Al inicio `drawcon` puede ser puramente combinacional. Los puertos `clk_pix`, `rst` y `game_over` existen desde el primer día (con `game_over` atado a 0 en `game_top`), para que añadir sprites o pantalla de fin no cambie la interfaz.

**`seg7_driver`**

```systemverilog
module seg7_driver (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic [7:0]  score,
    output logic [6:0]  seg,
    output logic [7:0]  an
);
```

**`game_top`** conecta además el Clocking Wizard (entrada 100 MHz, salida `clk_pix`) y asigna `led[2:0] = lives`.

## 5. Constantes compartidas (`game_pkg.sv`)

A (`drawcon`) y B (`position_logic`) deben leer las mismas posiciones de paredes y objetos desde un solo archivo; si cada uno escribe sus números, las colisiones y el dibujo se desfasan. Los tiempos VGA salen de la diapositiva 7 y los tamaños de objetos son valores de ejemplo que el equipo debe decidir.

```systemverilog
package game_pkg;

    // Timing VGA 1280x800 (diapositiva 7). Verificar contra /classproject/
    localparam int H_SYNC   = 136;
    localparam int H_BP     = 200;
    localparam int H_ACTIVE = 1280;
    localparam int H_FP     = 64;
    localparam int H_TOTAL  = H_SYNC + H_BP + H_ACTIVE + H_FP;  // 1680

    localparam int V_SYNC   = 3;
    localparam int V_BP     = 24;
    localparam int V_ACTIVE = 800;
    localparam int V_FP     = 1;
    localparam int V_TOTAL  = V_SYNC + V_BP + V_ACTIVE + V_FP;  // 828

    // Rectángulo en coordenadas de pantalla; x1 e y1 son exclusivos
    typedef struct packed {
        logic [10:0] x0, x1;
        logic [9:0]  y0, y1;
    } rect_t;

    function automatic logic in_rect(input logic [10:0] x,
                                     input logic [9:0]  y,
                                     input rect_t       r);
        return (x >= r.x0) && (x < r.x1) && (y >= r.y0) && (y < r.y1);
    endfunction

    // Valores de ejemplo: el equipo decide tamaños y velocidad
    localparam int BLK_W     = 32;
    localparam int BLK_H     = 32;
    localparam int BLK_SPEED = 4;   // píxeles por cuadro

    localparam rect_t WALL_TOP = '{x0: 11'd0, x1: 11'd1280, y0: 10'd0,   y1: 10'd16};
    localparam rect_t WALL_BOT = '{x0: 11'd0, x1: 11'd1280, y0: 10'd784, y1: 10'd800};

endpackage
```

No compilé este paquete en Vivado; corre una síntesis rápida al agregarlo al proyecto por si Vivado marca algún detalle de sintaxis. Ojo también con Icarus Verilog (`iverilog -g2012`): su soporte de `struct packed` dentro de paquetes y de patrones con nombre (`'{x0: ...}`) es limitado. Si no compila en Icarus, cambia `rect_t` por `localparam` sueltos (`WALL_TOP_X0`, `WALL_TOP_X1`, …) antes de que A y B empiecen a usarlo.

**Quién edita `game_pkg.sv`:** A fija los tiempos VGA, B fija tamaños, velocidad y rectángulos del juego, y C revisa que cualquier cambio siga pasando los testbenches.

## 6. Reglas de integración y puntos de fricción

Estos son los errores que más suelen romper la integración entre módulos escritos por personas distintas.

- **Restar sin signo:** `blkpos_x` y `blkpos_y` son sin signo. Si `blkpos_x = 2` y se resta `BLK_SPEED = 4`, el resultado da la vuelta a 2046 y el objeto salta al otro lado. Compara antes de restar (`if (blkpos_x > BLK_SPEED)`).
- **Asignaciones:** `always_ff` usa `<=` (non-blocking) y `always_comb` usa `=`. En `always_comb` todas las ramas deben asignar todas las salidas; si no, Vivado infiere un latch.
- **Un solo reloj:** nadie genera un reloj con lógica ni lo usa como reloj de otro módulo. `tick_60hz` es un pulso de habilitación (`if (tick_60hz)`) dentro de `clk_pix`.
- **Latencia de `drawcon`:** cualquier retraso que añada (ROM de sprites, registros de salida) obliga a `vga_out` a retrasar `hsync` y `vsync` lo mismo (sección 3). Como A es dueño de los dos módulos, este ajuste queda en una sola persona.
- **Blanking:** fuera del área visible los tres canales de color valen 0. Lo fuerza `vga_out`, así que `drawcon` no necesita saber si el píxel es visible.
- **Botones:** pasan por sincronizador y antirrebote, y el movimiento se aplica una vez por `tick_60hz`, no una vez por ciclo de reloj.
- **Probar `vga_out` primero:** en simulación, `hsync` dura 136 ciclos, una línea completa dura 1680, un cuadro dura 828 líneas y el color es 0 fuera de los 1280 × 800 visibles. Sin esto, el resto del diseño no se puede depurar (diapositiva 25: primero VGA, luego posición, luego juego).
- **Cambios al contrato:** cualquier cambio de nombre, ancho o significado de una señal se anota en este documento y se avisa antes de modificar el código.

## 7. Reparto entre 3 personas

El equipo es de tres (confirmado). Hay **dos desarrolladores (A y B)** y **una persona de verificación e integración (C)**. C no es un tester puro: también es dueño de `game_top` y de los periféricos, porque 30 de los 40 puntos son individuales (pre-demo y reporte) y cada quien necesita hardware propio que mostrar y explicar.

| Persona | Módulos | Entregables | Rúbrica que cubre |
| --- | --- | --- | --- |
| **A: Video** | Clocking Wizard (configuración), `vga_out`, `tick_60hz`, `drawcon`, ROM de sprites | Imagen estable en el monitor; sprites cargados desde memoria | Imagen estable (diapositiva 25), sprites (2), creatividad (1) |
| **B: Lógica de juego** | `position_logic`: botones, antirrebote, límites, colisiones, FSM, puntaje y vidas; constantes de juego en `game_pkg.sv` | Objeto que se mueve con los botones o la inclinación; juego completo | Control con límites de pantalla (2.5), objetos e interacciones (2.5) |
| **C: Verificación, integración y periféricos** | `game_top`, XDC, `seg7_driver`, LEDs, `accel_spi` (si aplica), testbenches de integración | Un testbench por módulo de A y B; simulación de `game_top`; proyecto Vivado integrado; control de versiones | E/S extra (2); base de la integración |

**Cómo se reparten las pruebas**

- Cada dueño hace pruebas rápidas de su propio módulo mientras lo escribe.
- C escribe el testbench **oficial** de cada módulo de A y B, partiendo de **este contrato**, no del código. Si C y el dueño leen distinto una señal, el testbench lo detecta antes de que llegue a la placa. Ese es el valor de tener a alguien dedicado a probar.
- Un módulo se considera terminado cuando pasa el testbench de C. Si falla, se decide entre los dos si el error está en el módulo, en el testbench o en el contrato; si es el contrato, se corrige aquí primero.
- El prototipo en Python (`prototipos/`) sirve como modelo de referencia: C puede sacar de ahí posiciones y colisiones esperadas para comparar con la simulación de `position_logic`.

**Orden de trabajo** (diapositiva 25; las fechas están en la sección 8). C tiene trabajo desde el primer día porque los testbenches salen del contrato:

1. A escribe `vga_out` mientras C escribe su testbench (tiempos de la sección 6) y B el antirrebote y el movimiento en simulación.
2. C integra `vga_out` en `game_top` y lo baja a la placa: imagen estable.
3. B conecta `position_logic` y mueve un objeto; A dibuja el fondo y el objeto en `drawcon`.
4. A y B construyen el juego sobre ese esqueleto; C añade display, LEDs y acelerómetro, y mantiene la simulación de `game_top` al día.

**Riesgo del rol de C:** si C solo escribe testbenches, en la pre-demo individual tiene poco diseño propio que enseñar. Por eso `seg7_driver`, `accel_spi` y `game_top` son suyos. Si el juego no usa acelerómetro, conviene darle a C otro bloque de diseño (por ejemplo, la pantalla de inicio y de fin, o el sonido).

## 8. Timeline semanal

Las semanas van de lunes a domingo. El **hito** de cada semana vence el **domingo a las 23:59** y se revisa en una reunión corta del equipo ese mismo domingo. Las tres fechas fijas del curso (diapositiva 2) mandan sobre todo lo demás:

| Fecha | Entrega | Puntos | Tipo |
| --- | --- | --- | --- |
| Jue 19 nov 2026 | Pre-demo con el TA | 15 | Individual |
| Lun 30 nov 2026 | Demo del juego en clase | 10 | En grupo |
| Jue 10 dic 2026 | Reporte del diseño | 15 | Individual |

El plan deja el juego completo una semana antes de la pre-demo y el código congelado cuatro días antes de la demo. La diapositiva 27 menciona hitos del curso en `/classproject/`; cuando se publiquen, se ajustan estas fechas para que coincidan.

**Resumen**

| Sem. | Fechas | Hito del equipo (vence el domingo) |
| --- | --- | --- |
| 1 | 12–18 oct | Juego elegido; `vga_out` pasa el testbench de C en simulación |
| 2 | 19–25 oct | Imagen estable en el monitor y un rectángulo que se mueve con los botones |
| 3 | 26 oct – 1 nov | Juego jugable con rectángulos: mapa, colisiones y fin del juego |
| 4 | 2–8 nov | Sprites desde memoria; puntaje en el display y vidas en los LEDs |
| 5 | 9–15 nov | Juego completo; versión `predemo` etiquetada en git |
| 6 | 16–22 nov | **Pre-demo el jue 19**; correcciones a partir de los comentarios del TA |
| 7 | 23–29 nov | Código congelado el jue 26 (tag `demo`); guion de la demo ensayado |
| 8 | 30 nov – 6 dic | **Demo el lun 30**; borrador de cada reporte |
| 9 | 7–10 dic | **Reporte el jue 10** |

**Semana 1 (12–18 oct): VGA en simulación**
- Equipo: elegir el juego antes del **miércoles 14** y llenar los tamaños y rectángulos en `game_pkg.sv`.
- A: `vga_out` con `hcnt` 0–1679 y `vcnt` 0–827, pulsos de sync, blanking, `curr_x`/`curr_y` y `tick_60hz`. Partir de `counters.sv`, cambiándolo a 11 bits y 1679.
- B: antirrebote de los botones y movimiento de `blkpos_x`/`blkpos_y` con límites de pantalla, en simulación.
- C: compilar `game_pkg.sv` en Icarus y en Vivado; escribir el testbench de `vga_out` a partir de la sección 6; confirmar el reloj y la polaridad en `/classproject/`.

**Semana 2 (19–25 oct): primera imagen en el monitor**
- A: configurar el Clocking Wizard para `clk_pix`; `drawcon` dibuja el fondo y un rectángulo en `blkpos_x`/`blkpos_y`.
- B: `position_logic` pasa el testbench de C (bordes, resta sin signo, un paso por `tick_60hz`).
- C: `game_top` y XDC; generar el bitstream y probarlo en la placa. Escribir el testbench de `position_logic`.
- Si la imagen no sale estable para el miércoles 22, los tres se enfocan en eso: sin VGA no hay nada que mostrar.

**Semana 3 (26 oct – 1 nov): juego con rectángulos**
- B: mapa u obstáculos en `game_pkg.sv`, colisiones y FSM (inicio, juego, fin).
- A: dibujar paredes y obstáculos desde `game_pkg.sv`, y la pantalla de `game_over`.
- C: `seg7_driver` con `score` y los LEDs con `lives`; testbench de colisiones con valores esperados sacados del prototipo en Python; empezar `accel_spi` si el juego usa inclinación.
- Con este hito ya quedan cubiertos los dos criterios de 2.5 puntos de la rúbrica (diapositiva 26).

**Semana 4 (2–8 nov): sprites y periféricos**
- A: ROM de sprites con pixel art propio; retrasar `hsync`/`vsync` según la latencia de la ROM.
- B: puntaje, vidas, dificultad con `sw` y aleatoriedad con un LFSR si el juego la necesita.
- C: `accel_spi` funcionando en la placa (`tilt_x`); simulación completa de `game_top`.
- Si `accel_spi` no funciona el domingo 8, el juego se queda con botones y C pasa a la pantalla de inicio o al sonido.

**Semana 5 (9–15 nov): juego completo**
- Todos: integrar, corregir errores y añadir los detalles creativos.
- Cada quien prepara la explicación de sus módulos para la pre-demo: diagrama, puertos, decisiones de diseño y cómo lo probó.
- Domingo 15: versión estable con tag `predemo`. Desde ese día solo se arreglan errores.

**Semana 6 (16–22 nov): pre-demo**
- Lunes 16 a miércoles 18: ensayo cruzado, en el que cada quien explica sus módulos ante los otros dos y responde preguntas.
- **Jueves 19:** pre-demo individual con el TA.
- Viernes 20 a domingo 22: anotar y corregir lo que haya señalado el TA.

**Semana 7 (23–29 nov): preparar la demo**
- Pulir y, si se puede, probar en un monitor como el del salón.
- **Jueves 26:** código congelado con tag `demo`. Después de eso solo se aceptan arreglos de errores graves, y pasan por C.
- Escribir y ensayar el guion de la demo: qué se muestra, quién lo presenta y cuánto dura.

**Semana 8 (30 nov – 6 dic): demo y reportes**
- **Lunes 30:** demo en grupo.
- El reporte es individual, así que cada quien escribe el suyo sobre su parte del diseño. Antes de reutilizar figuras o diagramas, confirmen con el profesor qué se puede compartir.
- Domingo 6: borrador completo de cada reporte.

**Semana 9 (7–10 dic): entrega final**
- Revisión cruzada de los reportes (ortografía y claridad, no contenido) a más tardar el martes 8.
- **Jueves 10:** entrega del reporte.

**Si un hito se atrasa**, se recorta alcance en este orden y nunca se mueve una fecha del curso: primero el acelerómetro (se queda con botones), después las extensiones creativas, luego los sprites extra (al menos uno en ROM, que vale 2 puntos) y, como última opción, el display de 7 segmentos.

## 9. Preguntas abiertas

- [x] ¿Pueden ser tres en el equipo? Sí.
- [ ] ¿`clk_pix` es 83.5 MHz o 106 MHz? Con los contadores de la diapositiva 7, 1680 × 828 × 60 Hz da 83.5 MHz. El "106 MHz" del diagrama de las diapositivas 11 y 12 coincide con el estándar 1280 × 800 a 75 Hz, que usa otros totales, así que probablemente es un rótulo heredado. Confirmar en `/classproject/` (diapositiva 27).
- [ ] ¿Polaridad de `hsync` y `vsync`? El estándar VESA de 1280 × 800 a 60 Hz usa `hsync` en bajo y `vsync` en alto, pero los tiempos del curso no son idénticos a VESA (828 líneas en vez de 831). Confirmar en `/classproject/`.
- [x] ¿Qué placa exacta usamos? Nexys A7-100T.
- [ ] ¿Qué juego hacemos? Define tamaños en `game_pkg.sv` y quién dibuja qué. **Vence el miércoles 14 oct.**
- [x] ¿Resolución? **1280 × 800**: la diapositiva 7 lo dice explícitamente (`hcnt` 0–1679, `vcnt` 0–827). El `README.md` y `counters.sv` todavía usan 640 × 480 (cuenta 0–799) y hay que actualizarlos: el contador horizontal llega a 1679 y necesita 11 bits.
- [ ] ¿El juego usa acelerómetro (Mountain Crash) o botones? Decide si `accel_spi` entra en el plan de C. **Vence el miércoles 14 oct.**
- [ ] ¿Quién es A, quién es B y quién es C? **Vence el lunes 12 oct**, para que la semana 1 arranque con dueños claros.
