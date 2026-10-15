"""
Pruebas de la lógica (sin pygame).  Ejecutar:  python3 test_juego.py

Son también la lista de casos que deben cubrir los testbenches de snake_engine.
"""

from config import *
from juego import (LFSR16, Juego, BotAI, Serpiente, cell_addr, cx_de, cy_de, vecino,
                   dir_desde_botones, dir_desde_inclinacion, GIRO_NADA, GIRO_DER, GIRO_IZQ)

QUIETOS = [GIRO_NADA] * N_BOTS


def juego_sin_bots():
    """Partida empezada, con los bots quitados de la arena para aislar al jugador."""
    j = Juego(semilla=0x1234)
    j.paso(DIR_RIGHT, start=True)
    for s in j.serpientes[1:]:
        for i in range(s.largo):
            j.arena[s.celda(i)] = CELL_EMPTY
        s.viva = False
        s.reaparecer = 10 ** 9
    for addr in range(MAP_SIZE):
        if j.arena[addr] == CELL_FOOD:
            j.arena[addr] = CELL_EMPTY
    j.comida = N_FOOD               # que no aparezca comida sola
    return j


def avanzar_un_paso(j, d):
    """Corre cuadros hasta que el jugador se mueve una celda."""
    for _ in range(MOVE_FRAMES_POR_VEL[j.velocidad]):
        j.paso(d, bot_turn=QUIETOS)


def test_lfsr_periodo_maximo():
    l = LFSR16(1)
    vistos = {l.siguiente() for _ in range(65535)}
    assert len(vistos) == 65535 and 0 not in vistos


def test_direccion_de_celda():
    assert cell_addr(0, 0) == 0
    assert cell_addr(79, 49) == (49 << 7) | 79
    assert (cx_de(cell_addr(37, 21)), cy_de(cell_addr(37, 21))) == (37, 21)
    # Las restas dan la vuelta con máscara, como en hardware.
    assert vecino(cell_addr(0, 5), DIR_LEFT) == cell_addr(127, 5)


def test_arena_limpia():
    j = Juego()
    j.limpiar_arena()
    assert j.contar(CELL_WALL) == 2 * GRID_W + 2 * (GRID_H - 2)
    assert j.arena[cell_addr(0, 0)] == CELL_WALL
    assert j.arena[cell_addr(GRID_W - 1, GRID_H - 1)] == CELL_WALL
    assert j.arena[cell_addr(1, 1)] == CELL_EMPTY
    assert j.arena[cell_addr(GRID_W, 0)] == CELL_EMPTY      # fuera de la arena


def test_inicio_de_partida():
    j = Juego()
    j.paso(DIR_RIGHT)
    assert j.estado == ST_START             # sin start no empieza
    j.paso(DIR_RIGHT, start=True)
    assert j.estado == ST_PLAY
    assert j.player_len == START_LEN
    assert j.contar(CELL_P_HEAD) == 1 and j.contar(CELL_P_BODY) == START_LEN - 1


def test_se_mueve_una_celda_cada_move_frames():
    j = juego_sin_bots()
    cabeza = j.jugador.cabeza
    for _ in range(MOVE_FRAMES_POR_VEL[j.velocidad] - 1):
        j.paso(DIR_RIGHT, bot_turn=QUIETOS)
    assert j.jugador.cabeza == cabeza
    j.paso(DIR_RIGHT, bot_turn=QUIETOS)
    assert j.jugador.cabeza == vecino(cabeza, DIR_RIGHT)
    assert j.contar(CELL_P_BODY) == START_LEN - 1     # el largo no cambia


def test_giro_de_180_se_ignora():
    j = juego_sin_bots()
    cabeza = j.jugador.cabeza
    avanzar_un_paso(j, DIR_LEFT)                      # va a la derecha
    assert j.estado == ST_PLAY
    assert j.jugador.cabeza == vecino(cabeza, DIR_RIGHT)


def test_muere_en_la_pared():
    j = juego_sin_bots()
    for _ in range(GRID_W):
        avanzar_un_paso(j, DIR_RIGHT)
        if j.estado == ST_DEAD:
            break
    assert j.estado == ST_DEAD
    assert cx_de(j.jugador.cabeza) == GRID_W - 2      # la cabeza no entra a la pared
    j.paso(DIR_RIGHT, start=True)
    assert j.estado == ST_PLAY and j.score == 0


def test_comer_crece_y_suma():
    j = juego_sin_bots()
    adelante = vecino(j.jugador.cabeza, DIR_RIGHT)
    j.arena[adelante] = CELL_FOOD
    j.comida = N_FOOD                                 # no reponer
    avanzar_un_paso(j, DIR_RIGHT)
    assert j.score == 1 and j.player_len == START_LEN + 1
    assert j.comida == N_FOOD - 1
    assert j.contar(CELL_P_BODY) == START_LEN


def test_largo_maximo():
    j = juego_sin_bots()
    j.jugador.largo = MAX_LEN       # se finge que ya está lleno (las celdas extra no importan aquí)
    for i in range(MAX_LEN - START_LEN):
        j.jugador.buf[(j.jugador.ptr - START_LEN - i) & (MAX_LEN - 1)] = cell_addr(1, 1)
    j.arena[vecino(j.jugador.cabeza, DIR_RIGHT)] = CELL_FOOD
    avanzar_un_paso(j, DIR_RIGHT)
    assert j.player_len == MAX_LEN and j.score == 1


