"""
Prototipo de Tron (motos de luz) para 2 jugadores, con pygame.

La ventana es la imagen VGA de 1280x800 tal como la dibujará drawcon: solo
colores de la paleta RGB444, rectángulos, patrones que salen de bits de x/y,
sprites de ROM de 16x16 ampliados al doble y letras de la ROM de 8x8 (fuente.py)
ampliadas por bloques. Nada de letras suavizadas ni esquinas redondeadas.
Lo que es de la tarjeta (display de 7 segmentos y switches) va en el título
de la ventana.

Igual que en la tarjeta:
- El juego se controla con el teclado: cada tecla se convierte en los bytes
  PS/2 (Set 2) que mandaría el teclado y pasa por `TecladoPS2`.
- Los menús se manejan con los botones de la tarjeta y los switches cambian
  la velocidad, los colores de las motos y el fondo; aquí se simulan con el
  teclado.

Controles:
  En el juego:  P1 = W A S D, P2 = flechas
  Menús (botones de la tarjeta): flechas = BTNU/BTND/BTNL/BTNR, Enter o Espacio = BTNC
  Switches: teclas 1 a 6 cambian sw[0] a sw[5]
      sw[1:0] velocidad, sw[3:2] colores de las motos, sw[5:4] fondo del mapa
  C: P2 lo maneja la computadora (para probar solo)
  Esc: salir

Ejecutar:  python3 main.py
"""

import os
import sys

os.environ.setdefault("SDL_RENDER_SCALE_QUALITY", "0")     # escalar la ventana sin suavizar

import pygame

from config import *
from fuente import FUENTE, ANCHO_LETRA, pixeles
from juego import (Juego, BotTron, TecladoPS2, bytes_ps2, cx_de, cy_de,
                   digitos_display, rotar_sprite)


def rgb(c444):
    """RGB444 -> RGB888 (cada canal de 4 bits se repite: 0xA -> 0xAA)."""
    return (((c444 >> 8) & 0xF) * 17, ((c444 >> 4) & 0xF) * 17, (c444 & 0xF) * 17)


C = {nombre: rgb(v) for nombre, v in PALETA.items()}

# Tecla de pygame -> (extendida, código Set 2)
PS2_DE_PYGAME = {
    pygame.K_w: (0, 0x1D), pygame.K_a: (0, 0x1C), pygame.K_s: (0, 0x1B), pygame.K_d: (0, 0x23),
    pygame.K_UP: (1, 0x75), pygame.K_LEFT: (1, 0x6B), pygame.K_DOWN: (1, 0x72), pygame.K_RIGHT: (1, 0x74),
}
# Tecla de pygame -> botón de la tarjeta (solo en los menús y al terminar)
BOTON_DE_PYGAME = {
    pygame.K_UP: BTN_U, pygame.K_DOWN: BTN_D, pygame.K_LEFT: BTN_L, pygame.K_RIGHT: BTN_R,
    pygame.K_RETURN: BTN_C, pygame.K_SPACE: BTN_C,
}
TECLAS_SW = (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5, pygame.K_6)

# ----------------------------------------------------------------------
# ROMs de sprites (16x16). Cada carácter es un índice de color; '.' = transparente.
# La moto se guarda una sola vez, mirando hacia arriba, y se pinta con los
# colores del tema ('C' color, 'S' sombra, 'W' brillo, 'D' llanta).
# ----------------------------------------------------------------------
MOTO = (
    "......WWWW......",
    ".....SCCCCS.....",
    "....DDDDDDDD....",
    "....DDSSSSDD....",
    "....DDDDDDDD....",
    ".....SCCCCS.....",
    "....SCCWWCCS....",
    "...SCCCWWCCCS...",
    "...SCCCWWCCCS...",
    "....SCCWWCCS....",
    ".....SCCCCS.....",
    "....DDDDDDDD....",
    "....DDSSSSDD....",
    "....DDSSSSDD....",
    "....DDDDDDDD....",
    ".....CCCCCC.....",
)

RAYO = (
    "................",
    "........YYYY....",
    ".......YYYYO....",
    "......YYYYO.....",
    ".....YYWYO......",
    "....YYWYO.......",
    "...YYYYYYYYYO...",
    "..YYYYYYYYYO....",
    "......YWYYO.....",
    ".....YWYYO......",
    "....YYYYO.......",
    "...YYYO.........",
    "..YYO...........",
    ".YO.............",
    "................",
    "................",
)

for _s in (MOTO, RAYO):
    assert len(_s) == SPRITE and all(len(f) == SPRITE for f in _s)


