"""
Lógica del juego tipo Crossy Road, separada del dibujo y del teclado.

Este módulo es el "modelo de referencia" para la versión en hardware:
- Solo enteros, nada de floats.
- Aleatoriedad con un LFSR de 16 bits (en Verilog son unas pocas compuertas XOR).
- Cada carril es un registro de 32 bits + un offset de 10 bits.
- Los patrones de autos/troncos/árboles salen de una ROM pequeña.
- Una máquina de estados sencilla: INICIO -> JUGANDO -> MUERTO -> INICIO.
- `paso()` avanza exactamente un frame (en la FPGA: un pulso por cada vsync).
"""

from config import *


class LFSR16:
    """LFSR de Galois de 16 bits, polinomio x^16 + x^14 + x^13 + x^11 + 1.

    Recorre los 65535 estados distintos de cero antes de repetirse.
    """

    def __init__(self, semilla=0xACE1):
        self.estado = (semilla & 0xFFFF) or 1

    def siguiente(self):
        lsb = self.estado & 1
        self.estado >>= 1
        if lsb:
            self.estado ^= 0xB400
        return self.estado


def _patron(s):
    """Convierte "##..#" en un entero: el carácter i es el bit i."""
    assert len(s) == CARRIL_BITS, (len(s), s)
    return sum(1 << i for i, c in enumerate(s) if c == "#")


# --- ROM de patrones (4 por tipo -> se eligen con 2 bits aleatorios) ---
ROM_CALLE = [_patron(s) for s in (
    "##......##.......##.......##....",
    "###.........###.........###.....",
    "##....##..........##....##......",
    "####..............####..........",
)]
ROM_RIO = [_patron(s) for s in (
    "####...###....#####...###...####",
    "#####....####....#####....####..",
    "###..###..###..###...###..###...",
    "######.....######.....######....",
)]
# En el pasto solo importan los primeros 20 bits (las columnas visibles).
ROM_PASTO = [_patron(s) for s in (
    "#.......#.........#.............",
    "..#.........#.....#.............",
    "#....#.........#...#............",
    "...##.............##............",
)]


class Carril:
    __slots__ = ("tipo", "patron", "offset", "dir", "periodo", "paso_px", "contador", "color")

    def __init__(self, tipo, patron, offset=0, dir=0, periodo=1, paso_px=1, color=0):
        self.tipo = tipo
        self.patron = patron      # 32 bits: 1 = auto / tronco / árbol
        self.offset = offset      # 10 bits: desplazamiento en píxeles
        self.dir = dir            # +1 derecha, -1 izquierda, 0 quieto
        self.periodo = periodo    # frames entre cada movimiento
        self.paso_px = paso_px    # píxeles por movimiento
        self.contador = 0
        self.color = color        # índice en COLORES_AUTOS

    def ocupado(self, x):
        """¿Hay algo (auto/tronco/árbol) en el píxel horizontal x de la pantalla?

        En hardware: resta de 10 bits, tomar los 5 bits altos, y usar eso como
        selector de un multiplexor de 32 a 1 sobre `patron`.
        """
        tile = ((x - self.offset) & MASCARA_X) >> TILE_BITS
        return (self.patron >> tile) & 1 == 1


