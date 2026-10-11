"""
Constantes de Tron (motos de luz, 2 jugadores en un teclado).

- VGA 1280x800 (diapositiva 7 del curso).
- La arena es una cuadrícula de celdas de 16x16 px: 80 x 50 celdas. La
  dirección de una celda en arena_map es {cy, cx}: cy en 6 bits, cx en 7 bits
  (13 bits, 8192 entradas de 4 bits = 32 Kb, una sola BRAM36).
  Para cambiar el grosor de la estela basta con cambiar TILE_SHIFT (y los
  anchos CX_W / CY_W que salen de ahí).
- Las 2 filas de arriba (32 px) son la franja del marcador.
- Entrada de juego: un teclado USB en el puerto USB HOST de la Nexys A7, que la
  tarjeta entrega como PS/2 (pines PS2_CLK y PS2_DATA, códigos Set 2).
- Menús: los 5 botones de la tarjeta. Switches: sw[1:0] velocidad, sw[3:2]
  colores de las motos, sw[5:4] fondo del mapa.
- Colores en RGB444 (la Nexys A7 tiene 4 bits por canal).
"""

# --- Pantalla (VGA 1280x800 @ 60 Hz) ---
ANCHO = 1280
ALTO = 800
FPS = 60

# --- Cuadrícula ---
TILE_SHIFT = 4
TILE = 1 << TILE_SHIFT          # 16 px
GRID_W = ANCHO >> TILE_SHIFT    # 80
GRID_H = ALTO >> TILE_SHIFT     # 50
CX_W = 7                        # 0-79
CY_W = 6                        # 0-49
ADDR_W = CY_W + CX_W            # 13
MAP_SIZE = 1 << ADDR_W          # 8192 (las direcciones fuera de 80x50 no se usan)
HUD_ROWS = 2                    # filas 0-1 = marcador; la arena va de cy = 2 a cy = 49

# --- Contenido de una celda (4 bits) ---
CELL_EMPTY = 0
CELL_WALL = 1
CELL_P1_TRAIL = 2
CELL_P1_HEAD = 3
CELL_P2_TRAIL = 4
CELL_P2_HEAD = 5
CELL_CRASH = 6                  # donde chocó una moto
CELL_RAYO = 7                   # el rayo que da puntos (ocupa RAYO_CELDAS x RAYO_CELDAS)

# --- Direcciones: girar a la derecha = sumar 1 (mod 4) ---
DIR_UP = 0
DIR_RIGHT = 1
DIR_DOWN = 2
DIR_LEFT = 3

# --- Estados del juego ---
ST_MENU = 0         # menú principal
ST_CONFIG = 1       # configuración de la partida
ST_AYUDA = 2        # cómo jugar
ST_READY = 3        # cuenta regresiva antes de cada ronda
ST_PLAY = 4
ST_ROUND = 5        # alguien chocó: se muestra quién perdió la vida
ST_MATCH = 6        # terminó la partida; BTNC vuelve al menú

EMPATE = 0          # resultado: 0 = empate, 1 = P1, 2 = P2

# --- Botones de la tarjeta (bits de btn) ---
BTN_U, BTN_D, BTN_L, BTN_R, BTN_C = 0, 1, 2, 3, 4

# --- Menú principal: BTNU/BTND eligen, BTNC entra ---
MENU_PRINCIPAL = ("Jugar", "Configuración", "Cómo jugar")
OP_JUGAR, OP_CONFIG, OP_AYUDA = 0, 1, 2

# --- Configuración: BTNU/BTND eligen, BTNL/BTNR cambian, BTNC vuelve ---
# (clave, texto, opciones, índice inicial). En hardware cada opción es un
# registro con el índice, y una tabla convierte el índice en el valor.
CONFIG = (
    ("vidas", "Vidas", tuple(range(1, 10)), 2),                     # 3
    ("meta", "Meta de puntos", tuple(range(5, 100, 5)), 3),         # 20
    ("valor_rayo", "Puntos por rayo", (1, 2, 3, 4, 5), 0),          # 1
    ("espera_rayo", "Espera del rayo (s)", (0, 1, 2, 3, 4, 5), 1),  # 1 s
    ("largo", "Largo de la estela", (0, 64, 32, 16), 0),            # 0 = infinita
)
MAX_LARGO = 64                  # tamaño del búfer circular de cada moto (potencia de 2)

