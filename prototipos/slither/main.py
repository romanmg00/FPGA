"""
Prototipo de Slither.io con pygame.

Se dibuja igual que lo hará drawcon: para cada celda se lee el tipo en la arena
y se pinta el sprite de 16x16 de ese tipo. El jugador es verde y los bots,
naranja y morado.

Controles (entre paréntesis, lo que serían en la tarjeta):
  Flechas / WASD  dirección (BTNU, BTND, BTNL, BTNR)
  Espacio / Enter empezar o reiniciar (BTNC)
  T               alternar control por inclinación (sw[0]); el mouse simula
                  el acelerómetro: su distancia al centro es la inclinación
  1-4             velocidad (sw[2:1])
  Esc             salir

Ejecutar:  python3 main.py
"""

import sys

import pygame

from config import *
from juego import Juego, dir_desde_botones, dir_desde_inclinacion, cx_de, cy_de


def rgb(c444):
    """RGB444 -> RGB888 (cada canal de 4 bits se repite: 0xA -> 0xAA)."""
    return (((c444 >> 8) & 0xF) * 17, ((c444 >> 4) & 0xF) * 17, (c444 & 0xF) * 17)


C = {nombre: rgb(v) for nombre, v in PALETA.items()}

# ----------------------------------------------------------------------
# ROMs de sprites (16x16). Cada carácter es un índice de color; '.' = fondo.
# Cabeza y cuerpo usan 'C' (color principal) y 'S' (sombra): el mismo sprite
# sirve para las tres serpientes cambiando solo la paleta, como se haría en
# hardware con una ROM y un multiplexor de color.
# ----------------------------------------------------------------------
CABEZA = (
    "....SSSSSSSS....",
    "..SSCCCCCCCCSS..",
    ".SCCCCCCCCCCCCS.",
    ".SCCCCCCCCCCCCS.",
    "SCCEEEECCEEEECCS",
    "SCEEEEEECEEEEEES",
    "SCEEPPEECEEPPEES",
    "SCEEPPEECEEPPEES",
    "SCEEEEEECEEEEEES",
    "SCCEEEECCCEEEECS",
    "SCCCCCCCCCCCCCCS",
    ".SCCCCCCCCCCCCS.",
    ".SCCCCCCCCCCCCS.",
    "..SSCCCCCCCCSS..",
    "....SSSSSSSS....",
    "................",
)

CUERPO = (
    "................",
    ".....SSSSSS.....",
    "...SSCCCCCCSS...",
    "..SCCCCCCCCCCS..",
    "..SCCEECCCCCCS..",
    ".SCCEECCCCCCCCS.",
    ".SCCCCCCCCCCCCS.",
    ".SCCCCCCCCCCCCS.",
    ".SCCCCCCCCCCCCS.",
    ".SCCCCCCCCCCCCS.",
    "..SCCCCCCCCCCS..",
    "..SCCCCCCCCCCS..",
    "...SSCCCCCCSS...",
    ".....SSSSSS.....",
    "................",
    "................",
)

COMIDA = (
    "................",
    "................",
    "................",
    "................",
    "......FFFF......",
    ".....FFFFFF.....",
    "....FFBBFFFF....",
    "....FFBBFFFF....",
    "....FFFFFFFF....",
    "....FFFFFFFF....",
    ".....FFFFFF.....",
    "......FFFF......",
    "................",
    "................",
    "................",
    "................",
)

PARED = (
    "WWWWWWWDWWWWWWWD",
    "WWWWWWWDWWWWWWWD",
    "WWWWWWWDWWWWWWWD",
    "DDDDDDDDDDDDDDDD",
    "WWWDWWWWWWWDWWWW",
    "WWWDWWWWWWWDWWWW",
    "WWWDWWWWWWWDWWWW",
    "DDDDDDDDDDDDDDDD",
    "WWWWWWWDWWWWWWWD",
    "WWWWWWWDWWWWWWWD",
    "WWWWWWWDWWWWWWWD",
    "DDDDDDDDDDDDDDDD",
    "WWWDWWWWWWWDWWWW",
    "WWWDWWWWWWWDWWWW",
    "WWWDWWWWWWWDWWWW",
    "DDDDDDDDDDDDDDDD",
)

for _s in (CABEZA, CUERPO, COMIDA, PARED):
    assert len(_s) == TILE and all(len(f) == TILE for f in _s)


def superficie(sprite, colores):
    s = pygame.Surface((TILE, TILE), pygame.SRCALPHA)
    for sy, fila in enumerate(sprite):
        for sx, ch in enumerate(fila):
            if ch != ".":
                s.fill(colores[ch], (sx, sy, 1, 1))
    return s


def crear_sprites():
    """Tipo de celda -> superficie, como la ROM más la paleta de drawcon."""
    fijos = {"E": C["ojo"], "P": C["pupila"], "F": C["comida"], "B": C["comida_br"],
             "W": C["pared"], "D": C["pared_osc"]}
    sprites = {CELL_WALL: superficie(PARED, fijos), CELL_FOOD: superficie(COMIDA, fijos)}
    for nombre, cabeza in (("jugador", CELL_P_HEAD), ("bot0", CELL_B0_HEAD), ("bot1", CELL_B1_HEAD)):
        col = dict(fijos, C=C[nombre], S=C[nombre + "_osc"])
        cuerpo = dict(col, E=C[nombre])      # el cuerpo no tiene ojos; 'E' es un brillo
        cuerpo["E"] = tuple(min(255, v + 70) for v in C[nombre])
        sprites[cabeza] = superficie(CABEZA, col)
        sprites[cabeza + 1] = superficie(CUERPO, cuerpo)
    return sprites


