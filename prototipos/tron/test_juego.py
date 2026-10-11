"""
Pruebas de la lógica (sin pygame).  Ejecutar:  python3 test_juego.py

Son también la lista de casos que deben cubrir los testbenches del motor, de
los menús y del módulo de teclado.
"""

from config import *
from juego import (LFSR16, Juego, BotTron, TecladoPS2, Config, bytes_ps2, digitos_display,
                   rotar_sprite, cell_addr, cx_de, cy_de, vecino)

SAL = [s[2] for s in SALIDAS]          # dirección de salida de cada jugador
U, D, L, R, BTNC = (1 << b for b in (BTN_U, BTN_D, BTN_L, BTN_R, BTN_C))


def ronda_en_juego(semilla=0x1234, sw=0b01, **opciones):
    """Partida empezada desde el menú y ya en ST_PLAY. sw = 0b01: velocidad
    normal. `opciones` elige valores de la configuración (vidas=..., largo=...)."""
    j = Juego(semilla)
    for clave, valor in opciones.items():
        j.setup.poner(clave, valor)
    j.paso(SAL, BTNC, sw)                       # menú principal: "Jugar"
    while j.estado == ST_READY:
        j.paso(SAL)
    assert j.estado == ST_PLAY
    sin_rayo(j)
    return j


def sin_rayo(j):
    """Quita el rayo y lo pausa mucho tiempo, para que no estorbe en una prueba."""
    if j.rayo is not None:
        for c in j.celdas_rayo(j.rayo):
            j.arena[c] = CELL_EMPTY
        j.rayo = None
    j.espera_rayo = 10 ** 6


def poner_rayo_en(j, cx, cy):
    for c in j.celdas_rayo(cell_addr(cx, cy)):
        j.arena[c] = CELL_RAYO
    j.rayo = cell_addr(cx, cy)


def un_paso(j, dirs=SAL):
    """Corre cuadros hasta que las motos avanzan una celda."""
    for _ in range(j.setup.periodo):
        j.paso(dirs)


def con(cambios):
    d = list(SAL)
    for i, v in cambios.items():
        d[i] = v
    return d


def mover_cabeza(j, i, cx, cy, d):
    """Pone la moto i en (cx, cy) con dirección d y estela de 1 celda."""
    m = j.motos[i]
    for k in range(m.largo):
        j.arena[m.buf[(m.ptr - k) & (MAX_LARGO - 1)]] = CELL_EMPTY
    m.ptr, m.largo, m.dir = 0, 1, d
    m.buf[0] = m.prev = cell_addr(cx, cy)
    j.arena[m.cabeza] = m.cabeza_cod


def teclear(t, tecla, soltada=False):
    for b in bytes_ps2(tecla, soltada):
        t.recibir(b)


# --- cuadrícula ---
def test_lfsr_periodo_maximo():
    l = LFSR16(1)
    assert len({l.siguiente() for _ in range(65535)}) == 65535


def test_direccion_de_celda():
    assert cell_addr(79, 49) == (49 << 7) | 79
    assert (cx_de(cell_addr(37, 21)), cy_de(cell_addr(37, 21))) == (37, 21)
    assert vecino(cell_addr(0, 5), DIR_LEFT) == cell_addr(127, 5)


def test_arena_limpia():
    j = Juego()
    j.limpiar_arena()
    assert j.contar(CELL_WALL) == 2 * GRID_W + 2 * (GRID_H - HUD_ROWS - 2)
    assert j.arena[cell_addr(5, HUD_ROWS - 1)] == CELL_EMPTY   # franja del marcador
    assert j.arena[cell_addr(GRID_W, 5)] == CELL_EMPTY         # fuera de la arena


# --- teclado PS/2 ---
def test_ps2_bytes():
    assert bytes_ps2((0, 0x1D)) == [0x1D]
    assert bytes_ps2((0, 0x1D), soltada=True) == [0xF0, 0x1D]
    assert bytes_ps2((1, 0x75)) == [0xE0, 0x75]
    assert bytes_ps2((1, 0x75), soltada=True) == [0xE0, 0xF0, 0x75]


