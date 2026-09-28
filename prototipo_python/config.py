"""
Constantes del juego Mountain Crash.

Los valores están elegidos pensando en la Nexys A7 (Artix-7):
- 640x480 es la resolución VGA estándar (reloj de píxel de 25 MHz).
- La Nexys A7 tiene VGA de 4 bits por canal -> paleta RGB444.
- El acelerómetro ADXL362 entrega en modo 8 bits (±2 g) unos 64 LSB por g,
  así que inclinar la tarjeta 90° da aprox. ±64.
- Los tamaños son potencias de 2 siempre que se puede, para que en hardware
  las divisiones sean cortes de bits (x >> 5, fila & 15...).
"""

# --- Pantalla (VGA 640x480 @ 60 Hz) ---
ANCHO = 640
ALTO = 480
FPS = 60

# --- Terreno: cuadrícula de tiles ---
TILE = 32                   # 2^5 píxeles -> columna = x >> 5
TILE_BITS = 5
COLS = ANCHO // TILE        # 20 columnas
MASCARA_COLS = (1 << COLS) - 1
# Con scroll suave se ven hasta 16 filas a la vez (15 completas + 1 partida),
# así que el buffer circular tiene exactamente 16 filas.
NUM_FILAS = 16
MASCARA_FILA = NUM_FILAS - 1

# --- Sprites: 16x16 dibujados al doble (cada píxel del sprite = 2x2 en pantalla) ---
SPRITE = 16
ESCALA = 2

# --- Punto fijo: posiciones y velocidades en 1/16 de píxel (Q4) ---
FP_BITS = 4

# --- Scroll (velocidad del avión hacia adelante) ---
VEL_INICIAL = 2 << FP_BITS      # 2 px/frame
VEL_MAXIMA = 6 << FP_BITS       # 6 px/frame
FRAMES_ACELERAR = 64            # cada 64 frames la velocidad sube 1/16 px/frame

# --- Avión ---
AVION_Y = ALTO - 96             # fila de pantalla fija (esquina superior del sprite)
AVION_TAM = SPRITE * ESCALA     # 32 px

# --- Acelerómetro ---
ACCEL_MAX = 64                  # ~1 g: se satura aquí
ZONA_MUERTA = 6                 # |a| menor que esto -> el avión no se mueve
UMBRAL_INCLINADO = 16           # a partir de aquí se dibuja el avión inclinado
# velocidad lateral (Q4) = (a - zona_muerta) * 3 / 2  -> máx. ~5.4 px/frame

# --- Generación del terreno ---
FILAS_SEGURAS = 16              # la primera pantalla es valle libre (despegue)
ANCHO_PASILLO_INICIAL = 9       # tiles libres garantizados
ANCHO_PASILLO_MINIMO = 4
FILAS_ANGOSTAR = 48             # cada 48 filas el pasillo pierde 1 tile

# --- Estados de la máquina de estados principal ---
INICIO = 0
JUGANDO = 1
CHOQUE = 2
FRAMES_ESPERA_CHOQUE = 60       # tiempo antes de aceptar el botón para reiniciar

# --- Paleta en RGB444 (12 bits: 4 bits por canal) ---
PALETA = {
    "valle":      0x3A4,
    "valle_osc":  0x394,
    "roca":       0x864,
    "roca_osc":   0x542,
    "nieve":      0xEEF,
    "avion":      0xEEE,
    "avion_osc":  0x99A,
    "franja":     0xD22,
    "cabina":     0x237,
    "fuego1":     0xF80,
    "fuego2":     0xFE3,
    "texto":      0xFFF,
    "sombra":     0x000,
}
