"""
Lógica de Tron, separada del dibujo y de la entrada.

Es el modelo de referencia para el hardware:
- `arena` es arena_map: 2048 celdas de 4 bits, con dirección {cy, cx}.
- `Juego.paso()` es lo que hace el motor del juego con cada pulso de tick_60hz.
- `Juego.paso()` también lleva los menús (principal, configuración y ayuda),
  que se manejan con los botones de la tarjeta; `Config` guarda las opciones.
- `TecladoPS2` decodifica los bytes del teclado (Set 2) y guarda la dirección
  de cada jugador.
- `digitos_display` es lo que muestra el display de 7 segmentos.
- `rotar_sprite` y `Juego.pos_sprite` son lo que drawcon necesita para pintar
  la moto orientada y deslizándose entre celdas.
- `BotTron` es un rival automático para probar solo.
- Toda lectura o escritura de la arena pasa por `leer()` / `escribir()`, que
  las cuentan, para comprobar que un cuadro cabe en el borrado vertical.

Las dos motos se mueven **al mismo tiempo**, en este orden: se borran las
colas, se leen las celdas destino y al final se escribe. Así el resultado no
depende de cuál se procese primero.
"""

from config import *

assert MAX_LARGO & (MAX_LARGO - 1) == 0


class LFSR16:
    """LFSR de Galois de 16 bits, polinomio x^16 + x^14 + x^13 + x^11 + 1.
    Avanza una vez por tick_60hz: `rnd` es el mismo durante todo un cuadro."""

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
    """Celda de al lado; las restas dan la vuelta con máscara, como en hardware."""
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
    return cx == 0 or cx == GRID_W - 1 or cy == HUD_ROWS or cy == GRID_H - 1


# ----------------------------------------------------------------------
# Entrada de juego: teclado PS/2
# ----------------------------------------------------------------------
def bytes_ps2(tecla, soltada=False):
    """Bytes que manda el teclado al presionar o soltar una tecla (Set 2).
    Presionar: [E0] código.  Soltar: [E0] F0 código."""
    ext, codigo = tecla
    return ([PS2_EXT] if ext else []) + ([PS2_BREAK] if soltada else []) + [codigo]


class TecladoPS2:
    """Recibe bytes ya armados por el receptor PS/2 y guarda la última
    dirección pedida por cada jugador. Solo importa cuándo se presiona una
    tecla: soltarla no cambia nada, así que varias teclas a la vez no son
    problema."""

    def __init__(self):
        self.ext = 0
        self.soltar = 0
        self.dirs = [s[2] for s in SALIDAS]

    def recibir(self, byte):
        if byte == PS2_EXT:
            self.ext = 1
            return
        if byte == PS2_BREAK:
            self.soltar = 1
            return
        tecla = (self.ext, byte)
        if not self.soltar and tecla in TECLAS_DIR:
            jugador, d = TECLAS_DIR[tecla]
            self.dirs[jugador] = d
        self.ext = 0
        self.soltar = 0

    def reiniciar_dirs(self):
        """Al empezar una ronda, cada quien arranca hacia su dirección de salida."""
        self.dirs = [s[2] for s in SALIDAS]


# ----------------------------------------------------------------------
# Configuración: botones y switches de la tarjeta
# ----------------------------------------------------------------------
class Config:
    """Opciones de la partida. Cada una es un índice dentro de su tupla de
    opciones (en hardware: un registro chico y una tabla). `btn` son pulsos
    de 1 ciclo (ya con antirrebote y detector de flanco): BTNU/BTND eligen la
    opción y BTNL/BTNR cambian su valor. Los switches se leen directo:
    sw[1:0] velocidad, sw[3:2] colores de las motos, sw[5:4] fondo."""

    def __init__(self):
        self.sel = 0
        self.idx = {clave: inicial for clave, _, _, inicial in CONFIG}
        self.sw = 0

    def boton(self, btn):
        if (btn >> BTN_U) & 1:
            self.sel = (self.sel - 1) % len(CONFIG)
        if (btn >> BTN_D) & 1:
            self.sel = (self.sel + 1) % len(CONFIG)
        clave, _, opciones, _ = CONFIG[self.sel]
        if (btn >> BTN_L) & 1:
            self.idx[clave] = max(0, self.idx[clave] - 1)
        if (btn >> BTN_R) & 1:
            self.idx[clave] = min(len(opciones) - 1, self.idx[clave] + 1)

    def __getitem__(self, clave):
        opciones = next(o for c, _, o, _ in CONFIG if c == clave)
        return opciones[self.idx[clave]]

    def poner(self, clave, valor):
        """Para pruebas: elegir una opción por su valor."""
        opciones = next(o for c, _, o, _ in CONFIG if c == clave)
        self.idx[clave] = opciones.index(valor)

    @property
    def periodo(self):
        return MOVE_FRAMES_POR_SW[self.sw & 3]

    @property
    def largo(self):
        return self["largo"]

    @property
    def tema(self):
        """sw[3:2]: colores de las motos (solo los usa drawcon)."""
        return (self.sw >> 2) & 3

    @property
    def fondo(self):
        """sw[5:4]: fondo del mapa (solo lo usa drawcon)."""
        return (self.sw >> 4) & 3


