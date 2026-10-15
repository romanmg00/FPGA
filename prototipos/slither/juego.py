"""
Lógica de Slither.io, separada del dibujo y de la entrada.

Es el modelo de referencia de los módulos del contrato de interfaces:
- `arena` es arena_map: 8192 celdas de 4 bits, con dirección {cy, cx}.
- `Juego.paso()` es lo que hace snake_engine con cada pulso de tick_60hz.
- `BotAI` es bot_ai, `LFSR16` es lfsr, y `dir_desde_botones` /
  `dir_desde_inclinacion` son input_ctrl.
- Toda lectura o escritura de la arena pasa por `leer()` / `escribir()`, que
  las cuentan: así se puede comprobar que una actualización cabe en el borrado
  vertical.

Solo enteros, máscaras en lugar de módulos, y nada que no se pueda hacer con
una máquina de estados.
"""

from config import *

assert MAX_LEN & (MAX_LEN - 1) == 0, "MAX_LEN debe ser potencia de 2 (búfer circular)"
assert START_LEN >= 2


class LFSR16:
    """LFSR de Galois de 16 bits, polinomio x^16 + x^14 + x^13 + x^11 + 1.

    Avanza una vez por tick_60hz. Así `rnd` es el mismo durante toda la
    actualización de un cuadro y el hardware puede dar exactamente lo mismo
    que este modelo.
    """

    def __init__(self, semilla=0xACE1):
        self.estado = (semilla & 0xFFFF) or 1

    def siguiente(self):
        lsb = self.estado & 1
        self.estado >>= 1
        if lsb:
            self.estado ^= 0xB400
        return self.estado


# ----------------------------------------------------------------------
# Cuadrícula
# ----------------------------------------------------------------------
def cell_addr(cx, cy):
    return (cy << CX_W) | cx


def cx_de(addr):
    return addr & ((1 << CX_W) - 1)


def cy_de(addr):
    return addr >> CX_W


def vecino(addr, d):
    """Celda de al lado. Las restas dan la vuelta con máscara, como en hardware
    (cx = 0 menos 1 da 127); las paredes del borde impiden llegar ahí."""
    cx, cy = cx_de(addr), cy_de(addr)
    if d == DIR_UP:
        cy = (cy - 1) & ((1 << CY_W) - 1)
    elif d == DIR_DOWN:
        cy = (cy + 1) & ((1 << CY_W) - 1)
    elif d == DIR_LEFT:
        cx = (cx - 1) & ((1 << CX_W) - 1)
    else:
        cx = (cx + 1) & ((1 << CX_W) - 1)
    return cell_addr(cx, cy)


def es_borde(cx, cy):
    return cx == 0 or cx == GRID_W - 1 or cy == 0 or cy == GRID_H - 1


# ----------------------------------------------------------------------
# input_ctrl
# ----------------------------------------------------------------------
def dir_desde_botones(btn, actual):
    """btn: 5 bits ([0] arriba, [1] abajo, [2] izquierda, [3] derecha).
    La dirección se queda guardada hasta que se presione otro botón."""
    for bit, d in ((0, DIR_UP), (1, DIR_DOWN), (2, DIR_LEFT), (3, DIR_RIGHT)):
        if (btn >> bit) & 1:
            return d
    return actual


def dir_desde_inclinacion(tx, ty, actual):
    """Gana el eje más inclinado, si pasa la zona muerta."""
    ax, ay = abs(tx), abs(ty)
    if ax < TILT_ZONA_MUERTA and ay < TILT_ZONA_MUERTA:
        return actual
    if ax >= ay:
        return DIR_RIGHT if tx > 0 else DIR_LEFT
    return DIR_DOWN if ty > 0 else DIR_UP


# ----------------------------------------------------------------------
# bot_ai
# ----------------------------------------------------------------------
GIRO_NADA = 0
GIRO_DER = 1
GIRO_IZQ = 3      # sumar 3 (mod 4) = girar a la izquierda


class BotAI:
    """Decide el giro de cada bot con cada tick.

    El bot i usa los bits [8+4i+3 : 8+4i] de rnd: gira si tiene algo enfrente
    o, al azar, 1 de cada 8 veces. bit 0 elige derecha o izquierda.
    """

    def decidir(self, ahead_blocked, rnd):
        giros = []
        for i in range(N_BOTS):
            n = (rnd >> (8 + 4 * i)) & 0xF
            if ahead_blocked[i] or (n >> 1) == 0:
                giros.append(GIRO_DER if n & 1 else GIRO_IZQ)
            else:
                giros.append(GIRO_NADA)
        return giros