def test_ps2_cada_jugador_su_direccion():
    t = TecladoPS2()
    teclear(t, (0, 0x1B))                       # S -> P1 abajo
    teclear(t, (1, 0x6B))                       # flecha izquierda -> P2 izquierda
    assert t.dirs == [DIR_DOWN, DIR_LEFT]


def test_ps2_soltar_no_cambia_la_direccion():
    t = TecladoPS2()
    teclear(t, (0, 0x1D))
    teclear(t, (0, 0x1D), soltada=True)
    teclear(t, (1, 0x75), soltada=True)
    assert t.dirs == [DIR_UP, SAL[1]]


def test_ps2_teclas_a_la_vez():
    t = TecladoPS2()
    teclear(t, (0, 0x23))                       # P1 mantiene D
    teclear(t, (1, 0x72))                       # P2 presiona abajo
    teclear(t, (0, 0x1B))                       # P1 cambia a S sin soltar D
    teclear(t, (0, 0x23), soltada=True)
    assert t.dirs == [DIR_DOWN, DIR_DOWN]


def test_ps2_flecha_no_es_la_tecla_normal():
    """0x75 sin E0 es el 8 del teclado numérico, no la flecha arriba."""
    t = TecladoPS2()
    teclear(t, (0, 0x75))
    assert t.dirs == SAL


# --- menús ---
def test_menu_principal():
    j = Juego()
    assert j.estado == ST_MENU and j.menu_sel == OP_JUGAR
    j.paso(SAL, D)
    j.paso(SAL, BTNC)
    assert j.estado == ST_CONFIG
    j.paso(SAL, BTNC)
    assert j.estado == ST_MENU and j.menu_sel == OP_CONFIG
    j.paso(SAL, D)
    j.paso(SAL, BTNC)
    assert j.estado == ST_AYUDA
    j.paso(SAL, BTNC)
    j.paso(SAL, D)                              # da la vuelta: de "Cómo jugar" a "Jugar"
    assert j.menu_sel == OP_JUGAR
    j.paso(SAL, BTNC)
    assert j.estado == ST_READY


def test_configuracion():
    c = Config()
    assert c["vidas"] == 3 and c["largo"] == 0
    c.boton(R)
    assert c["vidas"] == 4
    for _ in range(20):
        c.boton(R)
    assert c["vidas"] == 9                      # tope
    c.boton(D)                                  # baja a "meta"
    c.boton(L)
    assert c["meta"] == 15
    c.boton(U)
    c.boton(U)                                  # da la vuelta: queda en "largo"
    assert CONFIG[c.sel][0] == "largo"
    c.boton(R)
    assert c.largo == 64
    c.boton(R)
    c.boton(R)
    c.boton(R)
    assert c.largo == 16                        # tope


def test_cambiar_largo_desde_el_menu():
    """Menú principal -> Configuración -> bajar hasta "Largo" -> derecha."""
    j = Juego()
    j.paso(SAL, D)
    j.paso(SAL, BTNC)
    j.paso(SAL, U)                              # de "Vidas" sube (da la vuelta) a "Largo"
    j.paso(SAL, R)
    j.paso(SAL, R)
    assert j.setup.largo == 32
    j.paso(SAL, BTNC)
    j.paso(SAL, U)
    j.paso(SAL, BTNC)                           # "Jugar"
    assert j.estado == ST_READY and j.setup.largo == 32


def test_velocidad_con_switches_en_cualquier_momento():
    j = ronda_en_juego(sw=0b00)
    assert j.setup.periodo == MOVE_FRAMES_POR_SW[0]
    j.paso(SAL, 0, 0b11)
    assert j.setup.periodo == MOVE_FRAMES_POR_SW[3]
    assert 0 < j.mov <= j.setup.periodo