# ----------------------------------------------------------------------
# Salidas: display de 7 segmentos y orientación de sprites
# ----------------------------------------------------------------------
def digitos_display(vidas, puntos):
    """Los 8 dígitos del display, de izquierda a derecha (None = apagado):
    P1 en los 4 de la izquierda y P2 en los 4 de la derecha, cada uno como
    [vidas] [apagado] [decenas] [unidades]."""
    d = []
    for v, p in zip(vidas, puntos):
        d += [v, None, p // 10, p % 10]
    return d


def rotar_sprite(sx, sy, d):
    """Píxel (sx, sy) de la moto ya orientada -> píxel de la ROM, que la
    guarda mirando hacia arriba. En hardware: intercambiar sx/sy e invertir
    bits (15 - s = ~s en 4 bits); nada de multiplicadores."""
    m = SPRITE - 1
    if d == DIR_UP:
        return sx, sy
    if d == DIR_RIGHT:
        return sy, m - sx
    if d == DIR_DOWN:
        return m - sx, m - sy
    return m - sy, sx


# ----------------------------------------------------------------------
# Motor del juego
# ----------------------------------------------------------------------
class Moto:
    """La estela es un búfer circular de MAX_LARGO celdas; `ptr` apunta a la
    cabeza. Con largo fijo, la celda más vieja se borra al avanzar."""

    def __init__(self, indice):
        self.indice = indice                    # 0 = P1, 1 = P2
        self.estela = CELL_P1_TRAIL + 2 * indice
        self.cabeza_cod = self.estela + 1
        self.salida = SALIDAS[indice]
        self.buf = [0] * MAX_LARGO
        self.ptr = 0
        self.largo = 0                          # celdas ocupadas, contando la cabeza
        self.prev = 0                           # celda anterior (para deslizar el sprite)
        self.dir = DIR_RIGHT
        self.viva = True
        self.vidas = 0
        self.puntos = 0

    @property
    def cabeza(self):
        return self.buf[self.ptr]

    @property
    def cola(self):
        return self.buf[(self.ptr - self.largo + 1) & (MAX_LARGO - 1)]

    def colocar(self):
        cx, cy, d = self.salida
        self.ptr = 0
        self.buf[0] = self.prev = cell_addr(cx, cy)
        self.largo = 1
        self.dir = d
        self.viva = True

    def sumar(self, puntos):
        self.puntos = min(self.puntos + puntos, SCORE_MAX)


class Juego:
    def __init__(self, semilla=0xACE1):
        self.lfsr = LFSR16(semilla)
        self.setup = Config()
        self.arena = [CELL_EMPTY] * MAP_SIZE
        self.motos = [Moto(0), Moto(1)]
        self.estado = ST_MENU
        self.menu_sel = 0                       # opción elegida del menú principal
        self.perdio_ronda = []                  # quiénes chocaron en la última ronda
        self.ganador = EMPATE                   # de la partida
        self.rayo = None                        # esquina de arriba a la izquierda del rayo, o None
        self.espera_rayo = 0                    # cuadros que faltan para que salga otro
        self.contador = 0                       # cuadros que faltan en READY o ROUND
        self.mov = 0                            # cuadros que faltan para el próximo paso
        self.rnd = self.lfsr.estado
        self.accesos = 0
        self.frame = 0

    @property
    def vidas(self):
        return [m.vidas for m in self.motos]

    @property
    def puntos(self):
        return [m.puntos for m in self.motos]

    # --- acceso a arena_map ---
    def leer(self, addr):
        self.accesos += 1
        return self.arena[addr]

    def escribir(self, addr, valor):
        self.accesos += 1
        self.arena[addr] = valor

    # --- partida y rondas ---
    def limpiar_arena(self):
        """8192 escrituras (~0.1 ms a 83.5 MHz); ocurre al empezar cada ronda."""
        for addr in range(MAP_SIZE):
            cx, cy = cx_de(addr), cy_de(addr)
            dentro = cx < GRID_W and HUD_ROWS <= cy < GRID_H
            self.escribir(addr, CELL_WALL if dentro and es_borde(cx, cy) else CELL_EMPTY)

    def nueva_partida(self):
        for m in self.motos:
            m.vidas = self.setup["vidas"]
            m.puntos = 0
        self.ganador = EMPATE
        self.nueva_ronda()

    def nueva_ronda(self):
        self.limpiar_arena()
        for m in self.motos:
            m.colocar()
            self.escribir(m.cabeza, m.cabeza_cod)
        self.rayo = None
        self.espera_rayo = 0
        self.perdio_ronda = []
        self.estado = ST_READY
        self.contador = FRAMES_READY

    def terminar(self, ganador):
        self.ganador = ganador
        self.estado = ST_MATCH

    # --- un cuadro ---
    def paso(self, dirs, btn=0, sw=None):
        """Un pulso de tick_60hz.

        dirs: dirección guardada de cada jugador (salida del módulo de teclado).
        btn: pulsos de los botones de la tarjeta en este cuadro.
        sw: switches; sw[1:0] es la velocidad y cuenta en todo momento.
        """
        self.frame += 1
        self.accesos = 0
        self.rnd = self.lfsr.siguiente()
        if sw is not None:
            self.setup.sw = sw
        arriba, abajo, centro = (btn >> BTN_U) & 1, (btn >> BTN_D) & 1, (btn >> BTN_C) & 1

        if self.estado == ST_MENU:
            if arriba:
                self.menu_sel = (self.menu_sel - 1) % len(MENU_PRINCIPAL)
            if abajo:
                self.menu_sel = (self.menu_sel + 1) % len(MENU_PRINCIPAL)
            if centro:
                if self.menu_sel == OP_JUGAR:
                    self.nueva_partida()
                elif self.menu_sel == OP_CONFIG:
                    self.estado = ST_CONFIG
                else:
                    self.estado = ST_AYUDA
        elif self.estado == ST_CONFIG:
            self.setup.boton(btn)
            if centro:
                self.estado = ST_MENU
        elif self.estado == ST_AYUDA:
            if centro:
                self.estado = ST_MENU
        elif self.estado == ST_READY:
            # Durante la cuenta ya se puede elegir hacia dónde arrancar (menos hacia atrás).
            for m, d in zip(self.motos, dirs):
                if d != m.salida[2] ^ 2:
                    m.dir = d
            self.contador -= 1
            if self.contador == 0:
                self.estado = ST_PLAY
                self.mov = self.setup.periodo
        elif self.estado == ST_PLAY:
            # Si con los switches se sube la velocidad a medio paso, se recorta la espera.
            self.mov = min(self.mov, self.setup.periodo) - 1
            if self.mov == 0:
                self.mov = self.setup.periodo
                self.mover(dirs)
            if self.estado == ST_PLAY and self.rayo is None:
                if self.espera_rayo > 0:
                    self.espera_rayo -= 1
                else:
                    self.poner_rayo()
        elif self.estado == ST_ROUND:
            self.contador -= 1
            if self.contador == 0:
                self.fin_de_ronda()
        elif self.estado == ST_MATCH:
            if centro:
                self.estado = ST_MENU

    def celdas_rayo(self, esquina):
        """Las RAYO_CELDAS x RAYO_CELDAS celdas del rayo, fila por fila."""
        cx, cy = cx_de(esquina), cy_de(esquina)
        return [cell_addr(cx + i, cy + k) for k in range(RAYO_CELDAS) for i in range(RAYO_CELDAS)]

    def poner_rayo(self):
        """Un intento por cuadro: la esquina sale de rnd (cx = rnd[6:0],
        cy = rnd[12:7]). Si cae en la pared, fuera de la arena o encima de
        algo, se intenta en el siguiente cuadro."""
        cx = self.rnd & ((1 << CX_W) - 1)
        cy = (self.rnd >> CX_W) & ((1 << CY_W) - 1)
        if not (1 <= cx <= GRID_W - 1 - RAYO_CELDAS and HUD_ROWS + 1 <= cy <= GRID_H - 1 - RAYO_CELDAS):
            return
        celdas = self.celdas_rayo(cell_addr(cx, cy))
        if any(self.leer(c) != CELL_EMPTY for c in celdas):
            return
        for c in celdas:
            self.escribir(c, CELL_RAYO)
        self.rayo = celdas[0]

    def mover(self, dirs):
        motos = self.motos
        largo_max = self.setup.largo
        # 1. Direcciones: un giro de 180° se ignora.
        for m in motos:
            if dirs[m.indice] != m.dir ^ 2:
                m.dir = dirs[m.indice]
        # 2. Con estela de largo fijo, la celda más vieja se borra primero:
        #    así se puede entrar a la celda que se libera en este mismo paso.
        for m in motos:
            if largo_max and m.largo == largo_max:
                self.escribir(m.cola, CELL_EMPTY)
                m.largo -= 1
        # 3. Leer las dos celdas destino ANTES de escribir nada.
        destino = [vecino(m.cabeza, m.dir) for m in motos]
        contenido = [self.leer(n) for n in destino]
        mismo_lugar = destino[0] == destino[1]
        sobrevive = [c in (CELL_EMPTY, CELL_RAYO) and not mismo_lugar for c in contenido]
        # 4. Rayo: si alguien lo toma, se suma y empieza la espera del siguiente.
        tomo = [s and c == CELL_RAYO for s, c in zip(sobrevive, contenido)]
        if any(tomo):
            for c in self.celdas_rayo(self.rayo):
                self.escribir(c, CELL_EMPTY)
            self.rayo = None
            self.espera_rayo = self.setup["espera_rayo"] * FPS
            for m, t in zip(motos, tomo):
                if t:
                    m.sumar(self.setup["valor_rayo"])
        # 5. Escribir. La cabeza vieja pasa a ser estela; si chocó, se marca el choque.
        for m, n, s in zip(motos, destino, sobrevive):
            m.prev = m.cabeza
            if s:
                self.escribir(m.cabeza, m.estela)
                m.ptr = (m.ptr + 1) & (MAX_LARGO - 1)
                m.buf[m.ptr] = n
                m.largo = min(m.largo + 1, MAX_LARGO)
                self.escribir(n, m.cabeza_cod)
            else:
                self.escribir(m.cabeza, CELL_CRASH)
                m.viva = False
                m.vidas -= 1
        # 6. ¿Alguien llegó a la meta? Gana al instante (si los dos, el de más puntos).
        meta = self.setup["meta"]
        if max(self.puntos) >= meta:
            p1, p2 = self.puntos
            self.terminar(EMPATE if p1 == p2 else (1 if p1 > p2 else 2))
            return
        # 7. ¿Alguien chocó? Termina la ronda.
        if not all(sobrevive):
            self.perdio_ronda = [m.indice for m, s in zip(motos, sobrevive) if not s]
            self.estado = ST_ROUND
            self.contador = FRAMES_ROUND

    def fin_de_ronda(self):
        """Si alguien se quedó sin vidas, pierde la partida (si los dos, gana
        el de más puntos). Si no, otra ronda."""
        sin_vidas = [m.vidas == 0 for m in self.motos]
        if sin_vidas[0] and sin_vidas[1]:
            p1, p2 = self.puntos
            self.terminar(EMPATE if p1 == p2 else (1 if p1 > p2 else 2))
        elif sin_vidas[0]:
            self.terminar(2)
        elif sin_vidas[1]:
            self.terminar(1)
        else:
            self.nueva_ronda()

    # --- para drawcon ---
    def pos_sprite(self, m):
        """Esquina del sprite de la moto (32x32) en píxeles, centrado en su
        celda y deslizándose de la celda anterior a la cabeza durante el
        periodo (en hardware: el avance es `periodo - mov`, y un factor de una
        tabla chica por velocidad)."""
        centro = (SPRITE_PX - TILE) // 2
        x1, y1 = cx_de(m.cabeza) * TILE - centro, cy_de(m.cabeza) * TILE - centro
        if not m.viva or self.estado != ST_PLAY:
            return x1, y1
        periodo = self.setup.periodo
        prog = periodo - self.mov
        x0, y0 = cx_de(m.prev) * TILE - centro, cy_de(m.prev) * TILE - centro
        return x0 + (x1 - x0) * prog // periodo, y0 + (y1 - y0) * prog // periodo

    # --- para pruebas y testbenches ---
    def contar(self, codigo):
        return sum(1 for v in self.arena if v == codigo)

    def arena_hex(self):
        """Contenido de la arena, una celda por línea en hex (formato $readmemh)."""
        return [f"{v:x}" for v in self.arena]


class BotTron:
    """Rival automático: sigue derecho mientras pueda y, si tiene algo
    enfrente, gira hacia el lado libre. A veces gira al azar (1 de cada 16)."""

    def decidir(self, juego, moto):
        libre = lambda d: juego.arena[vecino(moto.cabeza, d)] in (CELL_EMPTY, CELL_RAYO)
        der, izq = (moto.dir + 1) & 3, (moto.dir + 3) & 3
        rnd = juego.rnd >> moto.indice
        if libre(moto.dir) and (rnd >> 11) & 0xF:
            return moto.dir
        primero, segundo = (der, izq) if rnd & 1 else (izq, der)
        if libre(primero):
            return primero
        if libre(segundo):
            return segundo
        return moto.dir