# ----------------------------------------------------------------------
# snake_engine
# ----------------------------------------------------------------------
class Serpiente:
    """Búfer circular de MAX_LEN celdas; `ptr` apunta a la cabeza."""

    def __init__(self, indice):
        self.indice = indice            # 0 = jugador, 1.. = bots
        self.cabeza_cod = (CELL_P_HEAD, CELL_B0_HEAD, CELL_B1_HEAD)[indice]
        self.cuerpo_cod = self.cabeza_cod + 1
        self.buf = [0] * MAX_LEN
        self.ptr = 0
        self.largo = 0
        self.dir = DIR_RIGHT
        self.viva = False
        self.contador = 0
        self.reaparecer = 0

    def celda(self, i):
        """i = 0 es la cabeza, i = largo - 1 es la cola."""
        return self.buf[(self.ptr - i) & (MAX_LEN - 1)]

    @property
    def cabeza(self):
        return self.celda(0)

    @property
    def cola(self):
        return self.celda(self.largo - 1)


class Juego:
    def __init__(self, semilla=0xACE1):
        self.lfsr = LFSR16(semilla)
        self.bot_ai = BotAI()
        self.arena = [CELL_EMPTY] * MAP_SIZE
        self.estado = ST_START
        self.score = 0
        self.record = 0
        self.comida = 0
        self.velocidad = VEL_INICIAL
        self.serpientes = [Serpiente(i) for i in range(1 + N_BOTS)]
        self.bot_ahead_blocked = [0] * N_BOTS
        self.rnd = self.lfsr.estado
        self.accesos = 0                # lecturas + escrituras en el último paso
        self.frame = 0

    # --- acceso a arena_map (puerto A) ---
    def leer(self, addr):
        self.accesos += 1
        return self.arena[addr]

    def escribir(self, addr, valor):
        self.accesos += 1
        self.arena[addr] = valor

    # --- salidas del módulo ---
    @property
    def jugador(self):
        return self.serpientes[0]

    @property
    def player_len(self):
        return self.jugador.largo

    @property
    def bot_head(self):
        return [s.cabeza if s.viva else 0 for s in self.serpientes[1:]]

    def periodo(self, s):
        return MOVE_FRAMES_POR_VEL[self.velocidad] if s.indice == 0 else BOT_MOVE_FRAMES

    # --- partida ---
    def limpiar_arena(self):
        """8192 escrituras: en hardware tarda ~0.1 ms y ocurre en ST_START."""
        for addr in range(MAP_SIZE):
            cx, cy = cx_de(addr), cy_de(addr)
            dentro = cx < GRID_W and cy < GRID_H
            self.escribir(addr, CELL_WALL if dentro and es_borde(cx, cy) else CELL_EMPTY)

    def colocar(self, s, cx, cy, d):
        """Pone a la serpiente con la cabeza en (cx, cy) y el cuerpo detrás.
        Puede salir encima de comida (se la come sin crecer), pero si alguna
        celda tiene pared u otra serpiente, no la pone y devuelve False."""
        atras = d ^ 2
        celdas = [cell_addr(cx, cy)]
        for _ in range(START_LEN - 1):
            celdas.append(vecino(celdas[-1], atras))
        contenido = [self.leer(c) for c in celdas]
        if any(v not in (CELL_EMPTY, CELL_FOOD) for v in contenido):
            return False
        self.comida -= contenido.count(CELL_FOOD)
        for i, c in enumerate(reversed(celdas)):        # de la cola a la cabeza
            s.buf[i] = c
            self.escribir(c, s.cabeza_cod if i == START_LEN - 1 else s.cuerpo_cod)
        s.ptr = START_LEN - 1
        s.largo = START_LEN
        s.dir = d
        s.viva = True
        s.contador = self.periodo(s)
        s.reaparecer = 0
        return True

    def nueva_partida(self):
        self.limpiar_arena()
        self.score = 0
        self.comida = 0
        self.colocar(self.jugador, *SALIDA_JUGADOR)
        for s, salida in zip(self.serpientes[1:], SALIDA_BOTS):
            self.colocar(s, *salida)
        self.estado = ST_PLAY

    # --- un cuadro ---
    def paso(self, player_dir, start=False, velocidad=None, bot_turn=None):
        """Un pulso de tick_60hz.

        player_dir: salida de input_ctrl (se queda guardada entre cuadros).
        bot_turn: giros de bot_ai; si es None se calculan aquí con BotAI.
        """
        self.frame += 1
        self.accesos = 0
        self.rnd = self.lfsr.siguiente()
        if velocidad is not None:
            self.velocidad = velocidad

        if self.estado != ST_PLAY:
            if start:
                self.nueva_partida()
            return

        if bot_turn is None:
            bot_turn = self.bot_ai.decidir(self.bot_ahead_blocked, self.rnd)

        for s in self.serpientes:
            if not s.viva:
                if s.indice > 0:
                    self.intentar_reaparecer(s)
                continue
            s.contador -= 1
            if s.contador == 0:
                s.contador = self.periodo(s)
                if s.indice == 0:
                    # Un giro de 180° se ignora: chocaría con su propio cuello.
                    if player_dir != s.dir ^ 2:
                        s.dir = player_dir
                else:
                    s.dir = (s.dir + bot_turn[s.indice - 1]) & 3
                self.mover(s)
            if self.estado == ST_DEAD:
                return

        self.reponer_comida()
        self.calcular_bloqueos()

    def mover(self, s):
        nueva = vecino(s.cabeza, s.dir)
        c = self.leer(nueva)
        cola = s.cola
        crece = False
        if c == CELL_FOOD:
            self.comida -= 1
            crece = s.largo < MAX_LEN
            if s.indice == 0:
                self.score = min(self.score + 1, SCORE_MAX)
        elif c != CELL_EMPTY and nueva != cola:
            # Pared, cuerpo o cabeza: muere. Entrar a la celda que deja la
            # propia cola en este mismo paso sí se vale.
            self.morir(s)
            return
        if not crece:
            self.escribir(cola, CELL_EMPTY)
        self.escribir(s.cabeza, s.cuerpo_cod)
        self.escribir(nueva, s.cabeza_cod)
        s.ptr = (s.ptr + 1) & (MAX_LEN - 1)
        s.buf[s.ptr] = nueva
        if crece:
            s.largo += 1

    def morir(self, s):
        s.viva = False
        if s.indice == 0:
            self.estado = ST_DEAD
            self.record = max(self.record, self.score)
            return
        # Bot: su cuerpo se vuelve comida (o se borra) y reaparece más tarde.
        resto = CELL_FOOD if BOT_MUERTO_A_COMIDA else CELL_EMPTY
        for i in range(s.largo):
            self.escribir(s.celda(i), resto)
        if BOT_MUERTO_A_COMIDA:
            self.comida += s.largo
        s.largo = 0
        s.reaparecer = FRAMES_REAPARECER

    def intentar_reaparecer(self, s):
        s.reaparecer -= 1
        if s.reaparecer <= 0 and not self.colocar(s, *SALIDA_BOTS[s.indice - 1]):
            s.reaparecer = 1                # ocupado: se intenta en el siguiente cuadro

    def reponer_comida(self):
        """Un intento por cuadro: la celda sale de rnd[12:0]; si cae en la
        pared, fuera de la arena u ocupada, se intenta en el siguiente cuadro."""
        if self.comida >= N_FOOD:
            return
        cx = self.rnd & ((1 << CX_W) - 1)
        cy = (self.rnd >> CX_W) & ((1 << CY_W) - 1)
        if 1 <= cx <= GRID_W - 2 and 1 <= cy <= GRID_H - 2:
            addr = cell_addr(cx, cy)
            if self.leer(addr) == CELL_EMPTY:
                self.escribir(addr, CELL_FOOD)
                self.comida += 1

    def calcular_bloqueos(self):
        for i, s in enumerate(self.serpientes[1:]):
            if s.viva:
                c = self.leer(vecino(s.cabeza, s.dir))
                self.bot_ahead_blocked[i] = int(c not in (CELL_EMPTY, CELL_FOOD))
            else:
                self.bot_ahead_blocked[i] = 0

    # --- para pruebas y testbenches ---
    def contar(self, codigo):
        return sum(1 for v in self.arena if v == codigo)

    def arena_hex(self):
        """Contenido de la arena, una celda por línea en hex (formato $readmemh)."""
        return [f"{v:x}" for v in self.arena]
