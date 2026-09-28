"""
Pruebas de la lógica (sin pygame).  Ejecutar:  python3 test_juego.py
"""

from config import *
from juego import LFSR16, Juego, velocidad_lateral, pose_avion, POSE_IZQ, POSE_RECTO, POSE_DER


def test_lfsr_periodo_maximo():
    l = LFSR16(1)
    vistos = {l.siguiente() for _ in range(65535)}
    assert len(vistos) == 65535 and 0 not in vistos


def test_velocidad_lateral():
    assert velocidad_lateral(0) == 0
    assert velocidad_lateral(ZONA_MUERTA) == 0
    assert velocidad_lateral(-ZONA_MUERTA) == 0
    assert velocidad_lateral(ACCEL_MAX) == -velocidad_lateral(-ACCEL_MAX) > 0
    # Proporcional: más inclinación, más velocidad.
    vs = [velocidad_lateral(a) for a in range(ZONA_MUERTA, ACCEL_MAX + 1)]
    assert vs == sorted(vs)


def test_pose():
    assert pose_avion(-40) == POSE_IZQ
    assert pose_avion(3) == POSE_RECTO
    assert pose_avion(40) == POSE_DER


def test_pasillo_siempre_libre_y_continuo():
    j = Juego(semilla=0x4321)
    anterior = None
    for n in range(FILAS_SEGURAS, FILAS_SEGURAS + 5000):
        j._generar(n)
        f = j.fila(n)
        pasillo = ((1 << f.ancho) - 1) << f.izq
        assert f.montanas & pasillo == 0
        assert 0 <= f.izq and f.izq + f.ancho <= COLS
        if anterior is not None:
            # Los pasillos de filas seguidas se traslapan al menos 3 tiles.
            assert anterior & pasillo and bin(anterior & pasillo).count("1") >= 3
        anterior = pasillo


def test_piloto_automatico_sobrevive():
    """Un piloto que sigue el pasillo debe llegar lejos: el juego es ganable."""
    for semilla in (0x2468, 0xBEEF, 0x1234, 0x7777):
        j = Juego(semilla)
        j.paso(0, boton=True)
        for _ in range(60 * 90):          # 90 segundos
            j.paso(piloto_automatico(j))
            assert j.estado == JUGANDO, f"semilla {semilla:#x}: chocó en la fila {j.puntos}"
        assert j.vel_fp == VEL_MAXIMA


def piloto_automatico(j):
    """Apunta al centro de la zona libre común a las filas bajo el avión y la siguiente."""
    abajo = (j.dist + ALTO - 1 - (AVION_Y + AVION_TAM - 1)) >> TILE_BITS
    izq, der = 0, COLS
    for n in range(abajo, abajo + 3):
        f = j.fila(n)
        if max(izq, f.izq) >= min(der, f.izq + f.ancho):
            break                           # ya no hay traslape: basta con las anteriores
        izq, der = max(izq, f.izq), min(der, f.izq + f.ancho)
    objetivo = (izq + der) * TILE // 2 - AVION_TAM // 2
    return max(-ACCEL_MAX, min(ACCEL_MAX, objetivo - j.avion_x))


def test_sin_control_choca():
    j = Juego(semilla=0x1357)
    j.paso(0, boton=True)
    for _ in range(60 * 60):
        j.paso(ACCEL_MAX)             # tarjeta inclinada todo el tiempo a la derecha
        if j.estado == CHOQUE:
            break
    assert j.estado == CHOQUE and j.record == j.puntos


def test_dibujo_no_falla():
    """Dibuja cada frame de una partida completa (inicio, vuelo y choque) sin ventana."""
    import os
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    import pygame
    import main
    from juego import MONTANA, SPRITES_AVION
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO))
    recursos = (main.superficie_sprite(MONTANA), [main.superficie_sprite(s) for s in SPRITES_AVION],
                pygame.font.Font(None, 32), pygame.font.Font(None, 64))
    j = Juego(semilla=0x2468)
    for t in range(60 * 30):
        main.dibujar(pantalla, j, recursos)
        j.paso(piloto_automatico(j) if t < 60 * 20 else ACCEL_MAX, boton=(t == 10))
    assert j.estado == CHOQUE
    pygame.quit()


if __name__ == "__main__":
    for nombre, f in list(globals().items()):
        if nombre.startswith("test_"):
            f()
            print("ok ", nombre)
