"""HUD digit fonts and icons as 1-bit ROM images (objective H2).

A glyph is drawn at an integer scale. A power-of-two scale is a bit slice
of the address (drop low bits), so the ROM holds only the small glyph; any
other scale needs counters or a divider and is flagged by the viewer.
The HUD colour comes from the Player colour, not the ROM.
"""

from .art import Canvas

# --- Seven-segment style: 8 x 16 glyphs ------------------------------------

_SEGMENTS = {          # segment -> (col0, row0, col1, row1), exclusive ends
    "a": (1, 0, 7, 2), "b": (6, 1, 8, 8), "c": (6, 8, 8, 15),
    "d": (1, 14, 7, 16), "e": (0, 8, 2, 15), "f": (0, 1, 2, 8), "g": (1, 7, 7, 9),
}
_DIGIT_SEGMENTS = ("abcdef", "bc", "abged", "abgcd", "fgbc",
                   "afgcd", "afgedc", "abc", "abcdefg", "abcdfg")


def _seg_glyph(digit: int) -> list:
    rows = [[0] * 8 for _ in range(16)]
    for s in _DIGIT_SEGMENTS[digit]:
        c0, r0, c1, r1 = _SEGMENTS[s]
        for r in range(r0, r1):
            for c in range(c0, c1):
                rows[r][c] = 1
    return rows


# --- Block style: 4 x 8 glyphs ---------------------------------------------

_BLOCK = (
    ("####", "#..#", "#..#", "#..#", "#..#", "#..#", "#..#", "####"),
    ("..#.", ".##.", "..#.", "..#.", "..#.", "..#.", "..#.", ".###"),
    ("####", "...#", "...#", "####", "#...", "#...", "#...", "####"),
    ("####", "...#", "...#", ".###", "...#", "...#", "...#", "####"),
    ("#..#", "#..#", "#..#", "####", "...#", "...#", "...#", "...#"),
    ("####", "#...", "#...", "####", "...#", "...#", "...#", "####"),
    ("####", "#...", "#...", "####", "#..#", "#..#", "#..#", "####"),
    ("####", "...#", "...#", "..#.", ".#..", ".#..", ".#..", ".#.."),
    ("####", "#..#", "#..#", "####", "#..#", "#..#", "#..#", "####"),
    ("####", "#..#", "#..#", "####", "...#", "...#", "...#", "####"),
)


def _block_glyph(digit: int) -> list:
    return [[1 if ch == "#" else 0 for ch in row] for row in _BLOCK[digit]]


class Font:
    def __init__(self, name, glyph_w, glyph_h, glyphs, scale=1):
        self.name = name
        self.glyph_w = glyph_w
        self.glyph_h = glyph_h
        self.scale = scale
        self.glyphs = glyphs           # 10 glyphs, each rows of 0/1

    def at_height(self, px: int) -> "Font":
        """The same ROM shown `px` tall (integer scale)."""
        return Font(self.name, self.glyph_w, self.glyph_h, self.glyphs, px // self.glyph_h)

    @property
    def scale_is_power_of_two(self) -> bool:
        return self.scale & (self.scale - 1) == 0

    @property
    def rom_bits(self) -> int:
        return 10 * self.glyph_w * self.glyph_h

    @property
    def shown_w(self) -> int:
        return self.glyph_w * self.scale

    @property
    def shown_h(self) -> int:
        return self.glyph_h * self.scale


FONTS = {
    "seg": Font("seg", 8, 16, [_seg_glyph(d) for d in range(10)]),
    "block": Font("block", 4, 8, [_block_glyph(d) for d in range(10)]),
}


# --- Icons: 16 x 16, 1 bit ------------------------------------------------

ICON_PX = 16


def _icon(draw) -> list:
    c = Canvas(ICON_PX, 0)
    draw(c)
    return [[1 if w else 0 for w in row] for row in c.px]


def _life(c):
    c.polygon([(0.5, 0.05), (0.95, 0.5), (0.5, 0.95), (0.05, 0.5)], 1)


def _life_lost(c):
    _life(c)
    c.polygon([(0.5, 0.25), (0.75, 0.5), (0.5, 0.75), (0.25, 0.5)], 0)


def _play(c):
    c.polygon([(0.2, 0.1), (0.9, 0.5), (0.2, 0.9)], 1)


def _crown(c):
    c.polygon([(0.05, 0.85), (0.05, 0.25), (0.3, 0.55), (0.5, 0.15),
               (0.7, 0.55), (0.95, 0.25), (0.95, 0.85)], 1)


ICONS = {
    "life": _icon(_life),
    "life_lost": _icon(_life_lost),
    "play": _icon(_play),
    "crown": _icon(_crown),
}

ICON_ROM_BITS = len(ICONS) * ICON_PX * ICON_PX