# --- Switches: se pueden cambiar en cualquier momento ---
# sw[1:0]: velocidad
MOVE_FRAMES_POR_SW = (6, 4, 3, 2)              # cuadros por celda (16 px)
NOMBRE_VEL = ("lenta", "normal", "rápida", "turbo")

# sw[3:2]: colores de las motos y sus estelas. Por jugador: (color, sombra, brillo).
TEMAS_MOTO = (
    ("clásico", ((0x0DF, 0x08A, 0xEFF), (0xF80, 0xA40, 0xFEC))),   # cian y naranja
    ("neón",    ((0x2F4, 0x182, 0xEFE), (0xF2E, 0x918, 0xFDF))),   # verde y magenta
    ("hielo y fuego", ((0x48F, 0x24A, 0xDEF), (0xF33, 0x922, 0xFDD))),  # azul y rojo
    ("retro",   ((0xA6F, 0x63B, 0xEDF), (0xDDD, 0x777, 0xFFF))),   # violeta y blanco
)

# sw[5:4]: fondo del mapa: (nombre, color de fondo, color del patrón, patrón).
# En hardware el patrón sale de bits de curr_x/curr_y, sin memoria.
FONDOS = (
    ("rejilla", 0x002, 0x024, "rejilla"),   # líneas donde x[5:0] == 0 o y[5:0] == 0
    ("puntos",  0x000, 0x335, "puntos"),    # un punto de 2x2 donde x[4:1] == 0 y y[4:1] == 0
    ("tablero", 0x102, 0x214, "tablero"),   # x[6] ^ y[6] elige el color
    ("liso",    0x111, 0x111, "liso"),
)

# --- Reglas fijas ---
SCORE_MAX = 99                  # 2 dígitos por jugador en el display
FRAMES_READY = 120              # 2 s de cuenta regresiva
FRAMES_ROUND = 120              # 2 s mostrando quién chocó
RAYO_CELDAS = 2                 # el rayo ocupa 2x2 celdas = 32x32 px, como su sprite

# Salida de cada moto: (cx, cy, dirección)
SALIDAS = (
    (12, (HUD_ROWS + GRID_H) // 2, DIR_RIGHT),          # P1, a la izquierda
    (GRID_W - 13, (HUD_ROWS + GRID_H) // 2, DIR_LEFT),  # P2, a la derecha
)

# --- Sprites ---
SPRITE = 16                     # las ROM son de 16x16...
ESCALA = 2                      # ...y se dibujan al doble: 32x32 px
SPRITE_PX = SPRITE * ESCALA     # la moto se centra en su celda de cabeza

# --- Teclado PS/2, códigos Set 2 ---
PS2_EXT = 0xE0                  # prefijo de tecla extendida (las flechas)
PS2_BREAK = 0xF0                # prefijo de "tecla soltada"

# (extendida, código) -> (jugador, dirección)
TECLAS_DIR = {
    (0, 0x1D): (0, DIR_UP),     # W
    (0, 0x1C): (0, DIR_LEFT),   # A
    (0, 0x1B): (0, DIR_DOWN),   # S
    (0, 0x23): (0, DIR_RIGHT),  # D
    (1, 0x75): (1, DIR_UP),     # flecha arriba
    (1, 0x6B): (1, DIR_LEFT),   # flecha izquierda
    (1, 0x72): (1, DIR_DOWN),   # flecha abajo
    (1, 0x74): (1, DIR_RIGHT),  # flecha derecha
}

# --- Paleta en RGB444 ---
PALETA = {
    "fondo":    0x002,
    "hud":      0x013,
    "rejilla":  0x024,
    "pared":    0x9AF,
    "pared_osc": 0x46A,
    "p1":       0x0DF,
    "p1_osc":   0x08A,
    "p1_cab":   0xEFF,
    "p2":       0xF80,
    "p2_osc":   0xA40,
    "p2_cab":   0xFEC,
    "llanta":   0x112,
    "choque":   0xF22,
    "rayo":     0xFF3,
    "rayo_osc": 0xC80,
    "seg_on":   0xF20,
    "seg_off":  0x200,
    "texto":    0xFFF,
    "sombra":   0x000,
    "sel":      0x35A,
}
