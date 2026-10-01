"""
ROMs de sprites de Zombie Crossing: pixel art propio inspirado en Plantas vs Zombies.

Cada sprite es una lista de filas; cada carácter es un índice de color y
'.' es transparente. Los colores son RGB444, como en la FPGA, donde cada
sprite será una ROM con dirección (fila, columna).
"""

SPRITES = {}
COLORES = {}


def _sprite(nombre, filas, colores):
    ancho = len(filas[0])
    assert all(len(f) == ancho for f in filas), nombre
    assert all(ch == "." or ch in colores for f in filas for ch in f), nombre
    SPRITES[nombre] = filas
    COLORES[nombre] = colores


# El personaje: zombie de saco café, camisa blanca y corbata roja.
_sprite("zombie", (
    ".....SSSSSS.....",
    "....SSSSSSSS....",
    "...SSSsSSSSSS...",
    "...SWWSSSWWSS...",
    "...SWKSSSWKSS...",
    "...SSSSSSSSSS...",
    "...SSKKKKKSSS...",
    "....SSKWKSSS....",
    ".....SSSSSS.....",
    "...BBBWRWBBB....",
    "..BBBBWRWBBBB...",
    "..SBBBBRBBBBS...",
    "..SBBBBRBBBBS...",
    "...BBBBBBBBB....",
    "...PPP...PPP....",
    "...KKK...KKK....",
), {"S": 0x9B8, "s": 0x786, "W": 0xFFF, "K": 0x000, "B": 0x753, "R": 0xD22, "P": 0x445})

# Lanzaguisantes mirando a la derecha (se refleja para la orilla derecha).
_LANZAGUISANTES = (
    "................",
    "....GGGGG.......",
    "...GGGGGGG......",
    "..GGGKGGGGGGGG..",
    "..GGGKGGGGGgggG.",
    "..GGGGGGGGGg..g.",
    "..GGGGGGGGGgggG.",
    "...GGGGGGGGGGG..",
    "....GGGGG.......",
    "......gg........",
    "......gg........",
    "...LL.gg.LL.....",
    "..LLLLggLLLL....",
    "...LLLggLLL.....",
    "......gg........",
    ".....gggg.......",
)
_sprite("lanzaguisantes", _LANZAGUISANTES, {"G": 0x5C3, "g": 0x392, "K": 0x000, "L": 0x4A2})
_sprite("hielaguisantes", _LANZAGUISANTES, {"G": 0x8CF, "g": 0x48C, "K": 0x000, "L": 0x4A2})

_GUISANTE = (
    "..PPPP..",
    ".PhhPPP.",
    "PhhPPPPP",
    "PhPPPPPP",
    "PPPPPPPP",
    "PPPPPPPP",
    ".PPPPPP.",
    "..PPPP..",
)
_sprite("guisante", _GUISANTE, {"P": 0x5D2, "h": 0xBF8})
_sprite("guisante_hielo", _GUISANTE, {"P": 0x7CF, "h": 0xEFF})

_sprite("nenufar", (
    "................",
    ".....LLLLLL.....",
    "...LLLLLLLLLL...",
    "..LLLLLlLLLLLL..",
    ".LLLLLLlLLLLLLL.",
    ".LLLLLLlLLLLLLL.",
    ".LllLLLlLLLllLL.",
    ".LLLllLlLllLLLL.",
    ".LLLLLlllLLLLLL.",
    ".LLLLLLLLLLLLLL.",
    ".LLLLLLLLLLLLLL.",
    "..LLLLLLLLLLLL..",
    "...LLLLLLLLLL...",
    ".....LLLLLL.....",
    "................",
    "................",
), {"L": 0x4B4, "l": 0x293})

_sprite("nuez", (
    ".....NNNNNN.....",
    "...NNNNNNNNNN...",
    "..NNNNNNNNNNNN..",
    ".NNNNNNNNNNNNNN.",
    ".NNNWWNNNNWWNNN.",
    ".NNNWKNNNNWKNNN.",
    ".NNNNNNNNNNNNNN.",
    ".NNnNNNNNNNNnNN.",
    ".NNNNNnnnnNNNNN.",
    ".NNNNNNNNNNNNNN.",
    ".NNnNNNNNNNNNNN.",
    ".NNNNNNNNNNnNNN.",
    "..NNNNNNNNNNNN..",
    "...NNNNNNNNNN...",
    ".....NNNNNN.....",
    "................",
), {"N": 0xC93, "n": 0x962, "W": 0xFFF, "K": 0x000})

_sprite("podadora", (
    "................",
    "................",
    "..KK............",
    "...KK...........",
    "....KK..........",
    ".....KK.........",
    "......RRRRRRR...",
    ".....RRRRRRRRR..",
    "....RRRRRRRRRRR.",
    "....RRWWRRRRRRR.",
    "....RRRRRRRRRRR.",
    "....GGGGGGGGGGG.",
    "...KKK.....KKK..",
    "...KKK.....KKK..",
    "................",
    "................",
), {"K": 0x222, "R": 0xD22, "W": 0xFFF, "G": 0x999})