def test_botones_no_cambian_la_config_jugando():
    j = ronda_en_juego()
    j.paso(SAL, R)
    assert j.setup["vidas"] == 3


# --- display y sprites ---
def test_display():
    assert digitos_display([3, 1], [7, 12]) == [3, None, 0, 7, 1, None, 1, 2]


def test_rotar_sprite():
    """El frente de la moto (fila 0 de la ROM) queda del lado hacia donde va."""
    m = SPRITE - 1
    frente = {(x, 0) for x in range(SPRITE)}
    lado = {
        DIR_UP: {(x, 0) for x in range(SPRITE)},
        DIR_RIGHT: {(m, y) for y in range(SPRITE)},
        DIR_DOWN: {(x, m) for x in range(SPRITE)},
        DIR_LEFT: {(0, y) for y in range(SPRITE)},
    }
    for d, pixeles in lado.items():
        assert {rotar_sprite(x, y, d) for x, y in pixeles} == frente
        assert len({rotar_sprite(x, y, d) for x in range(SPRITE) for y in range(SPRITE)}) == SPRITE ** 2


def test_sprite_se_desliza_y_esta_centrado():
    j = ronda_en_juego()
    un_paso(j)
    m = j.motos[0]
    centro = (SPRITE_PX - TILE) // 2
    x0 = cx_de(m.prev) * TILE - centro
    assert j.pos_sprite(m)[0] == x0                         # recién movida: en la celda anterior
    for k in range(1, j.setup.periodo):
        j.paso(SAL)
        assert j.pos_sprite(m)[0] == x0 + TILE * k // j.setup.periodo
    j.paso(SAL)                                             # llega y da el siguiente paso
    assert j.pos_sprite(m)[0] == x0 + TILE


def test_fuente_tiene_todas_las_letras():
    """Todas las letras de los textos que salen en pantalla existen en la ROM."""
    from fuente import FUENTE
    textos = list(MENU_PRINCIPAL) + [c[1] for c in CONFIG] + list(NOMBRE_VEL)
    textos += [t[0] for t in TEMAS_MOTO] + [f[0] for f in FONDOS]
    textos += ["0123456789 :.,-+<>()[]/!¡?=", "ÁÉÍÓÚÑ", "INFINITA CELDAS"]
    for t in textos:
        for ch in t.upper():
            assert ch in FUENTE, (t, ch)
    for ch, filas in FUENTE.items():
        assert len(filas) == 8 and all(len(f) == 8 for f in filas), ch


def test_switches_de_estetica():
    j = ronda_en_juego(sw=0b100101)
    assert j.setup.periodo == MOVE_FRAMES_POR_SW[1]
    assert j.setup.tema == 1 and j.setup.fondo == 2
    j.paso(SAL, 0, 0b011101)                        # se pueden cambiar jugando
    assert j.setup.tema == 3 and j.setup.fondo == 1


# --- partida ---
def test_inicio():
    j = Juego()
    j.setup.poner("vidas", 5)
    j.paso(SAL, BTNC)
    assert j.estado == ST_READY and j.vidas == [5, 5] and j.puntos == [0, 0]
    assert j.contar(CELL_P1_HEAD) == 1 and j.contar(CELL_P2_HEAD) == 1


def test_avanza_una_celda_por_periodo():
    j = ronda_en_juego()
    c = j.motos[0].cabeza
    for _ in range(j.setup.periodo - 1):
        j.paso(SAL)
    assert j.motos[0].cabeza == c
    j.paso(SAL)
    assert j.motos[0].cabeza == vecino(c, DIR_RIGHT)
    assert j.arena[c] == CELL_P1_TRAIL


def test_estela_infinita():
    j = ronda_en_juego(largo=0)
    for _ in range(20):
        un_paso(j)
    assert j.contar(CELL_P1_TRAIL) == 20


def test_estela_de_largo_fijo():
    j = ronda_en_juego(largo=16)
    for _ in range(25):
        un_paso(j)
    assert j.contar(CELL_P1_TRAIL) == 15 and j.contar(CELL_P1_HEAD) == 1
    assert j.motos[0].largo == 16


