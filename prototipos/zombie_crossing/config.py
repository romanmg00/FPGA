"""
Constantes de Zombie Crossing (tipo Crossy Road con tema de Plantas vs Zombies).

Los valores están elegidos pensando en la Nexys A7 (Artix-7):
- 640x480 es la resolución VGA estándar (reloj de píxel de 25 MHz).
- La Nexys A7 tiene VGA de 4 bits por canal -> paleta RGB444.
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

# --- Sprites: dibujados al doble (cada píxel del sprite = 2x2 en pantalla) ---
ESCALA = 2

# --- Tipos de carril ---
CESPED = 0      # pasto con nueces que bloquean el paso
TIRO = 1        # una planta en la orilla dispara guisantes
PISCINA = 2     # agua con nenúfares

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
FILA_INICIAL = 1            # fila (absoluta) donde aparece el zombie
FILAS_SEGURAS = 3           # primeras filas siempre son césped sin nueces
FILA_CAMARA = 5             # si el zombie sube más de esto en pantalla, la cámara avanza
# Un guisante ocupa solo el centro de su tile: píxeles 8..23 de los 32.
GUISANTE_INI = 8
GUISANTE_FIN = 24
# Puntos del zombie que se revisan contra los guisantes (desde su borde izquierdo).
PUNTOS_ZOMBIE = (8, 16, 23)
FRAMES_PODADORA = 8 * FPS   # 8 s sin avanzar -> llega la podadora
FRAMES_AVISO_PODADORA = 90  # 1.5 s antes se ve venir por la izquierda
FRAMES_ESPERA_MUERTO = 45   # tiempo antes de aceptar tecla para reiniciar

# --- Paleta en RGB444 (12 bits: 4 bits por canal) ---
PALETA = {
    "cesped":       0x6C3,
    "cesped_osc":   0x5B2,
    "tierra":       0x974,
    "tierra_osc":   0x863,
    "agua":         0x3AE,
    "agua_clara":   0x5CF,
    "texto":        0xFFF,
    "sombra":       0x000,
}
