"""
Constantes del juego.

Los valores están elegidos pensando en la FPGA:
- 640x480 es la resolución VGA estándar (reloj de píxel de 25 MHz).
- Los tamaños son potencias de 2 siempre que se puede, para que en hardware
  las divisiones y módulos sean simples cortes de bits (x >> 5, x & 1023...).
"""

# --- Pantalla (VGA 640x480 @ 60 Hz) ---
ANCHO = 640
ALTO = 480
FPS = 60

# --- Cuadrícula ---
TILE = 32                   # 2^5 píxeles -> tile = x >> 5
TILE_BITS = 5
COLS = ANCHO // TILE        # 20 columnas visibles
FILAS = ALTO // TILE        # 15 carriles visibles

# Cada carril es un patrón de 32 tiles (1024 px) que "da la vuelta".
# Solo se ven 20 tiles; usar 32 hace que el offset sea un contador de 10 bits
# que se desborda solo, sin necesidad de calcular módulo 640.
CARRIL_BITS = 32
ANCHO_VIRTUAL = CARRIL_BITS * TILE   # 1024
MASCARA_X = ANCHO_VIRTUAL - 1        # 0x3FF

# Buffer circular de carriles (15 visibles + 1 que se está regenerando).
NUM_CARRILES = 16
MASCARA_CARRIL = NUM_CARRILES - 1

# --- Tipos de carril ---
PASTO = 0
CALLE = 1
RIO = 2

# --- Entradas (en la FPGA serán los botones de la tarjeta) ---
NADA = 0
ARRIBA = 1
ABAJO = 2
IZQ = 3
DER = 4

# --- Estados de la máquina de estados principal ---
INICIO = 0
JUGANDO = 1
MUERTO = 2

# --- Reglas ---
FILA_INICIAL = 1            # fila (absoluta) donde aparece la gallina
FILAS_SEGURAS = 3           # primeras filas siempre son pasto sin árboles
FILA_CAMARA = 5             # si la gallina sube más de esto en pantalla, la cámara avanza
MARGEN_CHOQUE = 6           # píxeles de "perdón" a cada lado al chocar con autos
FRAMES_AGUILA = 8 * FPS     # 8 s sin avanzar -> el águila se la lleva
FRAMES_ESPERA_MUERTO = 45   # tiempo antes de aceptar tecla para reiniciar

# --- Paleta en RGB444 (12 bits: 4 bits por canal) ---
# Muchas tarjetas (Basys 3, DE10-Lite, Nexys A7) usan VGA de 4 bits por canal,
# así que el prototipo solo usa colores que la tarjeta puede mostrar tal cual.
PALETA = {
    "pasto":        0x5B3,
    "pasto_osc":    0x4A3,
    "arbol":        0x262,
    "tronco_arbol": 0x631,
    "calle":        0x444,
    "linea":        0xCCC,
    "agua":         0x39E,
    "tronco":       0x852,
    "tronco_osc":   0x630,
    "gallina":      0xFFF,
    "cresta":       0xF22,
    "pico":         0xF90,
    "ojo":          0x000,
    "texto":        0xFFF,
    "sombra":       0x000,
}
COLORES_AUTOS = [0xE33, 0x36E, 0xEC2, 0xA4D, 0x2CA, 0xF80]