def test_entrar_a_la_celda_que_deja_la_cola():
    """Con estela de 16 celdas, dar vueltas en un anillo de 16 celdas es
    válido: la cabeza entra a la celda que la cola libera en ese mismo paso."""
    j = ronda_en_juego(largo=16)
    mover_cabeza(j, 0, 10, 10, DIR_RIGHT)
    mover_cabeza(j, 1, 60, 40, DIR_LEFT)
    vuelta = [DIR_RIGHT] * 4 + [DIR_DOWN] * 4 + [DIR_LEFT] * 4 + [DIR_UP] * 4
    for d in vuelta * 3:
        un_paso(j, con({0: d}))
        assert j.estado == ST_PLAY, d
    assert j.motos[0].largo == 16 and j.contar(CELL_P1_TRAIL) == 15


def test_giro_de_180_se_ignora():
    j = ronda_en_juego()
    un_paso(j, [d ^ 2 for d in SAL])
    assert j.estado == ST_PLAY and [m.dir for m in j.motos] == SAL


def test_chocar_cuesta_una_vida():
    j = ronda_en_juego(vidas=3)
    mover_cabeza(j, 0, 1, 10, DIR_LEFT)
    un_paso(j, con({0: DIR_LEFT}))
    assert j.estado == ST_ROUND and j.perdio_ronda == [0]
    assert j.vidas == [2, 3]
    assert j.arena[cell_addr(0, 10)] == CELL_WALL
    assert j.arena[cell_addr(1, 10)] == CELL_CRASH
    for _ in range(FRAMES_ROUND):
        j.paso(SAL)
    assert j.estado == ST_READY and j.vidas == [2, 3]       # otra ronda


def test_frente_a_frente():
    for distancia in (2, 1):                                # misma celda / cruzándose
        j = ronda_en_juego()
        mover_cabeza(j, 0, 15, 10, DIR_RIGHT)
        mover_cabeza(j, 1, 15 + distancia, 10, DIR_LEFT)
        un_paso(j, con({0: DIR_RIGHT, 1: DIR_LEFT}))
        assert j.perdio_ronda == [0, 1] and j.vidas == [2, 2]


def test_orden_no_importa():
    j = ronda_en_juego()
    mover_cabeza(j, 0, 15, 10, DIR_RIGHT)
    mover_cabeza(j, 1, 16, 10, DIR_DOWN)
    un_paso(j, con({0: DIR_RIGHT, 1: DIR_DOWN}))
    assert j.perdio_ronda == [0]


def test_sin_vidas_pierde_y_vuelve_al_menu():
    j = ronda_en_juego(vidas=1)
    mover_cabeza(j, 1, GRID_W - 2, 10, DIR_RIGHT)
    un_paso(j, con({1: DIR_RIGHT}))
    for _ in range(FRAMES_ROUND):
        j.paso(SAL)
    assert j.estado == ST_MATCH and j.ganador == 1
    j.paso(SAL, BTNC)
    assert j.estado == ST_MENU


def test_los_dos_sin_vidas_gana_el_de_mas_puntos():
    j = ronda_en_juego(vidas=1)
    j.motos[1].puntos = 4
    mover_cabeza(j, 0, 15, 10, DIR_RIGHT)
    mover_cabeza(j, 1, 17, 10, DIR_LEFT)
    un_paso(j, con({0: DIR_RIGHT, 1: DIR_LEFT}))
    for _ in range(FRAMES_ROUND):
        j.paso(SAL)
    assert j.estado == ST_MATCH and j.ganador == 2


# --- rayo ---
def test_aparece_un_rayo():
    j = ronda_en_juego()
    j.espera_rayo = 0
    for _ in range(300):
        j.paso(SAL)
        if j.rayo is not None:
            break
    assert j.rayo is not None and j.contar(CELL_RAYO) == RAYO_CELDAS ** 2
    cx, cy = cx_de(j.rayo), cy_de(j.rayo)
    assert 1 <= cx <= GRID_W - 1 - RAYO_CELDAS and HUD_ROWS + 1 <= cy <= GRID_H - 1 - RAYO_CELDAS


