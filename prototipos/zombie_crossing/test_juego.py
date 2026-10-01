"""
Pruebas de la lógica (sin pygame).  Ejecutar:  python3 test_juego.py
"""

from config import *
from juego import LFSR16, Juego, Carril, ROM_PASTO


def test_lfsr_periodo_maximo():
    l = LFSR16(1)
    vistos = set()
    for _ in range(65535):
        vistos.add(l.siguiente())
    assert len(vistos) == 65535 and 0 not in vistos


def test_ocupado_con_offset():
    c = Carril(CALLE, 0b1)       # solo el tile 0 ocupado
    assert c.ocupado(0) and c.ocupado(31) and not c.ocupado(32)
    c.offset = 40                # el auto se movió 40 px a la derecha
    assert not c.ocupado(39) and c.ocupado(40) and c.ocupado(71) and not c.ocupado(72)
    c.offset = MASCARA_X         # -1 px: el tile queda partido en la orilla
    assert c.ocupado(0) and c.ocupado(ANCHO_VIRTUAL - 1)


def test_pasto_no_bloquea_columna_completa():
    for p in ROM_PASTO:
        assert bin(p & ((1 << COLS) - 1)).count("1") <= COLS // 3


def test_simulacion_aleatoria():
    """Juega 200k frames con entradas aleatorias y revisa invariantes."""
    j = Juego(semilla=0x1234)
    r = LFSR16(0xBEEF)
    muertes = 0
    for _ in range(200_000):
        v = r.siguiente()
        entrada = [ARRIBA, ARRIBA, IZQ, DER, ABAJO][v % 5] if v & 0x30 == 0 else NADA
        antes = j.estado
        j.paso(entrada)
        if antes == JUGANDO and j.estado == MUERTO:
            muertes += 1
        assert j.cam <= j.jug_fila < j.cam + FILAS
        assert j.jug_fila - j.cam <= FILA_CAMARA
        for fila in range(j.cam, j.cam + FILAS):
            assert j.carril(fila) is not None
        if j.estado == JUGANDO and j.carril(j.jug_fila).tipo != RIO:
            assert j.jug_x % TILE == 0 and 0 <= j.jug_x <= ANCHO - TILE
    assert muertes > 0


if __name__ == "__main__":
    for nombre, f in list(globals().items()):
        if nombre.startswith("test_"):
            f()
            print("ok ", nombre)
