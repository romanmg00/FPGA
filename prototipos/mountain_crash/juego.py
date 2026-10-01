"""
Lógica de Mountain Crash, separada del dibujo y de la entrada.

Este módulo es el "modelo de referencia" para la versión en Verilog:
- Solo enteros; posiciones y velocidades en punto fijo Q4 (1/16 de píxel).
- Aleatoriedad con un LFSR de 16 bits.
- El terreno es un buffer circular de 16 filas de 20 bits (1 = montaña).
- Los sprites (avión y montaña) son ROMs de 16x16.
- Máquina de estados: INICIO -> JUGANDO -> CHOQUE -> INICIO.
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


# ----------------------------------------------------------------------
# ROMs de sprites. Cada carácter es un índice de color; '.' = transparente.
# ----------------------------------------------------------------------
COLOR_SPRITE = {
    "W": "avion", "G": "avion_osc", "R": "franja", "B": "cabina",
    "M": "roca", "D": "roca_osc", "N": "nieve",
}

AVION_RECTO = (
    ".......RR.......",
    ".......WW.......",
    "......WBBW......",
    "......WBBW......",
    "......WWWW......",
    ".....WWWWWW.....",
    "..WWWWWWWWWWWW..",
    "RWWWWWWWWWWWWWWR",
    "RWWWWWWWWWWWWWWR",
    ".......WW.......",
    ".......WW.......",
    ".......WW.......",
    ".....WWWWWW.....",
    "....RWWWWWWR....",
    ".......RR.......",
    "................",
)

# Inclinado a la izquierda: el ala izquierda baja, se ve más corta y en sombra.
AVION_IZQ = AVION_RECTO[:6] + (
    ".....GGWWWWWWW..",
    "....RGGWWWWWWWWR",
    "....RGGWWWWWWWWR",
) + AVION_RECTO[9:12] + (
    "......GWWWWW....",
    ".....RGWWWWR....",
) + AVION_RECTO[14:]

AVION_DER = tuple(fila[::-1] for fila in AVION_IZQ)

MONTANA = (
    "DMMMMMMMMMMMMMMD",
    "MMMMMMDMMMMMMMMM",
    "MMMMMDDDMMMMMDMM",
    "MMMMDNNNDMMMDDDM",
    "MMMDNNNNNDMMMMMM",
    "MMDNNNNNNNDMMMMM",
    "MDNNNNNNNNNDMMMM",
    "MMDNNNNNNNNNDMMM",
    "MMMDNNNNNNNNDMMM",
    "MMMMDDNNNNNDMMMM",
    "MMDMMMDDNNDMMMMM",
    "MDDDMMMMDDMMMDMM",
    "MMMMMMMMMMMMDDDM",
    "MMMMMDMMMMMMMMMM",
    "MMMMDDDMMMMMMMMM",
    "DMMMMMMMMMMMMMMD",
)

for _s in (AVION_RECTO, AVION_IZQ, AVION_DER, MONTANA):
    assert len(_s) == SPRITE and all(len(f) == SPRITE for f in _s)

POSE_IZQ, POSE_RECTO, POSE_DER = 0, 1, 2
SPRITES_AVION = (AVION_IZQ, AVION_RECTO, AVION_DER)

# Píxeles opacos de cada pose, para la colisión.
_OPACOS = tuple(
    tuple((sx, sy) for sy, f in enumerate(s) for sx, ch in enumerate(f) if ch != ".")
    for s in SPRITES_AVION
)


# ----------------------------------------------------------------------
# Entrada: acelerómetro
# ----------------------------------------------------------------------
def velocidad_lateral(a):
    """Inclinación filtrada (-64..64) -> velocidad lateral en Q4.

    En hardware: comparador para la zona muerta, una resta y a*3/2 = (a + 2a) >> 1.
    """
    if a > ZONA_MUERTA:
        a -= ZONA_MUERTA
    elif a < -ZONA_MUERTA:
        a += ZONA_MUERTA
    else:
        return 0
    return (a + (a << 1)) >> 1


def pose_avion(a):
    if a <= -UMBRAL_INCLINADO:
        return POSE_IZQ
    if a >= UMBRAL_INCLINADO:
        return POSE_DER
    return POSE_RECTO


class Fila:
    __slots__ = ("montanas", "izq", "ancho")

    def __init__(self, montanas, izq=0, ancho=COLS):
        self.montanas = montanas   # 20 bits: bit c = montaña en la columna c
        self.izq = izq             # primera columna del pasillo libre
        self.ancho = ancho         # ancho del pasillo en tiles


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
        self.dist_fp = 0                               # distancia recorrida (Q4)
        self.vel_fp = VEL_INICIAL                      # velocidad de scroll (Q4)
        self.avion_x_fp = ((ANCHO - AVION_TAM) // 2) << FP_BITS
        self.accel = 0                                 # inclinación filtrada
        self.pose = POSE_RECTO
        self.frames = 0
        self.frames_choque = 0
        self.pasillo_centro = COLS // 2
        self.pasillo_dir = 0
        self.filas = [None] * NUM_FILAS
        self.ultima_fila = -1
        self._generar_filas_visibles()

    # --- Accesos cómodos ---
    @property
    def dist(self):
        return self.dist_fp >> FP_BITS

    @property
    def avion_x(self):
        return self.avion_x_fp >> FP_BITS

    @property
    def puntos(self):
        return self.dist >> TILE_BITS    # una fila de montañas = 1 punto

    def fila(self, n):
        return self.filas[n & MASCARA_FILA]

    def montana_en(self, x, y):
        """¿Hay montaña en el píxel (x, y) de la pantalla?

        Es exactamente lo que el módulo de render calcula para cada píxel.
        """
        wy = self.dist + (ALTO - 1 - y)          # coordenada del mundo (hacia arriba)
        f = self.fila(wy >> TILE_BITS)
        return (f.montanas >> (x >> TILE_BITS)) & 1 == 1

    # ------------------------------------------------------------------
    # Terreno
    # ------------------------------------------------------------------
    def _aleatorio(self):
        # En la FPGA el LFSR corre en cada ciclo de reloj; aquí lo avanzamos
        # 16 veces para que dos filas seguidas no salgan correlacionadas.
        for _ in range(16):
            self.lfsr.siguiente()
        return self.lfsr.estado

    def _generar_filas_visibles(self):
        arriba = (self.dist + ALTO - 1) >> TILE_BITS
        while self.ultima_fila < arriba:
            self.ultima_fila += 1
            self._generar(self.ultima_fila)

    def _generar(self, n):
        """Crea la fila absoluta `n`. Siempre deja un pasillo libre que se
        mueve como mucho 1 tile cada 2 filas, así que el juego nunca es imposible."""
        if n < FILAS_SEGURAS:
            self.filas[n & MASCARA_FILA] = Fila(0)
            return

        ancho = max(ANCHO_PASILLO_MINIMO,
                    ANCHO_PASILLO_INICIAL - (n - FILAS_SEGURAS) // FILAS_ANGOSTAR)
        r = self._aleatorio()

        # 1 de cada 4 filas el pasillo cambia de rumbo (izq / recto / der).
        if r & 0x3 == 0:
            self.pasillo_dir = (-1, 0, 0, 1)[(r >> 2) & 0x3]
        # Solo en filas pares y la mitad de esas veces: pendiente máxima de
        # 1 tile cada 2 filas. A 6 px/frame de scroll eso exige 3 px/frame de
        # lado, y el avión llega a ~5.4, así que siempre da tiempo de seguirlo.
        if n & 1 == 0 and (r >> 4) & 1:
            self.pasillo_centro += self.pasillo_dir

        # Rebota en las orillas.
        mitad = ancho // 2
        if self.pasillo_centro - mitad < 0:
            self.pasillo_centro = mitad
            self.pasillo_dir = 1
        elif self.pasillo_centro - mitad + ancho > COLS:
            self.pasillo_centro = COLS - ancho + mitad
            self.pasillo_dir = -1
        izq = self.pasillo_centro - mitad

        # Fuera del pasillo: montaña con probabilidad 3/4 (OR de dos palabras aleatorias).
        a = self._aleatorio() | (self._aleatorio() << 16)
        b = self._aleatorio() | (self._aleatorio() << 16)
        ruido = a | b
        pasillo = ((1 << ancho) - 1) << izq
        montanas = ruido & ~pasillo & MASCARA_COLS
        self.filas[n & MASCARA_FILA] = Fila(montanas, izq, ancho)

    # ------------------------------------------------------------------
    # Un frame
    # ------------------------------------------------------------------
    def paso(self, accel_crudo=0, boton=False):
        """accel_crudo: eje X del ADXL362 (8 bits con signo). boton: BTNC."""
        self.lfsr.siguiente()   # el LFSR siempre corre: el mundo depende del tiempo del jugador

        # Filtro pasa-bajas de un registro: a += (x - a) / 4
        x = max(-ACCEL_MAX, min(ACCEL_MAX, accel_crudo))
        self.accel += (x - self.accel) >> 2

        if self.estado == INICIO:
            self.pose = pose_avion(self.accel)
            if boton:
                self.estado = JUGANDO
            return

        if self.estado == CHOQUE:
            self.frames_choque += 1
            if boton and self.frames_choque > FRAMES_ESPERA_CHOQUE:
                self.reiniciar()
            return

        self.frames += 1

        # Avión: velocidad lateral proporcional a la inclinación.
        self.pose = pose_avion(self.accel)
        self.avion_x_fp += velocidad_lateral(self.accel)
        self.avion_x_fp = max(0, min((ANCHO - AVION_TAM) << FP_BITS, self.avion_x_fp))

        # Scroll: el mundo avanza y cada cierto tiempo acelera.
        self.dist_fp += self.vel_fp
        if self.frames % FRAMES_ACELERAR == 0 and self.vel_fp < VEL_MAXIMA:
            self.vel_fp += 1
        self._generar_filas_visibles()

        if self._choco():
            self.estado = CHOQUE
            self.frames_choque = 0
            self.record = max(self.record, self.puntos)

    def _choco(self):
        """Colisión píxel a píxel: algún píxel opaco del avión sobre una montaña.

        En la FPGA sale casi gratis: mientras se dibuja la pantalla, si en el mismo
        píxel el sprite del avión es opaco y el terreno es montaña, se activa un
        flag que se lee en el siguiente vsync.
        """
        x0, y0 = self.avion_x, AVION_Y
        for sx, sy in _OPACOS[self.pose]:
            if self.montana_en(x0 + sx * ESCALA, y0 + sy * ESCALA):
                return True
        return False
