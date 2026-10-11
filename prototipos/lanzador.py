"""
Menú para elegir qué prototipo correr.

Ejecutar:  python3 lanzador.py
Flechas + Enter (o el número del juego) para elegir, Esc para salir.
Al cerrar un juego se vuelve al menú.
"""

import os
import subprocess
import sys

import pygame

AQUI = os.path.dirname(os.path.abspath(__file__))
ANCHO, ALTO = 640, 480

JUEGOS = [
    ("Tron", "tron",
     "Motos de luz para 2 jugadores: rayos, vidas y menús."),
]


def correr(carpeta):
    """Corre el main.py del juego en su propio proceso: cada juego tiene su
    propio config.py y juego.py, y así no se mezclan."""
    ruta = os.path.join(AQUI, carpeta)
    subprocess.run([sys.executable, "main.py"], cwd=ruta)


def dibujar(pantalla, fuentes, elegido):
    grande, normal, chica = fuentes
    pantalla.fill((20, 24, 40))
    t = grande.render("Prototipos FPGA", True, (255, 255, 255))
    pantalla.blit(t, ((ANCHO - t.get_width()) // 2, 50))
    for i, (nombre, _, descripcion) in enumerate(JUEGOS):
        y = 110 + i * 84
        activo = i == elegido
        if activo:
            pygame.draw.rect(pantalla, (60, 90, 160), (60, y - 10, ANCHO - 120, 80), border_radius=8)
        color = (255, 255, 255) if activo else (170, 175, 190)
        pantalla.blit(normal.render(f"{i + 1}. {nombre}", True, color), (84, y))
        # La descripción en dos líneas si no cabe.
        palabras, lineas, actual = descripcion.split(), [], ""
        for p in palabras:
            prueba = (actual + " " + p).strip()
            if chica.size(prueba)[0] > ANCHO - 170:
                lineas.append(actual)
                actual = p
            else:
                actual = prueba
        lineas.append(actual)
        for k, linea in enumerate(lineas):
            pantalla.blit(chica.render(linea, True, color), (84, y + 32 + k * 20))
    ayuda = chica.render("Flechas + Enter para jugar  ·  Esc para salir", True, (140, 145, 160))
    pantalla.blit(ayuda, ((ANCHO - ayuda.get_width()) // 2, ALTO - 40))


def main():
    pygame.init()
    fuentes = (pygame.font.Font(None, 60), pygame.font.Font(None, 40), pygame.font.Font(None, 26))
    elegido = 0
    pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
    pygame.display.set_caption("Prototipos FPGA")
    reloj = pygame.time.Clock()
    while True:
        jugar = None
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT or (ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE):
                pygame.quit()
                return
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_UP, pygame.K_w):
                    elegido = (elegido - 1) % len(JUEGOS)
                elif ev.key in (pygame.K_DOWN, pygame.K_s):
                    elegido = (elegido + 1) % len(JUEGOS)
                elif ev.key in (pygame.K_RETURN, pygame.K_SPACE):
                    jugar = elegido
                elif pygame.K_1 <= ev.key < pygame.K_1 + len(JUEGOS):
                    jugar = ev.key - pygame.K_1

        if jugar is not None:
            # Se cierra la ventana del menú mientras corre el juego y luego se reabre.
            pygame.display.quit()
            correr(JUEGOS[jugar][1])
            pygame.display.init()
            pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
            pygame.display.set_caption("Prototipos FPGA")
            elegido = jugar
            continue

        dibujar(pantalla, fuentes, elegido)
        pygame.display.flip()
        reloj.tick(30)


if __name__ == "__main__":
    main()
