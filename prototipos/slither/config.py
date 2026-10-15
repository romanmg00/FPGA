"""
Constantes de Slither.io.

Son las mismas que game_pkg.sv del contrato de interfaces
(proyecto_final/Contrato de interfaces game_top (CS 256).md). Si cambian allá,
cambian aquí.
- VGA 1280x800 (diapositiva 7 del curso).
- La arena es una cuadrícula de celdas de 16x16 píxeles: 80 x 50 celdas.
- La dirección de una celda en arena_map es {cy, cx}: cy en 6 bits, cx en 7 bits
  (13 bits, 8192 entradas). No hace falta multiplicar.
- Colores en RGB444 (la Nexys A7 tiene 4 bits por canal).
"""

# --- Pantalla (VGA 1280x800 @ 60 Hz) ---
ANCHO = 1280
ALTO = 800
FPS = 60

# --- Cuadrícula ---
TILE = 16
TILE_SHIFT = 4
GRID_W = ANCHO >> TILE_SHIFT    # 80
GRID_H = ALTO >> TILE_SHIFT     # 50
CX_W = 7                        # 0-79
CY_W = 6                        # 0-49
ADDR_W = CY_W + CX_W            # 13
MAP_SIZE = 1 << ADDR_W          # 8192 (las direcciones con cx >= 80 no se usan)

# --- Contenido de una celda (4 bits) ---
CELL_EMPTY = 0
CELL_WALL = 1
CELL_FOOD = 2
CELL_P_HEAD = 4
CELL_P_BODY = 5
CELL_B0_HEAD = 6
CELL_B0_BODY = 7
CELL_B1_HEAD = 8
CELL_B1_BODY = 9

# --- Direcciones: girar a la derecha = sumar 1 (mod 4) ---
DIR_UP = 0
DIR_RIGHT = 1
DIR_DOWN = 2
DIR_LEFT = 3

# --- Estados del juego ---
ST_START = 0
ST_PLAY = 1
ST_DEAD = 2

# --- Parámetros del juego ---
N_BOTS = 2
MAX_LEN = 64
START_LEN = 4
N_FOOD = 8
SCORE_MAX = 999
# Cuadros por paso según la velocidad (sw[2:1]); el valor por defecto es el índice 1.
MOVE_FRAMES_POR_VEL = (8, 6, 4, 3)
VEL_INICIAL = 1
BOT_MOVE_FRAMES = 7             # los bots van un poco más lentos que el jugador
FRAMES_REAPARECER = 120         # 2 s antes de que un bot muerto vuelva a salir
BOT_MUERTO_A_COMIDA = True      # extensión: el cuerpo de un bot muerto se vuelve comida

# Dónde sale cada serpiente: (cx, cy, dirección). El cuerpo queda detrás de la cabeza.
SALIDA_JUGADOR = (40, 25, DIR_RIGHT)
SALIDA_BOTS = ((70, 8, DIR_LEFT), (10, 42, DIR_RIGHT))

# --- Acelerómetro (ADXL362, 12 bits, ±2 g: 1 mg por LSB) ---
TILT_MAX = 1000                 # ~1 g
TILT_ZONA_MUERTA = 250          # menos de ~15° de inclinación no cambia la dirección

# --- Paleta en RGB444 ---
PALETA = {
    "fondo1":   0x112,
    "fondo2":   0x123,
    "pared":    0x445,
    "pared_osc": 0x223,
    "comida":   0xF5A,
    "comida_br": 0xFCE,
    "ojo":      0xFFF,
    "pupila":   0x000,
    "texto":    0xFFF,
    "sombra":   0x000,
    "led_on":   0x2F4,
    "led_off":  0x232,
    # Color principal y sombra de cada serpiente
    "jugador":  0x4E6,
    "jugador_osc": 0x293,
    "bot0":     0xFA2,
    "bot0_osc": 0xC60,
    "bot1":     0xA6F,
    "bot1_osc": 0x63B,
}
