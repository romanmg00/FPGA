"""Welcome/Pause viewer layer in the look of the design, using a small
monochrome glyph bank.

One 8x8 cell per glyph, padded to 32 entries (2048 bits). Integer scaling,
opaque rectangles and RGB444 colours avoid system fonts and alpha blending.
The scene stays visible: the welcome screen puts a sunset-shaded title above
the sun and the instructions in a neon band below it; the pause screen
halves the Arena's colours (a shift, like the crash flash) under one neon
band near the top, clear of the Bikes' starting row. This is a PC rendering
reference; its ROM and timing are not implemented HDL.
"""

import pygame

from model import IDLE
from model.params import SCREEN_H, SCREEN_W

from .rgb444 import expand, halve, lerp

SCREEN_FONT_BITS = 32 * 8 * 8
TITLE_ROWS = 56            # title shading LUT: 7 glyph rows x 8 sub-rows
TITLE_LUT_WIDTH = 13       # 12-bit colour + 1 cut bit
BLINK_FRAMES = 32          # prompt colour swaps on frame[5]

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

# DESKTOP PLAYTEST ONLY: these lines name PC keys (Enter, Space, P, WASD,
# arrows) and the desktop's swapped Player keys. Do not copy them into the
# FPGA build. On the board, per the agreed specification, Start is BTNC or
# Space/Enter on the UART controller, SW0 pauses, P1 steers with the board's
# direction buttons and P2 with WASD over UART. Board screen text is not
# designed yet.
DESKTOP_TEXT = {
    "subtitle": "DESKTOP PLAYTEST",
    "start": "PRESS ENTER TO START",
    "start_keys": "ENTER BTNC   SPACE UART START",
    "resume": "P OR SW0 DOWN TO RESUME",
}

# (y, scale) of each screen's title, and (y, height) of its neon band.
WELCOME_TITLE = (104, 16)
WELCOME_BAND = (616, 136)
PAUSE_TITLE = (120, 8)   # top of the Arena: Bikes start on its middle row
PAUSE_BAND = (104, 136)


def title_rows(pal) -> tuple:
    """Sunset shading for titles, one entry per eighth of a glyph row: the
    sun's colours top to bottom, with cut stripes (None) that widen towards
    the bottom like the sun's. A 56 x 13-bit row LUT in hardware."""
    rows = []
    for t in range(TITLE_ROWS):
        k = t - TITLE_ROWS // 2
        cut = k >= 2 and (k - 2) % 8 < 1 + (k - 2) // 10
        rows.append(None if cut else lerp(pal["sun_hi"], pal["sun_lo"], t / (TITLE_ROWS - 1)))
    return tuple(rows)


def dim(frame, rect) -> None:
    """Halve each 4-bit channel inside rect: (n >> 1) per channel, a shift
    of the colour composed so far, not a blend of two layers."""
    p = pygame.surfarray.pixels2d(frame.subsurface(rect))   # 0x00RRGGBB, n * 17
    p[...] = (((p >> 4) & 0x0F0F0F) >> 1 & 0x070707) * 0x11
    del p


class ScreenRenderer:
    def __init__(self, geom):
        c = geom.cell_px
        self.x0, self.x1 = geom.x0 * c, geom.x1 * c
        self.arena = pygame.Rect(0, geom.hud_px, SCREEN_W, SCREEN_H - geom.hud_px)
        self._labels = {}

    def _label(self, text, scale, colour):
        """colour is one word, or a tuple with one word (or None for a cut)
        per entry of the title LUT."""
        key = (text, scale, colour)
        if key not in self._labels:
            # Leave three blank columns between glyphs; trim the last gap.
            label = pygame.Surface(((len(text) * 8 - 3) * scale, 7 * scale))
            label.set_colorkey((0, 0, 0))
            for index, char in enumerate(text):
                for row, bits in enumerate(GLYPHS[char]):
                    for column in range(5):
                        if not bits & (1 << (4 - column)):
                            continue
                        for y in range(row * scale, (row + 1) * scale):
                            word = colour[y * 8 // scale] if isinstance(colour, tuple) else colour
                            if word is not None:
                                label.fill(expand(word), ((index * 8 + column) * scale, y, scale, 1))
            self._labels[key] = label
        return self._labels[key]

    def _line(self, frame, parts, y, scale):
        """Centred text; parts are (text, colour) runs, i.e. a colour per
        character position in the string ROM."""
        labels = [self._label(text, scale, colour) for text, colour in parts]
        gap = 3 * scale                      # the gap trimmed from each run
        x = (SCREEN_W - sum(lb.get_width() for lb in labels) - gap * (len(labels) - 1)) // 2
        for lb in labels:
            frame.blit(lb, (x, y))
            x += lb.get_width() + gap

    def _title(self, frame, text, y, scale, pal):
        """Sunset-shaded title over a neon drop shadow (a second read of the
        same glyph ROM, offset by a quarter of a glyph pixel)."""
        off = scale // 4
        shadow = self._label(text, scale, pal["wall_line"])
        x = (SCREEN_W - shadow.get_width()) // 2
        frame.blit(shadow, (x + off, y + off))
        frame.blit(self._label(text, scale, title_rows(pal)), (x, y))

    def _band(self, frame, y, h, pal):
        """Opaque band across the Arena with the neon Wall's tube on its top
        and bottom edges: 2 px glow outside, 2 px bright, 1 px glow inside."""
        x, w = self.x0 + 1, self.x1 - self.x0 - 2
        frame.fill(expand(pal["hud_bg"]), (x, y, w, h))
        glow, line = expand(halve(pal["wall_line"])), expand(pal["wall_line"])
        for dy, colour in ((-2, glow), (-1, glow), (0, line), (1, line), (2, glow)):
            frame.fill(colour, (x, y + dy, w, 1))
            frame.fill(colour, (x, y + h - 1 - dy, w, 1))

    def draw(self, frame, snap, pal, video_frame=0):
        paused = snap["paused"]
        if not paused and snap["phase"] != IDLE:
            return
        white, p1, p2 = pal["hud_fg"], pal["p1"], pal["p2"]
        if paused:
            dim(frame, self.arena)
            self._band(frame, *PAUSE_BAND, pal)
            self._title(frame, "PAUSED", *PAUSE_TITLE, pal)
            self._line(frame, [(DESKTOP_TEXT["resume"], white)], 192, 2)
            self._line(frame, [("GAME STATE HELD", halve(white))], 216, 2)
            return
        self._title(frame, "TRON", *WELCOME_TITLE, pal)
        self._line(frame, [(DESKTOP_TEXT["subtitle"], pal["wall_line"])], 236, 2)
        y = WELCOME_BAND[0]
        self._band(frame, *WELCOME_BAND, pal)
        prompt = white if (video_frame // BLINK_FRAMES) % 2 == 0 else pal["wall_line"]
        self._line(frame, [(DESKTOP_TEXT["start"], prompt)], y + 22, 4)
        self._line(frame, [(DESKTOP_TEXT["start_keys"], white)], y + 74, 2)
        # Desktop playtest only, like DESKTOP_TEXT: desktop keys, Players swapped.
        self._line(frame, [("P1", p1), (" WASD   ", white), ("P2", p2),
                           (" ARROWS   P PAUSE", white)], y + 102, 2)
