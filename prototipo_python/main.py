"""
Prototipo tipo Crossy Road con pygame.

Controles: flechas o WASD para saltar, Esc para salir.
Ejecutar:  python3 main.py
"""

import sys

import pygame

from config import *
from juego import Juego

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
C_AUTOS = [rgb(v) for v in COLORES_AUTOS]


def dibujar_carril(pantalla, juego, fila, y):
    c = juego.carril(fila)

    if c.tipo == PASTO:
        pygame.draw.rect(pantalla, C["pasto"] if fila & 1 else C["pasto_osc"], (0, y, ANCHO, TILE))
        for k in range(COLS):
            if (c.patron >> k) & 1:
                x = k * TILE
                pygame.draw.rect(pantalla, C["tronco_arbol"], (x + 12, y + 20, 8, 10))
                pygame.draw.rect(pantalla, C["arbol"], (x + 4, y + 2, 24, 20))
        return

    if c.tipo == CALLE:
        pygame.draw.rect(pantalla, C["calle"], (0, y, ANCHO, TILE))
        if juego.carril(fila + 1).tipo == CALLE:
            for x in range(0, ANCHO, 40):
                pygame.draw.rect(pantalla, C["linea"], (x + 8, y - 1, 20, 2))
        color = C_AUTOS[c.color]
    else:
        pygame.draw.rect(pantalla, C["agua"], (0, y, ANCHO, TILE))
        color = C["tronco"]

    # Obstáculos: cada bit encendido del patrón es un tile de auto/tronco.
    for k in range(CARRIL_BITS):
        if not (c.patron >> k) & 1:
            continue
        x = (k * TILE + c.offset) & MASCARA_X
        for xx in (x, x - ANCHO_VIRTUAL):   # el tile puede estar partido en la orilla
            if -TILE < xx < ANCHO:
                if c.tipo == CALLE:
                    pygame.draw.rect(pantalla, color, (xx, y + 5, TILE, TILE - 10))
                    pygame.draw.rect(pantalla, C["sombra"], (xx, y + 3, TILE, 2))
                else:
                    pygame.draw.rect(pantalla, color, (xx, y + 4, TILE, TILE - 8))
                    pygame.draw.rect(pantalla, C["tronco_osc"], (xx, y + 14, TILE, 3))


def dibujar_gallina(pantalla, x, y):
    pygame.draw.rect(pantalla, C["gallina"], (x + 6, y + 8, 20, 20))
    pygame.draw.rect(pantalla, C["cresta"], (x + 12, y + 3, 8, 5))
    pygame.draw.rect(pantalla, C["pico"], (x + 13, y + 16, 6, 4))
    pygame.draw.rect(pantalla, C["ojo"], (x + 10, y + 12, 3, 3))
    pygame.draw.rect(pantalla, C["ojo"], (x + 19, y + 12, 3, 3))


def texto(pantalla, fuente, msg, y, centrado=True):
    for dx, dy, col in ((2, 2, C["sombra"]), (0, 0, C["texto"])):
        img = fuente.render(msg, False, col)
        x = (ANCHO - img.get_width()) // 2 if centrado else 10
        pantalla.blit(img, (x + dx, y + dy))


def dibujar(pantalla, juego, fuente, fuente_grande):
    for i in range(FILAS):
        dibujar_carril(pantalla, juego, juego.cam + i, ALTO - (i + 1) * TILE)

    y_jug = ALTO - (juego.jug_fila - juego.cam + 1) * TILE
    dibujar_gallina(pantalla, juego.jug_x, y_jug)

    texto(pantalla, fuente, f"{juego.puntos}   récord {juego.record}", 8, centrado=False)
    if juego.estado == INICIO:
        texto(pantalla, fuente_grande, "CROSSY FPGA", 160)
        texto(pantalla, fuente, "Flechas / WASD para saltar", 230)
    elif juego.estado == MUERTO:
        texto(pantalla, fuente_grande, juego.causa, 160)
        texto(pantalla, fuente, f"Puntos: {juego.puntos}", 230)
        if juego.frames_muerto > FRAMES_ESPERA_MUERTO:
            texto(pantalla, fuente, "Presiona una tecla", 270)


def main():
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
    pygame.display.set_caption("Crossy FPGA - prototipo")
    reloj = pygame.time.Clock()
    fuente = pygame.font.Font(None, 32)
    fuente_grande = pygame.font.Font(None, 64)
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
        dibujar(pantalla, juego, fuente, fuente_grande)
        pygame.display.flip()
        reloj.tick(FPS)


if __name__ == "__main__":
    main()
