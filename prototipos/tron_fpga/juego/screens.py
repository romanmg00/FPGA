"""Welcome/Pause viewer layer, using a small monochrome glyph bank.

One 8x8 cell per glyph, padded to 32 entries (2048 bits). Integer scaling,
opaque rectangles and RGB444 colours avoid system fonts and alpha blending.
This is a PC rendering reference; its ROM and timing are not implemented HDL.
"""

import pygame

from model import IDLE
from model.params import SCREEN_W

from .rgb444 import expand

SCREEN_FONT_BITS = 32 * 8 * 8
PANEL = (256, 176, 768, 432)

# Five lit columns in an 8x8 glyph cell; bit 4 is the leftmost column.
GLYPHS = {
    " ": (0, 0, 0, 0, 0, 0, 0),
    "A": (14, 17, 17, 31, 17, 17, 17),
    "B": (30, 17, 17, 30, 17, 17, 30),
    "C": (14, 17, 16, 16, 16, 17, 14),
    "D": (30, 17, 17, 17, 17, 17, 30),
    "E": (31, 16, 16, 30, 16, 16, 31),
    "F": (31, 16, 16, 30, 16, 16, 16),
    "G": (14, 17, 16, 23, 17, 17, 15),
    "H": (17, 17, 17, 31, 17, 17, 17),
    "I": (31, 4, 4, 4, 4, 4, 31),
    "J": (7, 2, 2, 2, 18, 18, 12),
    "K": (17, 18, 20, 24, 20, 18, 17),
    "L": (16, 16, 16, 16, 16, 16, 31),
    "M": (17, 27, 21, 21, 17, 17, 17),
    "N": (17, 25, 21, 19, 17, 17, 17),
    "O": (14, 17, 17, 17, 17, 17, 14),
    "P": (30, 17, 17, 30, 16, 16, 16),
    "Q": (14, 17, 17, 17, 21, 18, 13),
    "R": (30, 17, 17, 30, 20, 18, 17),
    "S": (15, 16, 16, 14, 1, 1, 30),
    "T": (31, 4, 4, 4, 4, 4, 4),
    "U": (17, 17, 17, 17, 17, 17, 14),
    "V": (17, 17, 17, 17, 17, 10, 4),
    "W": (17, 17, 17, 21, 21, 21, 10),
    "X": (17, 17, 10, 4, 10, 17, 17),
    "Y": (17, 17, 10, 4, 4, 4, 4),
    "Z": (31, 1, 2, 4, 8, 16, 31),
    "0": (14, 17, 19, 21, 25, 17, 14),
    "1": (4, 12, 4, 4, 4, 4, 14),
    "2": (14, 17, 1, 2, 4, 8, 31),
}


class ScreenRenderer:
    def __init__(self):
        self._labels = {}

    def _text(self, frame, text, y, scale, colour):
        key = (text, scale, colour)
        if key not in self._labels:
            # Leave three blank columns between glyphs; trim the last gap.
            label = pygame.Surface(((len(text) * 8 - 3) * scale, 8 * scale))
            label.set_colorkey((0, 0, 0))
            for index, char in enumerate(text):
                for row, bits in enumerate(GLYPHS[char]):
                    for column in range(5):
                        if bits & (1 << (4 - column)):
                            label.fill(expand(colour),
                                       ((index * 8 + column) * scale, row * scale, scale, scale))
            self._labels[key] = label
        label = self._labels[key]
        frame.blit(label, ((SCREEN_W - label.get_width()) // 2, y))

    def draw(self, frame, snap, palette):
        paused = snap["paused"]
        if not paused and snap["phase"] != IDLE:
            return
        pygame.draw.rect(frame, expand(palette["hud_bg"]), PANEL)
        pygame.draw.rect(frame, expand(palette["p1"]), PANEL, 2)
        x, y, width, height = PANEL
        frame.fill(expand(palette["p2"]), (x + 2, y + height - 4, width - 4, 2))
        white = palette["hud_fg"]
        self._text(frame, "PAUSED" if paused else "TRON", 224, 8 if paused else 16, palette["p1"])
        if paused:
            self._text(frame, "GAME STATE HELD", 336, 4, white)
            self._text(frame, "P TO RESUME", 416, 4, palette["p2"])
            self._text(frame, "SW0 DOWN TO RESUME", 488, 2, white)
        else:
            self._text(frame, "DESKTOP PLAYTEST", 368, 2, white)
            self._text(frame, "ENTER TO START", 416, 4, palette["p2"])
            self._text(frame, "ENTER BTNC   SPACE UART START", 480, 2, white)
            self._text(frame, "P1 WASD   P2 ARROWS   P PAUSE", 528, 2, white)
