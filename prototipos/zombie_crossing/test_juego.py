"""
Pruebas de Zombie Crossing.  Ejecutar:  python3 test_juego.py
"""

from config import *
from juego import LFSR16, Juego, Carril, ROM_CESPED, ROM_TIRO


def test_lfsr_periodo_maximo():
    l = LFSR16(1)
    vistos = {l.siguiente() for _ in range(65535)}
    assert len(vistos) == 65535 and 0 not in vistos


def test_ocupado_con_offset():
    c = Carril(PISCINA, 0b1)     # solo el tile 0 ocupado
    assert c.ocupado(0) and c.ocupado(31) and not c.ocupado(32)
    c.offset = 40                # el nenúfar se movió 40 px a la derecha
    assert not c.ocupado(39) and c.ocupado(40) and c.ocupado(71) and not c.ocupado(72)
    c.offset = MASCARA_X         # -1 px: el tile queda partido en la orilla
    assert c.ocupado(0) and c.ocupado(ANCHO_VIRTUAL - 1)


def test_guisante_solo_golpea_en_su_centro():
    c = Carril(TIRO, 0b1, dir=1)  # un guisante en el tile 0
    assert not c.golpe(GUISANTE_INI - 1) and c.golpe(GUISANTE_INI)
    assert c.golpe(GUISANTE_FIN - 1) and not c.golpe(GUISANTE_FIN)
    c.offset = 100
    assert c.golpe(100 + GUISANTE_INI) and not c.golpe(GUISANTE_INI)


def test_planta_bloquea_su_orilla():
    j = Juego(semilla=0x99)
    for d, col in ((1, 0), (-1, COLS - 1)):
        c = Carril(TIRO, ROM_TIRO[0], dir=d)
        assert c.col_planta == col
        assert j._bloqueado(c, col * TILE + TILE // 2)
        assert not j._bloqueado(c, (COLS // 2) * TILE + TILE // 2)


def test_cesped_no_bloquea_columna_completa():
    for p in ROM_CESPED:
        assert bin(p & ((1 << COLS) - 1)).count("1") <= COLS // 3


def test_simulacion_aleatoria():
    """Juega 200k frames con entradas aleatorias y revisa invariantes."""
    j = Juego(semilla=0x1234)
    r = LFSR16(0xBEEF)
    muertes = set()
    for _ in range(200_000):
        v = r.siguiente()
        entrada = [ARRIBA, ARRIBA, IZQ, DER, ABAJO][v % 5] if v & 0x30 == 0 else NADA
        antes = j.estado
        j.paso(entrada)
        if antes == JUGANDO and j.estado == MUERTO:
            muertes.add(j.causa)
        assert j.cam <= j.jug_fila < j.cam + FILAS
        assert j.jug_fila - j.cam <= FILA_CAMARA
        for fila in range(j.cam, j.cam + FILAS):
            assert j.carril(fila) is not None
        c = j.carril(j.jug_fila)
        if j.estado == JUGANDO and c.tipo != PISCINA:
            assert j.jug_x % TILE == 0 and 0 <= j.jug_x <= ANCHO - TILE
            assert not j._bloqueado(c, j.jug_x + TILE // 2)
    assert "¡Te alcanzó un guisante!" in muertes
    assert "Te hundiste en la piscina" in muertes


def test_podadora_si_no_avanzas():
    j = Juego(semilla=0x77)
    j.paso(ARRIBA)                    # empieza el juego
    for _ in range(FRAMES_PODADORA):
        j.paso(NADA)
        assert j.estado == JUGANDO    # el césped inicial es seguro
    j.paso(NADA)
    assert j.estado == MUERTO and j.causa == "¡La podadora!"


def test_dibujo_no_falla():
    """Dibuja cada frame de varias partidas (inicio, juego y muerte) sin ventana."""
    import os
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    import pygame
    import main
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO))
    recursos = main.cargar_recursos()
    j = Juego(semilla=0x2468)
    r = LFSR16(0x1357)
    for _ in range(60 * 60):
        main.dibujar(pantalla, j, recursos)
        v = r.siguiente()
        j.paso([ARRIBA, ARRIBA, IZQ, DER][v % 4] if v & 0x1F == 0 else NADA)
    pygame.quit()


if __name__ == "__main__":
    for nombre, f in list(globals().items()):
        if nombre.startswith("test_"):
            f()
            print("ok ", nombre)