def superficie(sprite, colores, d=DIR_UP):
    """Pinta la ROM con la paleta dada, al doble. Para cada píxel de salida
    (x, y) se lee la ROM en rotar_sprite(x >> 1, y >> 1), como lo haría drawcon."""
    lado = SPRITE * ESCALA
    s = pygame.Surface((lado, lado), pygame.SRCALPHA)
    for y in range(lado):
        for x in range(lado):
            sx, sy = rotar_sprite(x // ESCALA, y // ESCALA, d)
            ch = sprite[sy][sx]
            if ch != ".":
                s.fill(colores[ch], (x, y, 1, 1))
    return s


class Recursos:
    """Todo lo que en la FPGA son ROMs y tablas, ya convertido a superficies."""

    def __init__(self):
        # motos[tema][jugador][dirección]
        self.motos = [
            [[superficie(MOTO, {"C": rgb(c), "S": rgb(s), "W": rgb(w), "D": C["llanta"]}, d)
              for d in range(4)]
             for (c, s, w) in colores]
            for _, colores in TEMAS_MOTO
        ]
        self.rayo = superficie(RAYO, {"Y": C["rayo"], "O": C["rayo_osc"], "W": C["texto"]})
        self.fondos = [self.crear_fondo(*f[1:]) for f in FONDOS]
        self.letras = {}

    @staticmethod
    def crear_fondo(fondo, patron_color, patron):
        """El fondo sale de bits de x e y; aquí se dibuja una sola vez."""
        f = pygame.Surface((ANCHO, ALTO))
        f.fill(rgb(fondo))
        col = rgb(patron_color)
        if patron == "rejilla":
            for x in range(0, ANCHO, 64):
                f.fill(col, (x, 0, 1, ALTO))
            for y in range(0, ALTO, 64):
                f.fill(col, (0, y, ANCHO, 1))
        elif patron == "puntos":
            for y in range(0, ALTO, 32):
                for x in range(0, ANCHO, 32):
                    f.fill(col, (x, y, 2, 2))
        elif patron == "tablero":
            for y in range(0, ALTO, 64):
                for x in range(0, ANCHO, 64):
                    if ((x >> 6) ^ (y >> 6)) & 1:
                        f.fill(col, (x, y, 64, 64))
        f.fill(C["hud"], (0, 0, ANCHO, HUD_ROWS * TILE))
        return f

    def letra(self, ch, escala, color):
        """Letra de la ROM de 8x8 ampliada `escala` veces (cada bit = un bloque)."""
        clave = (ch, escala, color)
        if clave not in self.letras:
            s = pygame.Surface((ANCHO_LETRA * escala, ANCHO_LETRA * escala), pygame.SRCALPHA)
            for x, y in pixeles(ch):
                s.fill(color, (x * escala, y * escala, escala, escala))
            self.letras[clave] = s
        return self.letras[clave]


def texto(pantalla, rec, msg, y, escala=2, color=None, x=None, caja=False):
    """Texto en mayúsculas con la ROM de letras. Si x es None se centra.
    `caja` pone un rectángulo negro detrás, para leerlo encima de la arena."""
    msg = msg.upper()
    color = color or C["texto"]
    ancho = len(msg) * ANCHO_LETRA * escala
    if x is None:
        x = (ANCHO - ancho) // 2
    if caja:
        margen = ANCHO_LETRA * escala // 2
        pantalla.fill(C["sombra"], (x - margen, y - margen, ancho + 2 * margen,
                                    ANCHO_LETRA * escala + 2 * margen))
    for k, ch in enumerate(msg):
        pantalla.blit(rec.letra(ch, escala, color), (x + k * ANCHO_LETRA * escala, y))
    return x + ancho


def ancho_texto(msg, escala):
    return len(msg) * ANCHO_LETRA * escala


# ----------------------------------------------------------------------
# drawcon
# ----------------------------------------------------------------------
def pintar_celda(pantalla, v, x, y, colores_motos):
    """Capa de la arena: color según el tipo de celda y la posición dentro de
    la celda (x[3:0], y[3:0])."""
    if v == CELL_WALL:
        pantalla.fill(C["pared_osc"], (x, y, TILE, TILE))
        pantalla.fill(C["pared"], (x + 2, y + 2, TILE - 4, TILE - 4))
    elif v in (CELL_P1_TRAIL, CELL_P2_TRAIL):
        color = colores_motos[(v - CELL_P1_TRAIL) // 2][0]
        pantalla.fill(rgb(color), (x, y, TILE, TILE))
    elif v == CELL_CRASH:
        # Una X: se enciende si x[3:0] == y[3:0] o x[3:0] == ~y[3:0] (2 px de grueso).
        pantalla.fill(C["choque"], (x, y, TILE, TILE))
        for i in range(TILE):
            for j in (i, TILE - 1 - i):
                pantalla.fill(C["texto"], (x + j, y + i, 1, 1))
                if j + 1 < TILE:
                    pantalla.fill(C["texto"], (x + j + 1, y + i, 1, 1))
    # CELL_P*_HEAD y CELL_RAYO no se pintan aquí: van con sprite encima.


def nombre(i, con_bot):
    return "CPU" if con_bot and i == 1 else f"P{i + 1}"


def color_jugador(juego, i):
    return rgb(TEMAS_MOTO[juego.setup.tema][1][i][0])


def dibujar_hud(pantalla, rec, juego, con_bot):
    """Franja de arriba (filas 0-1): vidas y puntos de cada jugador y la meta."""
    y = (HUD_ROWS * TILE - 2 * ANCHO_LETRA) // 2
    m1, m2 = juego.motos
    texto(pantalla, rec, f"{nombre(0, con_bot)} VIDAS {m1.vidas} PUNTOS {m1.puntos:02d}", y,
          color=color_jugador(juego, 0), x=16)
    derecha = f"{nombre(1, con_bot)} VIDAS {m2.vidas} PUNTOS {m2.puntos:02d}"
    texto(pantalla, rec, derecha, y, color=color_jugador(juego, 1), x=ANCHO - 16 - ancho_texto(derecha, 2))
    texto(pantalla, rec, f"META {juego.setup['meta']}", y)


def opcion(pantalla, rec, y, elegida, izquierda, derecha=None, x_izq=None, x_der=None):
    """Una línea de menú con letras x4; la elegida va sobre un rectángulo."""
    alto = ANCHO_LETRA * 4
    if elegida:
        pantalla.fill(C["sel"], (64, y - 8, ANCHO - 128, alto + 16))
    if derecha is None:
        texto(pantalla, rec, izquierda, y, escala=4)
    else:
        texto(pantalla, rec, izquierda, y, escala=4, x=x_izq)
        texto(pantalla, rec, derecha, y, escala=4, x=x_der)


def dibujar_menu(pantalla, rec, juego):
    texto(pantalla, rec, "TRON", 140, escala=16, color=color_jugador(juego, 0))
    for k, nombre_op in enumerate(MENU_PRINCIPAL):
        opcion(pantalla, rec, 360 + k * 72, k == juego.menu_sel, nombre_op)
    texto(pantalla, rec, "ARRIBA/ABAJO ELIGEN, CENTRO ENTRA", 700)
    texto(pantalla, rec, "PC: FLECHAS Y ENTER. C = CONTRA LA CPU. TECLAS 1-6 = SWITCHES", 740)


def texto_opcion(clave, valor):
    if clave == "largo":
        return "INFINITA" if valor == 0 else f"{valor} CELDAS"
    return str(valor)


def dibujar_config(pantalla, rec, juego):
    s = juego.setup
    texto(pantalla, rec, "CONFIGURACIÓN", 80, escala=8)
    y = 220
    for k, (clave, etiqueta, _opciones, _ini) in enumerate(CONFIG):
        opcion(pantalla, rec, y, k == s.sel, etiqueta, f"< {texto_opcion(clave, s[clave])} >",
               x_izq=96, x_der=760)
        y += 64
    y += 24
    texto(pantalla, rec, f"SW[1:0] VELOCIDAD: {NOMBRE_VEL[s.sw & 3]}", y)
    texto(pantalla, rec, f"SW[3:2] COLORES: {TEMAS_MOTO[s.tema][0]}", y + 32)
    texto(pantalla, rec, f"SW[5:4] FONDO: {FONDOS[s.fondo][0]}", y + 64)
    texto(pantalla, rec, "ARRIBA/ABAJO ELIGEN, IZQ./DER. CAMBIAN, CENTRO VUELVE", 740)


def dibujar_ayuda(pantalla, rec, juego):
    texto(pantalla, rec, "CÓMO JUGAR", 80, escala=8)
    lineas = (
        ("P1: W A S D", color_jugador(juego, 0)),
        ("P2: FLECHAS", color_jugador(juego, 1)),
        ("", None),
        ("TU MOTO DEJA UNA ESTELA. SI CHOCAS CON UNA PARED", None),
        ("O CON CUALQUIER ESTELA (TAMBIÉN LA TUYA), PIERDES UNA VIDA.", None),
        ("", None),
        ("TOMA LOS RAYOS PARA SUMAR PUNTOS.", C["rayo"]),
        (f"GANA QUIEN LLEGUE PRIMERO A LA META ({juego.setup['meta']} PUNTOS).", None),
        ("SI TE QUEDAS SIN VIDAS, PIERDES.", None),
        ("", None),
        ("EL DISPLAY DE LA TARJETA MUESTRA [VIDAS] [ ] [PUNTOS] DE CADA JUGADOR.", None),
    )
    for k, (linea, color) in enumerate(lineas):
        texto(pantalla, rec, linea, 220 + k * 36, color=color)
    texto(pantalla, rec, "CENTRO PARA VOLVER AL MENÚ", 740)


def dibujar(pantalla, juego, rec, con_bot):
    s = juego.setup
    pantalla.blit(rec.fondos[s.fondo], (0, 0))
    dibujar_hud(pantalla, rec, juego, con_bot)

    pantallas = {ST_MENU: dibujar_menu, ST_CONFIG: dibujar_config, ST_AYUDA: dibujar_ayuda}
    if juego.estado in pantallas:
        pantallas[juego.estado](pantalla, rec, juego)
        return

    # Capa 1: la arena.
    colores_motos = TEMAS_MOTO[s.tema][1]
    for addr, v in enumerate(juego.arena):
        if v != CELL_EMPTY:
            pintar_celda(pantalla, v, cx_de(addr) * TILE, cy_de(addr) * TILE, colores_motos)

    # Capa 2: sprites en posiciones de registro.
    if juego.rayo is not None:
        pantalla.blit(rec.rayo, (cx_de(juego.rayo) * TILE, cy_de(juego.rayo) * TILE))
    for m in juego.motos:
        if m.viva:
            pantalla.blit(rec.motos[s.tema][m.indice][m.dir], juego.pos_sprite(m))

    # Capa 3: mensajes.
    if juego.estado == ST_READY:
        texto(pantalla, rec, str((juego.contador + FPS - 1) // FPS), 320, escala=16, caja=True)
    elif juego.estado == ST_ROUND:
        if len(juego.perdio_ronda) == 2:
            texto(pantalla, rec, "¡CHOQUE DOBLE!", 300, escala=8, caja=True)
            texto(pantalla, rec, "LOS DOS PIERDEN UNA VIDA", 420, escala=4, caja=True)
        else:
            i = juego.perdio_ronda[0]
            texto(pantalla, rec, f"¡{nombre(i, con_bot)} CHOCÓ!", 300, escala=8,
                  color=color_jugador(juego, i), caja=True)
            texto(pantalla, rec, f"LE QUEDAN {juego.motos[i].vidas} VIDAS", 420, escala=4, caja=True)
    elif juego.estado == ST_MATCH:
        if juego.ganador == EMPATE:
            texto(pantalla, rec, "EMPATE", 300, escala=8, caja=True)
        else:
            i = juego.ganador - 1
            texto(pantalla, rec, f"¡{nombre(i, con_bot)} GANA!", 300, escala=8,
                  color=color_jugador(juego, i), caja=True)
        texto(pantalla, rec, "CENTRO PARA VOLVER AL MENÚ", 420, escala=4, caja=True)


def titulo_tarjeta(juego, sw):
    """Lo que se ve en la tarjeta: el display de 7 segmentos y los switches."""
    dig = digitos_display(juego.vidas, juego.puntos)
    display = "".join(" " if d is None else str(d) for d in dig)
    return f"Tron  |  display: [{display}]  |  sw[5:0] = {sw:06b}"


def main():
    pygame.init()
    pantalla = pygame.display.set_mode((ANCHO, ALTO), pygame.SCALED | pygame.RESIZABLE)
    reloj = pygame.time.Clock()
    rec = Recursos()
    juego = Juego(semilla=pygame.time.get_ticks() | 1)
    teclado = TecladoPS2()
    bot = BotTron()
    con_bot = False
    sw = 0b000001               # velocidad normal, colores clásicos, fondo con rejilla
    titulo = None

    while True:
        btn = 0
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT or (ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE):
                pygame.quit()
                sys.exit()
            if ev.type in (pygame.KEYDOWN, pygame.KEYUP) and ev.key in PS2_DE_PYGAME:
                # Lo que llega por PS2_DATA, byte por byte.
                for b in bytes_ps2(PS2_DE_PYGAME[ev.key], soltada=ev.type == pygame.KEYUP):
                    teclado.recibir(b)
            if ev.type == pygame.KEYDOWN:
                if ev.key in BOTON_DE_PYGAME and juego.estado in (ST_MENU, ST_CONFIG, ST_AYUDA, ST_MATCH):
                    btn |= 1 << BOTON_DE_PYGAME[ev.key]
                elif ev.key in TECLAS_SW:
                    sw ^= 1 << TECLAS_SW.index(ev.key)
                elif ev.key == pygame.K_c:
                    con_bot = not con_bot

        if con_bot and juego.estado == ST_PLAY:
            teclado.dirs[1] = bot.decidir(juego, juego.motos[1])

        antes = juego.estado
        juego.paso(teclado.dirs, btn, sw)
        if juego.estado == ST_READY and antes != ST_READY:
            teclado.reiniciar_dirs()

        dibujar(pantalla, juego, rec, con_bot)
        nuevo = titulo_tarjeta(juego, sw)
        if nuevo != titulo:
            pygame.display.set_caption(nuevo)
            titulo = nuevo
        pygame.display.flip()
        reloj.tick(FPS)


if __name__ == "__main__":
    main()
