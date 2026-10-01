"""
Zombie Crossing: prototipo tipo Crossy Road con tema de Plantas vs Zombies.

Controles: flechas o WASD para avanzar, Esc para salir.
Ejecutar:  python3 main.py

Imágenes opcionales: si existe assets/<nombre>.png (por ejemplo assets/zombie.png),
se usa en lugar del pixel art. Esa carpeta no se sube a git. Ver assets/LEEME.md.
"""

import os
import sys

import pygame

from config import *
from juego import Juego
from sprites import SPRITES, COLORES

AQUI = os.path.dirname(os.path.abspath(__file__))
CARPETA_ASSETS = os.path.join(AQUI, "assets")

TECLAS = {
    pygame.K_UP: ARRIBA, pygame.K_w: ARRIBA,
    pygame.K_DOWN: ABAJO, pygame.K_s: ABAJO,
    pygame.K_LEFT: IZQ, pygame.K_a: IZQ,
    pygame.K_RIGHT: DER, pygame.K_d: DER,
}


def rgb(c444):
    """RGB444 -> RGB888 (cada canal de 4 bits se repite: 0xA -> 0xAA)."""
    return (((c444 >> 8) & 0xF) * 17, ((c444 >> 4) & 0xF) * 17, (c444 & 0xF) * 17)


C = {nombre: rgb(v) for nombre, v in PALETA.items()}


def cargar_sprite(nombre):
    """Superficie del sprite: assets/<nombre>.png si existe, si no el pixel art."""
    filas = SPRITES[nombre]
    tam = (len(filas[0]) * ESCALA, len(filas) * ESCALA)
    ruta = os.path.join(CARPETA_ASSETS, nombre + ".png")
    if os.path.exists(ruta):
        try:
            return pygame.transform.smoothscale(pygame.image.load(ruta).convert_alpha(), tam)
        except pygame.error as e:
            print(f"No se pudo cargar {ruta}: {e}. Uso el pixel art.")
    s = pygame.Surface(tam, pygame.SRCALPHA)
    colores = COLORES[nombre]
    for sy, fila in enumerate(filas):
        for sx, ch in enumerate(fila):
            if ch != ".":
                s.fill(rgb(colores[ch]), (sx * ESCALA, sy * ESCALA, ESCALA, ESCALA))
    return s


def cargar_recursos():
    img = {nombre: cargar_sprite(nombre) for nombre in SPRITES}
    # Las plantas de la orilla derecha miran a la izquierda.
    for planta in ("lanzaguisantes", "hielaguisantes"):
        img[planta + "_izq"] = pygame.transform.flip(img[planta], True, False)
    return img, pygame.font.Font(None, 32), pygame.font.Font(None, 56)


def dibujar_carril(pantalla, img, juego, fila, y):
    c = juego.carril(fila)

    if c.tipo == CESPED:
        # Césped a cuadros, como el jardín del juego original.
        for k in range(COLS):
            color = C["cesped"] if (k + fila) & 1 else C["cesped_osc"]
            pantalla.fill(color, (k * TILE, y, TILE, TILE))
            if (c.patron >> k) & 1:
                pantalla.blit(img["nuez"], (k * TILE, y))
        return

    if c.tipo == TIRO:
        for k in range(COLS):
            pantalla.fill(C["tierra"] if k & 1 else C["tierra_osc"], (k * TILE, y, TILE, TILE))
        bala = img["guisante_hielo" if c.hielo else "guisante"]
        dx = GUISANTE_INI      # el guisante va centrado en su tile
        dy = (TILE - bala.get_height()) // 2
    else:
        pantalla.fill(C["agua"], (0, y, ANCHO, TILE))
        pantalla.fill(C["agua_clara"], (0, y + 6, ANCHO, 2))
        bala = img["nenufar"]
        dx = dy = 0

    # Cada bit encendido del patrón es un guisante o un nenúfar.
    for k in range(CARRIL_BITS):
        if not (c.patron >> k) & 1:
            continue
        x = (k * TILE + c.offset) & MASCARA_X
        for xx in (x, x - ANCHO_VIRTUAL):   # el tile puede estar partido en la orilla
            if -TILE < xx < ANCHO:
                pantalla.blit(bala, (xx + dx, y + dy))

    if c.tipo == TIRO:
        # La planta va encima: los guisantes salen de su boca.
        nombre = "hielaguisantes" if c.hielo else "lanzaguisantes"
        if c.dir < 0:
            nombre += "_izq"
        pantalla.blit(img[nombre], (c.col_planta * TILE, y))


def texto(pantalla, fuente, msg, y, centrado=True):
    for d, col in ((2, C["sombra"]), (0, C["texto"])):
        img = fuente.render(msg, False, col)
        x = (ANCHO - img.get_width()) // 2 if centrado else 10
        pantalla.blit(img, (x + d, y + d))


def dibujar(pantalla, juego, recursos):
    img, fuente, fuente_grande = recursos
    for i in range(FILAS):
        dibujar_carril(pantalla, img, juego, juego.cam + i, ALTO - (i + 1) * TILE)

    y_jug = ALTO - (juego.jug_fila - juego.cam + 1) * TILE
    pantalla.blit(img["zombie"], (juego.jug_x, y_jug))

    # La podadora se ve venir por la izquierda en los últimos 1.5 s.
    faltan = FRAMES_PODADORA - juego.frames_sin_avanzar
    if juego.estado == JUGANDO and faltan < FRAMES_AVISO_PODADORA:
        avance = FRAMES_AVISO_PODADORA - faltan
        x_pod = -TILE + (juego.jug_x + TILE) * avance // FRAMES_AVISO_PODADORA
        pantalla.blit(img["podadora"], (x_pod, y_jug))
    elif juego.estado == MUERTO and juego.causa == "¡La podadora!":
        pantalla.blit(img["podadora"], (juego.jug_x, y_jug))

    texto(pantalla, fuente, f"{juego.puntos}   récord {juego.record}", 8, centrado=False)
    if juego.estado == INICIO:
        texto(pantalla, fuente_grande, "ZOMBIE CROSSING", 160)
        texto(pantalla, fuente, "Flechas / WASD para avanzar", 225)
    elif juego.estado == MUERTO:
        texto(pantalla, fuente_grande, juego.causa, 160)
        texto(pantalla, fuente, f"Puntos: {juego.puntos}", 225)
        if juego.frames_muerto > FRAMES_ESPERA_MUERTO:
            texto(pantalla, fuente, "Presiona una tecla", 265)


def main():
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
    pygame.display.set_caption("Zombie Crossing - prototipo")
    reloj = pygame.time.Clock()
    recursos = cargar_recursos()
    juego = Juego(semilla=pygame.time.get_ticks() | 1)

    pendientes = []   # teclas presionadas; se consume una por frame
    while True:
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT or (ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE):
                pygame.quit()
                sys.exit()
            if ev.type == pygame.KEYDOWN and ev.key in TECLAS:
                pendientes.append(TECLAS[ev.key])

        juego.paso(pendientes.pop(0) if pendientes else NADA)
        dibujar(pantalla, juego, recursos)
        pygame.display.flip()
        reloj.tick(FPS)


if __name__ == "__main__":
    main()
