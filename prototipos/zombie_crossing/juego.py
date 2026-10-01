"""
Lógica de Zombie Crossing, separada del dibujo y del teclado.

Un zombie cruza el jardín: carriles de césped con nueces que estorban,
carriles de tiro donde un lanzaguisantes dispara desde la orilla, y la
piscina, donde solo se puede pisar sobre los nenúfares.

Este módulo es el "modelo de referencia" para la versión en hardware:
- Solo enteros, nada de floats.
- Aleatoriedad con un LFSR de 16 bits (en Verilog son unas pocas compuertas XOR).
- Cada carril es un registro de 32 bits + un offset de 10 bits.
- Los patrones de guisantes/nenúfares/nueces salen de una ROM pequeña.
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
# Guisantes: cada '#' es un guisante; el último patrón son disparos dobles (repetidora).
ROM_TIRO = [_patron(s) for s in (
    "#.......#.......#.......#.......",
    "#.....#..........#.....#........",
    "#...#...........#...#...........",
    "##.........##.........##........",
)]
# Nenúfares: cada '#' es un nenúfar donde el zombie puede pararse.
ROM_PISCINA = [_patron(s) for s in (
    "####...###....#####...###...####",
    "#####....####....#####....####..",
    "###..###..###..###...###..###...",
    "######.....######.....######....",
)]
# Nueces: en el césped solo importan los primeros 20 bits (las columnas visibles).
ROM_CESPED = [_patron(s) for s in (
    "#.......#.........#.............",
    "..#.........#.....#.............",
    "#....#.........#...#............",
    "...##.............##............",
)]


class Carril:
    __slots__ = ("tipo", "patron", "offset", "dir", "periodo", "paso_px", "contador")

    def __init__(self, tipo, patron, offset=0, dir=0, periodo=1, paso_px=1):
        self.tipo = tipo
        self.patron = patron      # 32 bits: 1 = guisante / nenúfar / nuez
        self.offset = offset      # 10 bits: desplazamiento en píxeles
        self.dir = dir            # +1 derecha, -1 izquierda, 0 quieto
        self.periodo = periodo    # frames entre cada movimiento
        self.paso_px = paso_px    # píxeles por movimiento
        self.contador = 0

    @property
    def hielo(self):
        """Los carriles de tiro rápidos son de hielaguisantes."""
        return self.tipo == TIRO and self.paso_px == 2

    @property
    def col_planta(self):
        """Columna de la orilla donde está la planta que dispara."""
        return 0 if self.dir > 0 else COLS - 1

    def ocupado(self, x):
        """¿El tile bajo el píxel horizontal x tiene algo (guisante/nenúfar/nuez)?

        En hardware: resta de 10 bits, tomar los 5 bits altos, y usar eso como
        selector de un multiplexor de 32 a 1 sobre `patron`.
        """
        tile = ((x - self.offset) & MASCARA_X) >> TILE_BITS
        return (self.patron >> tile) & 1 == 1

    def golpe(self, x):
        """¿El píxel x toca un guisante? Solo cuenta el centro del tile (8..23),
        que es donde se dibuja el guisante. En hardware: los 5 bits bajos."""
        rel = (x - self.offset) & MASCARA_X
        dentro = GUISANTE_INI <= (rel & (TILE - 1)) < GUISANTE_FIN
        return dentro and (self.patron >> (rel >> TILE_BITS)) & 1 == 1


class Juego:
    def __init__(self, semilla=0xACE1):
        self.lfsr = LFSR16(semilla)
        self.record = 0
        self.reiniciar()

    # ------------------------------------------------------------------
    # Estado inicial
    # ------------------------------------------------------------------
    def reiniciar(self):
        self.estado = INICIO
        self.cam = 0                          # fila absoluta del borde inferior
        self.jug_fila = FILA_INICIAL          # fila absoluta del zombie
        self.jug_x = (COLS // 2) * TILE       # posición horizontal en píxeles
        self.puntos = 0
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
            c = Carril(CESPED, 0)
        else:
            r = self._aleatorio()
            t = r & 0x7                          # 3 bits: 3/8 césped, 3/8 tiro, 2/8 piscina
            idx = (r >> 3) & 0x3                 # 2 bits: qué patrón de la ROM
            dir = 1 if (r >> 5) & 1 else -1      # 1 bit: dirección
            periodo = 1 + ((r >> 6) & 0x3)       # 2 bits: 1..4 frames por paso
            offset = (r >> 8) << 2               # 8 bits -> offset inicial
            if t < 3:
                c = Carril(CESPED, ROM_CESPED[idx])
            elif t < 6:
                # Hielaguisantes: con periodo 1 a veces avanzan 2 px por frame.
                paso_px = 2 if periodo == 1 and (r >> 14) & 1 else 1
                c = Carril(TIRO, ROM_TIRO[idx], offset, dir, periodo, paso_px)
            else:
                c = Carril(PISCINA, ROM_PISCINA[idx], offset, dir, min(periodo + 1, 4))
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

    def _bloqueado(self, c, x):
        """¿Hay una nuez o una planta en el tile del píxel x de este carril?"""
        if c.tipo == CESPED:
            return c.ocupado(x)
        if c.tipo == TIRO:
            return x >> TILE_BITS == c.col_planta
        return False

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
        if destino.tipo != PISCINA:
            # Al bajar de un nenúfar el zombie vuelve a alinearse con la cuadrícula.
            x = ((x + TILE // 2) >> TILE_BITS) << TILE_BITS
            x = min(max(x, 0), ANCHO - TILE)
        if self._bloqueado(destino, x + TILE // 2):
            return

        self.jug_fila, self.jug_x = fila, x
        avance = fila - FILA_INICIAL
        if avance > self.puntos:
            self.puntos = avance
            self.record = max(self.record, self.puntos)
            self.frames_sin_avanzar = 0

    def _mover_carriles(self):
        for fila in range(self.cam, self.cam + FILAS):
            c = self.carril(fila)
            if c.tipo == CESPED:
                continue
            c.contador += 1
            if c.contador >= c.periodo:
                c.contador = 0
                d = c.dir * c.paso_px
                c.offset = (c.offset + d) & MASCARA_X
                if c.tipo == PISCINA and fila == self.jug_fila:
                    self.jug_x += d   # el nenúfar arrastra al zombie

    def _mover_camara(self):
        while self.jug_fila - self.cam > FILA_CAMARA:
            self.cam += 1
            # El carril nuevo ocupa el lugar del que acaba de salir por abajo.
            self._generar(self.cam + FILAS - 1)

    def _revisar_muerte(self):
        c = self.carril(self.jug_fila)
        x = self.jug_x
        if c.tipo == TIRO:
            if any(c.golpe(x + p) for p in PUNTOS_ZOMBIE):
                self._morir("¡Te alcanzó un guisante!")
        elif c.tipo == PISCINA:
            if x < -TILE // 2 or x > ANCHO - TILE // 2:
                self._morir("La corriente te arrastró")
            elif not c.ocupado(x + TILE // 2):
                self._morir("Te hundiste en la piscina")

        self.frames_sin_avanzar += 1
        if self.estado == JUGANDO and self.frames_sin_avanzar > FRAMES_PODADORA:
            self._morir("¡La podadora!")

    def _morir(self, causa):
        self.estado = MUERTO
        self.causa = causa
        self.frames_muerto = 0