def crear_fondo():
    """Fondo en tablero de ajedrez: (cx ^ cy) & 1 elige uno de dos tonos."""
    f = pygame.Surface((ANCHO, ALTO))
    for cy in range(GRID_H):
        for cx in range(GRID_W):
            f.fill(C["fondo1"] if (cx ^ cy) & 1 else C["fondo2"], (cx * TILE, cy * TILE, TILE, TILE))
    return f


def texto(pantalla, fuente, msg, y, x=None):
    for d, col in ((2, C["sombra"]), (0, C["texto"])):
        img = fuente.render(msg, True, col)
        xx = (ANCHO - img.get_width()) // 2 if x is None else x
        pantalla.blit(img, (xx + d, y + d))


def dibujar(pantalla, juego, recursos, entrada):
    fondo, sprites, fuente, fuente_grande = recursos
    pantalla.blit(fondo, (0, 0))

    # drawcon: un sprite por celda según lo que diga la arena.
    for addr, v in enumerate(juego.arena):
        if v != CELL_EMPTY:
            pantalla.blit(sprites[v], (cx_de(addr) * TILE, cy_de(addr) * TILE))

    # Lo que en la tarjeta va al display de 7 segmentos y a los LEDs.
    texto(pantalla, fuente, f"7seg: {juego.score:04d}   récord {juego.record}", 20, x=24)
    leds = min(16, (juego.player_len * 16 + MAX_LEN - 1) // MAX_LEN)
    for i in range(16):
        x = ANCHO - 24 - (i + 1) * 18
        pygame.draw.rect(pantalla, C["led_on"] if i < leds else C["led_off"], (x, 22, 12, 12))
    modo = "inclinación (mouse)" if entrada.usar_tilt else "botones"
    texto(pantalla, fuente, f"sw[0]: {modo}   sw[2:1]: velocidad {juego.velocidad}", ALTO - 44, x=24)
    if entrada.usar_tilt:
        tx, ty = entrada.tilt()
        cx, cy = ANCHO // 2, ALTO // 2
        pygame.draw.circle(pantalla, C["pared"], (cx, cy), TILT_ZONA_MUERTA * 300 // TILT_MAX, 1)
        pygame.draw.line(pantalla, C["texto"], (cx, cy), (cx + tx * 300 // TILT_MAX, cy + ty * 300 // TILT_MAX))

    if juego.estado == ST_START:
        texto(pantalla, fuente_grande, "SLITHER.FPGA", 300)
        texto(pantalla, fuente, "Come bolitas para crecer. No choques con paredes ni con otras serpientes.", 380)
        texto(pantalla, fuente, "Encierra a los bots: si chocan con tu cuerpo, se vuelven comida.", 412)
        texto(pantalla, fuente, "Espacio para empezar", 470)
    elif juego.estado == ST_DEAD:
        texto(pantalla, fuente_grande, "GAME OVER", 320)
        texto(pantalla, fuente, f"Puntos: {juego.score}   Largo: {juego.player_len}", 390)
        texto(pantalla, fuente, "Espacio para reiniciar", 430)


class Entrada:
    """Teclado y mouse -> btn, sw y la lectura del acelerómetro."""

    def __init__(self):
        self.usar_tilt = False
        self.player_dir = SALIDA_JUGADOR[2]

    def tilt(self):
        mx, my = pygame.mouse.get_pos()
        escala = ALTO // 2
        tx = max(-TILT_MAX, min(TILT_MAX, (mx - ANCHO // 2) * TILT_MAX // escala))
        ty = max(-TILT_MAX, min(TILT_MAX, (my - ALTO // 2) * TILT_MAX // escala))
        return tx, ty

    def leer(self, teclas):
        if self.usar_tilt:
            self.player_dir = dir_desde_inclinacion(*self.tilt(), self.player_dir)
        else:
            btn = ((teclas[pygame.K_UP] or teclas[pygame.K_w]) << 0
                   | (teclas[pygame.K_DOWN] or teclas[pygame.K_s]) << 1
                   | (teclas[pygame.K_LEFT] or teclas[pygame.K_a]) << 2
                   | (teclas[pygame.K_RIGHT] or teclas[pygame.K_d]) << 3)
            self.player_dir = dir_desde_botones(btn, self.player_dir)
        return self.player_dir


def main():
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
    pygame.display.set_caption("Slither.io - prototipo")
    reloj = pygame.time.Clock()
    recursos = (crear_fondo(), crear_sprites(), pygame.font.Font(None, 30), pygame.font.Font(None, 96))
    juego = Juego(semilla=pygame.time.get_ticks() | 1)
    entrada = Entrada()
    velocidad = VEL_INICIAL

    while True:
        start = False
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT or (ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE):
                pygame.quit()
                sys.exit()
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_SPACE, pygame.K_RETURN):
                    start = True
                elif ev.key == pygame.K_t:
                    entrada.usar_tilt = not entrada.usar_tilt
                elif pygame.K_1 <= ev.key <= pygame.K_4:
                    velocidad = ev.key - pygame.K_1

        if start and juego.estado != ST_PLAY:
            entrada.player_dir = SALIDA_JUGADOR[2]
        juego.paso(entrada.leer(pygame.key.get_pressed()), start, velocidad)
        dibujar(pantalla, juego, recursos, entrada)
        pygame.display.flip()
        reloj.tick(FPS)


if __name__ == "__main__":
    main()
