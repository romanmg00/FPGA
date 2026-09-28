"""
Prototipo de Mountain Crash con pygame.

En la PC no hay acelerómetro, así que se simula:
- Mouse: la posición horizontal es la inclinación (centro = plano).
- Flechas izquierda/derecha: mantenerlas inclina la "tarjeta" poco a poco.
Espacio / Enter / clic = botón central (BTNC). Esc para salir.

Ejecutar:  python3 main.py
"""

import sys

import pygame

from config import *
from juego import Juego, SPRITES_AVION, MONTANA, COLOR_SPRITE


def rgb(c444):
    """RGB444 -> RGB888 (cada canal de 4 bits se repite: 0xA -> 0xAA)."""
    return (((c444 >> 8) & 0xF) * 17, ((c444 >> 4) & 0xF) * 17, (c444 & 0xF) * 17)


C = {nombre: rgb(v) for nombre, v in PALETA.items()}


def superficie_sprite(sprite):
    """ROM de 16x16 -> superficie de 32x32 (cada píxel se dibuja 2x2)."""
    s = pygame.Surface((SPRITE * ESCALA, SPRITE * ESCALA), pygame.SRCALPHA)
    for sy, fila in enumerate(sprite):
        for sx, ch in enumerate(fila):
            if ch != ".":
                s.fill(C[COLOR_SPRITE[ch]], (sx * ESCALA, sy * ESCALA, ESCALA, ESCALA))
    return s


class Simulador:
    """Convierte mouse/teclado en una lectura "cruda" del acelerómetro."""

    def __init__(self):
        self.modo_mouse = True
        self.valor_teclado = 0

    def evento(self, ev):
        if ev.type == pygame.MOUSEMOTION:
            self.modo_mouse = True
        elif ev.type == pygame.KEYDOWN and ev.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_a, pygame.K_d):
            self.modo_mouse = False

    def leer(self):
        if self.modo_mouse:
            mx = pygame.mouse.get_pos()[0]
            return (mx - ANCHO // 2) * ACCEL_MAX // (ANCHO // 2 - 40)
        teclas = pygame.key.get_pressed()
        if teclas[pygame.K_LEFT] or teclas[pygame.K_a]:
            self.valor_teclado = max(self.valor_teclado - 4, -ACCEL_MAX)
        elif teclas[pygame.K_RIGHT] or teclas[pygame.K_d]:
            self.valor_teclado = min(self.valor_teclado + 4, ACCEL_MAX)
        else:
            self.valor_teclado -= max(-8, min(8, self.valor_teclado))
        return self.valor_teclado


def texto(pantalla, fuente, msg, y, x=None):
    for d, col in ((2, C["sombra"]), (0, C["texto"])):
        img = fuente.render(msg, False, col)
        xx = (ANCHO - img.get_width()) // 2 if x is None else x
        pantalla.blit(img, (xx + d, y + d))


def dibujar(pantalla, juego, recursos):
    img_montana, imgs_avion, fuente, fuente_grande = recursos

    # Terreno: fila n ocupa las y de pantalla [ALTO - 32(n+1) + dist, ... + 32).
    abajo = juego.dist >> TILE_BITS
    arriba = (juego.dist + ALTO - 1) >> TILE_BITS
    for n in range(abajo, arriba + 1):
        y = ALTO - TILE * (n + 1) + juego.dist
        f = juego.fila(n)
        pantalla.fill(C["valle"] if n & 1 else C["valle_osc"], (0, y, ANCHO, TILE))
        for c in range(COLS):
            if (f.montanas >> c) & 1:
                pantalla.blit(img_montana, (c * TILE, y))

    # Avión (o explosión).
    x = juego.avion_x
    if juego.estado == CHOQUE and juego.frames_choque < 40:
        col = C["fuego1"] if (juego.frames_choque >> 2) & 1 else C["fuego2"]
        r = 6 + juego.frames_choque // 2
        pygame.draw.rect(pantalla, col, (x + 16 - r, AVION_Y + 16 - r, 2 * r, 2 * r))
    elif juego.estado != CHOQUE:
        pantalla.blit(imgs_avion[juego.pose], (x, AVION_Y))

    # HUD: puntos y barra de inclinación (útil también para depurar en la tarjeta).
    texto(pantalla, fuente, f"{juego.puntos}   récord {juego.record}", 8, x=10)
    pygame.draw.rect(pantalla, C["sombra"], (ANCHO // 2 - 66, ALTO - 18, 132, 10))
    pygame.draw.rect(pantalla, C["avion_osc"], (ANCHO // 2 - ZONA_MUERTA, ALTO - 16, 2 * ZONA_MUERTA, 6))
    pygame.draw.rect(pantalla, C["franja"], (ANCHO // 2 + juego.accel - 2, ALTO - 20, 4, 14))

    if juego.estado == INICIO:
        texto(pantalla, fuente_grande, "MOUNTAIN CRASH", 150)
        texto(pantalla, fuente, "Inclina (mouse / flechas) para girar", 220)
        texto(pantalla, fuente, "Espacio para despegar", 255)
    elif juego.estado == CHOQUE:
        texto(pantalla, fuente_grande, "¡CRASH!", 150)
        texto(pantalla, fuente, f"Puntos: {juego.puntos}", 220)
        if juego.frames_choque > FRAMES_ESPERA_CHOQUE:
            texto(pantalla, fuente, "Espacio para reintentar", 255)


def main():
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
    pygame.display.set_caption("Mountain Crash - prototipo")
    reloj = pygame.time.Clock()
    recursos = (
        superficie_sprite(MONTANA),
        [superficie_sprite(s) for s in SPRITES_AVION],
        pygame.font.Font(None, 32),
        pygame.font.Font(None, 64),
    )
    juego = Juego(semilla=pygame.time.get_ticks() | 1)
    sim = Simulador()

    while True:
        boton = False
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT or (ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE):
                pygame.quit()
                sys.exit()
            sim.evento(ev)
            if (ev.type == pygame.KEYDOWN and ev.key in (pygame.K_SPACE, pygame.K_RETURN)) \
                    or ev.type == pygame.MOUSEBUTTONDOWN:
                boton = True

        juego.paso(sim.leer(), boton)
        dibujar(pantalla, juego, recursos)
        pygame.display.flip()
        reloj.tick(FPS)


if __name__ == "__main__":
    main()