class Juego:
    def __init__(self, semilla=0xACE1):
        self.lfsr = LFSR16(semilla)
        self.reiniciar()

    # ------------------------------------------------------------------
    # Estado inicial
    # ------------------------------------------------------------------
    def reiniciar(self):
        self.estado = INICIO
        self.cam = 0                          # fila absoluta del borde inferior
        self.jug_fila = FILA_INICIAL          # fila absoluta de la gallina
        self.jug_x = (COLS // 2) * TILE       # posición horizontal en píxeles
        self.puntos = 0
        self.record = getattr(self, "record", 0)
        self.frames_sin_avanzar = 0
        self.frames_muerto = 0
        self.causa = ""
        self.carriles = [None] * NUM_CARRILES
        for fila in range(FILAS):
            self._generar(fila)

    def carril(self, fila):
        return self.carriles[fila & MASCARA_CARRIL]

    def _aleatorio(self):
        # En la FPGA el LFSR corre en cada ciclo de reloj; aquí lo avanzamos
        # 16 veces para que dos carriles seguidos no salgan correlacionados.
        for _ in range(16):
            self.lfsr.siguiente()
        return self.lfsr.estado

    def _generar(self, fila):
        """Crea el carril de la fila absoluta `fila` en su lugar del buffer."""
        if fila < FILAS_SEGURAS:
            c = Carril(PASTO, 0)
        else:
            r = self._aleatorio()
            t = r & 0x7                          # 3 bits: 3/8 pasto, 3/8 calle, 2/8 río
            idx = (r >> 3) & 0x3                 # 2 bits: qué patrón de la ROM
            dir = 1 if (r >> 5) & 1 else -1      # 1 bit: dirección
            periodo = 1 + ((r >> 6) & 0x3)       # 2 bits: 1..4 frames por paso
            offset = (r >> 8) << 2               # 8 bits -> offset inicial
            color = (r >> 12) % len(COLORES_AUTOS)
            if t < 3:
                c = Carril(PASTO, ROM_PASTO[idx])
            elif t < 6:
                # Autos rápidos: con periodo 1 a veces avanzan 2 px por frame.
                paso_px = 2 if periodo == 1 and (r >> 14) & 1 else 1
                c = Carril(CALLE, ROM_CALLE[idx], offset, dir, periodo, paso_px, color)
            else:
                c = Carril(RIO, ROM_RIO[idx], offset, dir, min(periodo + 1, 4))
        self.carriles[fila & MASCARA_CARRIL] = c

    # ------------------------------------------------------------------
    # Un frame
    # ------------------------------------------------------------------
    def paso(self, entrada=NADA):
        self.lfsr.siguiente()   # el LFSR siempre corre: el mundo depende del tiempo del jugador

        if self.estado == INICIO:
            if entrada != NADA:
                self.estado = JUGANDO
            return

        if self.estado == MUERTO:
            self.frames_muerto += 1
            if entrada != NADA and self.frames_muerto > FRAMES_ESPERA_MUERTO:
                self.reiniciar()
            return

        self._mover_jugador(entrada)
        self._mover_carriles()
        self._mover_camara()
        self._revisar_muerte()

    def _mover_jugador(self, entrada):
        if entrada == NADA:
            return
        fila, x = self.jug_fila, self.jug_x
        if entrada == ARRIBA:
            fila += 1
        elif entrada == ABAJO:
            fila -= 1
        elif entrada == IZQ:
            x -= TILE
        elif entrada == DER:
            x += TILE

        if fila < self.cam or x < 0 or x > ANCHO - TILE:
            return

        destino = self.carril(fila)
        if destino.tipo != RIO:
            # Al bajar de un tronco la gallina vuelve a alinearse con la cuadrícula.
            x = ((x + TILE // 2) >> TILE_BITS) << TILE_BITS
            x = min(max(x, 0), ANCHO - TILE)
        if destino.tipo == PASTO and destino.ocupado(x + TILE // 2):
            return  # hay un árbol

        self.jug_fila, self.jug_x = fila, x
        avance = fila - FILA_INICIAL
        if avance > self.puntos:
            self.puntos = avance
            self.record = max(self.record, self.puntos)
            self.frames_sin_avanzar = 0

    def _mover_carriles(self):
        for fila in range(self.cam, self.cam + FILAS):
            c = self.carril(fila)
            if c.tipo == PASTO:
                continue
            c.contador += 1
            if c.contador >= c.periodo:
                c.contador = 0
                d = c.dir * c.paso_px
                c.offset = (c.offset + d) & MASCARA_X
                if c.tipo == RIO and fila == self.jug_fila:
                    self.jug_x += d   # el tronco arrastra a la gallina

    def _mover_camara(self):
        while self.jug_fila - self.cam > FILA_CAMARA:
            self.cam += 1
            # El carril nuevo ocupa el lugar del que acaba de salir por abajo.
            self._generar(self.cam + FILAS - 1)

    def _revisar_muerte(self):
        c = self.carril(self.jug_fila)
        x = self.jug_x
        if c.tipo == CALLE:
            if c.ocupado(x + MARGEN_CHOQUE) or c.ocupado(x + TILE - 1 - MARGEN_CHOQUE):
                self._morir("¡Atropellada!")
        elif c.tipo == RIO:
            if x < -TILE // 2 or x > ANCHO - TILE // 2:
                self._morir("El río se la llevó")
            elif not c.ocupado(x + TILE // 2):
                self._morir("¡Al agua!")

        self.frames_sin_avanzar += 1
        if self.estado == JUGANDO and self.frames_sin_avanzar > FRAMES_AGUILA:
            self._morir("¡El águila!")

    def _morir(self, causa):
        self.estado = MUERTO
        self.causa = causa
        self.frames_muerto = 0