def test_tomar_el_rayo():
    j = ronda_en_juego(valor_rayo=3, espera_rayo=2)
    cx, cy = cx_de(j.motos[0].cabeza), cy_de(j.motos[0].cabeza)
    poner_rayo_en(j, cx + 1, cy - 1)                        # P1 entra por la celda de abajo a la izquierda
    un_paso(j)
    assert j.puntos == [3, 0] and j.rayo is None
    assert j.contar(CELL_RAYO) == 0                         # se borra completo
    assert j.arena[j.motos[0].cabeza] == CELL_P1_HEAD
    # El siguiente sale después de la espera.
    for _ in range(2 * FPS - j.setup.periodo):
        j.paso(SAL)
    assert j.rayo is None
    for _ in range(300):
        j.paso(SAL)
        if j.rayo is not None:
            break
    assert j.rayo is not None


def test_dos_toman_el_rayo_a_la_vez():
    j = ronda_en_juego()
    mover_cabeza(j, 0, 19, 30, DIR_RIGHT)
    mover_cabeza(j, 1, 20 + RAYO_CELDAS, 30, DIR_LEFT)
    poner_rayo_en(j, 20, 30)
    un_paso(j, con({0: DIR_RIGHT, 1: DIR_LEFT}))
    assert j.puntos == [1, 1] and j.estado == ST_PLAY


def test_llegar_a_la_meta_gana():
    j = ronda_en_juego(meta=5, valor_rayo=1)
    j.motos[0].puntos = 4
    cx, cy = cx_de(j.motos[0].cabeza), cy_de(j.motos[0].cabeza)
    poner_rayo_en(j, cx + 1, cy)
    un_paso(j)
    assert j.estado == ST_MATCH and j.ganador == 1


def test_puntaje_se_satura():
    j = ronda_en_juego()
    j.motos[0].puntos = SCORE_MAX - 1
    j.motos[0].sumar(5)
    assert j.motos[0].puntos == SCORE_MAX


# --- partidas largas ---
def test_partidas_contra_el_bot():
    """Bot contra bot con todas las velocidades y largos de estela: la arena
    siempre coincide con las estelas y cada cuadro cabe en el borrado vertical."""
    bot = BotTron()
    rondas = 0
    for sw in range(4):
        for largo in (0, 64, 32, 16):
            j = Juego(0xBEEF ^ (sw * 7 + largo))
            j.setup.poner("largo", largo)
            for _ in range(2000):
                antes = j.estado
                dirs = [bot.decidir(j, m) if j.estado == ST_PLAY else SAL[m.indice] for m in j.motos]
                j.paso(dirs, BTNC if j.estado in (ST_MENU, ST_MATCH) else 0, sw)
                if j.estado == ST_PLAY:
                    assert j.accesos <= 8 + 3 * RAYO_CELDAS ** 2, j.accesos
                    for m in j.motos:
                        assert j.contar(m.cabeza_cod) == 1
                        if largo:
                            assert j.contar(m.estela) == m.largo - 1 and m.largo <= largo
                        else:
                            # Infinita: nunca se borra; `largo` solo cuenta hasta MAX_LARGO.
                            assert j.contar(m.estela) >= m.largo - 1
                    assert j.contar(CELL_RAYO) == (0 if j.rayo is None else RAYO_CELDAS ** 2)
                if antes == ST_PLAY and j.estado == ST_ROUND:
                    rondas += 1
    assert rondas >= 20, rondas


if __name__ == "__main__":
    pruebas = [(n, f) for n, f in sorted(globals().items()) if n.startswith("test_")]
    for nombre, f in pruebas:
        f()
        print("ok ", nombre)
    print(f"{len(pruebas)} pruebas pasaron.")