def test_la_cola_que_se_va():
    """La cabeza puede entrar a la celda que deja la cola en el mismo paso."""
    j = juego_sin_bots()
    s = j.jugador
    # Serpiente de 4 en un cuadro de 2x2: cola (10,10), luego (11,10), (11,11), cabeza (10,11).
    for addr in range(MAP_SIZE):
        if j.arena[addr] in (CELL_P_HEAD, CELL_P_BODY):
            j.arena[addr] = CELL_EMPTY
    celdas = [cell_addr(10, 10), cell_addr(11, 10), cell_addr(11, 11), cell_addr(10, 11)]
    for i, c in enumerate(celdas):
        s.buf[i] = c
        j.arena[c] = CELL_P_HEAD if i == 3 else CELL_P_BODY
    s.ptr, s.largo, s.dir = 3, 4, DIR_LEFT
    avanzar_un_paso(j, DIR_UP)                        # entra a (10,10), donde estaba la cola
    assert j.estado == ST_PLAY
    assert s.cabeza == cell_addr(10, 10)
    assert j.arena[cell_addr(10, 10)] == CELL_P_HEAD
    assert j.contar(CELL_P_BODY) == 3


def test_jugador_muere_contra_un_bot():
    j = juego_sin_bots()
    j.arena[vecino(j.jugador.cabeza, DIR_RIGHT)] = CELL_B0_BODY
    avanzar_un_paso(j, DIR_RIGHT)
    assert j.estado == ST_DEAD


def test_bot_contra_el_jugador_se_vuelve_comida():
    j = Juego(semilla=0x1234)
    j.paso(DIR_RIGHT, start=True)
    bot = j.serpientes[1]
    largo = bot.largo
    j.arena[vecino(bot.cabeza, bot.dir)] = CELL_P_BODY
    comida_antes = j.comida
    for _ in range(BOT_MOVE_FRAMES):
        j.paso(DIR_RIGHT, bot_turn=QUIETOS)
    assert not bot.viva and j.estado == ST_PLAY
    assert j.contar(CELL_B0_HEAD) == 0 and j.contar(CELL_B0_BODY) == 0
    if BOT_MUERTO_A_COMIDA:
        assert j.comida >= comida_antes + largo


def test_bot_reaparece():
    j = Juego(semilla=0x1234)
    j.paso(DIR_RIGHT, start=True)
    bot = j.serpientes[1]
    j.morir(bot)
    for _ in range(FRAMES_REAPARECER + 1):
        j.paso(DIR_UP, bot_turn=QUIETOS)
        if j.estado != ST_PLAY:
            break
    assert bot.viva or j.estado != ST_PLAY


def test_input_ctrl():
    assert dir_desde_botones(0b00000, DIR_LEFT) == DIR_LEFT
    assert dir_desde_botones(0b00001, DIR_LEFT) == DIR_UP
    assert dir_desde_botones(0b01000, DIR_UP) == DIR_RIGHT
    assert dir_desde_inclinacion(100, -50, DIR_UP) == DIR_UP           # zona muerta
    assert dir_desde_inclinacion(600, 300, DIR_UP) == DIR_RIGHT
    assert dir_desde_inclinacion(-200, -700, DIR_RIGHT) == DIR_UP


def test_bot_ai_gira_si_esta_bloqueado():
    ai = BotAI()
    for rnd in range(0, 65536, 97):
        giros = ai.decidir([1] * N_BOTS, rnd)
        assert all(g in (GIRO_DER, GIRO_IZQ) for g in giros)


def test_invariantes_en_partidas_largas():
    """Con entradas al azar, la arena siempre coincide con los búferes de las
    serpientes, la cuenta de comida es correcta y cada cuadro cabe en el
    borrado vertical."""
    presupuesto = 200       # accesos por cuadro; el borrado da ~47,000 ciclos
    for semilla in (0x1, 0xBEEF, 0x7777):
        j = Juego(semilla)
        l = LFSR16(semilla ^ 0x5A5A)
        partidas = 0
        for _ in range(5000):
            r = l.siguiente()
            empezo = j.estado != ST_PLAY
            j.paso(r & 3, start=(r >> 2) & 1 == 1)
            if empezo and j.estado == ST_PLAY:
                partidas += 1
                continue                    # limpiar la arena son 8192 accesos, en ST_START
            if j.estado == ST_PLAY:
                assert j.accesos <= presupuesto, j.accesos
            assert j.contar(CELL_FOOD) == j.comida
            for s in j.serpientes:
                if not s.viva:
                    if s.indice > 0:
                        assert j.contar(s.cabeza_cod) == 0 and j.contar(s.cuerpo_cod) == 0
                    continue
                assert j.arena[s.cabeza] == s.cabeza_cod
                assert j.contar(s.cabeza_cod) == 1
                assert j.contar(s.cuerpo_cod) == s.largo - 1
                for i in range(1, s.largo):
                    assert j.arena[s.celda(i)] == s.cuerpo_cod
                    # Cada segmento está junto al siguiente.
                    assert any(vecino(s.celda(i), d) == s.celda(i - 1) for d in range(4))
        assert partidas > 3


if __name__ == "__main__":
    pruebas = [(n, f) for n, f in sorted(globals().items()) if n.startswith("test_")]
    for nombre, f in pruebas:
        f()
        print("ok ", nombre)
    print(f"{len(pruebas)} pruebas pasaron.")
