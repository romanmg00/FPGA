"""HUD candidate (objective H2): Points (2 digits) and Lives (pips) per
Player, plus a state icon, inside the agreed 64 px band above the Arena.

The HUD follows the core in the agreed scope. Each element is a fixed box
on screen holding one glyph or icon, so the hardware needs one box
comparator per element plus a font/icon ROM read. Digits start at the
agreed 32 px height. The layer is drawn in Player colours, below the white
border.
"""

import pygame

from model import CRASH, DRAW, IDLE, MATCH_OVER, READY
from model.params import BORDER_PX, SCREEN_W

from .font import FONTS, ICON_PX, ICONS
from .rgb444 import expand, halve, lerp

GAP = 4
BLINK_TICKS = 16           # on/off half-period while blinking
DIGIT_PX = 32              # agreed starting text height


def digit_font(look):
    """neon and chrome are colour treatments of the seven-segment glyphs."""
    return FONTS["block" if look.font == "block" else "seg"].at_height(DIGIT_PX)


def chrome_rows(colour: int, h: int) -> tuple:
    """80s chrome lettering: white to colour on top, a dark split line,
    colour to half colour below. A per-glyph-row colour LUT in hardware."""
    rows = []
    for r in range(h):
        t = r / (h - 1)
        if r == h // 2:
            rows.append(halve(halve(colour)))
        elif r < h // 2:
            rows.append(lerp(0xFFF, colour, t * 2))
        else:
            rows.append(lerp(colour, halve(colour), (t - 0.5) * 2))
    return tuple(rows)


def _blink_on(ticks: int) -> bool:
    return (ticks // BLINK_TICKS) % 2 == 0


class Element:
    """One box: a digit of a Player's Points, a Life pip, or a state icon."""

    def __init__(self, kind, x, y, player=None, index=0):
        self.kind = kind            # "points", "life", "state"
        self.x, self.y = x, y
        self.player = player
        self.index = index          # digit position (0 = tens) or pip number


def _group(player, x, y, font, mirror):
    """Points digits then three Life pips, mirrored for P2."""
    dw, dh = font.shown_w, font.shown_h
    pts_w = 2 * dw + GAP
    pips_w = 3 * ICON_PX + 2 * GAP
    total = pts_w + 2 * GAP + pips_w
    x0 = x - total if mirror else x
    if mirror:                              # P2 reads [pips][digits] up to x
        px, ix = x0 + pips_w + 2 * GAP, x0
    else:
        px, ix = x0, x0 + pts_w + 2 * GAP
    els = [Element("points", px + d * (dw + GAP), y, player, d) for d in range(2)]
    els += [Element("life", ix + k * (ICON_PX + GAP), y + (dh - ICON_PX) // 2, player, k)
            for k in range(3)]
    return els


def layout(font, band_px: int) -> list:
    """Elements in the HUD band, vertically centred below the white border."""
    y = BORDER_PX + (band_px - BORDER_PX - font.shown_h) // 2
    els = _group(0, 24, y, font, False) + _group(1, SCREEN_W - 24, y, font, True)
    els.append(Element("state", SCREEN_W // 2 - ICON_PX // 2, y + (font.shown_h - ICON_PX) // 2))
    return els


class HudRenderer:
    def __init__(self):
        self._glyphs = {}

    def _bitmap(self, key, rows, scale, colour):
        """colour is one word, or a tuple with one word per glyph row."""
        k = (key, scale, colour)
        if k not in self._glyphs:
            h, w = len(rows), len(rows[0])
            surf = pygame.Surface((w * scale, h * scale))
            surf.set_colorkey((0, 0, 0))
            for r in range(h):
                rgb = expand(colour[r] if isinstance(colour, tuple) else colour)
                for c in range(w):
                    if rows[r][c]:
                        surf.fill(rgb, (c * scale, r * scale, scale, scale))
            self._glyphs[k] = surf
        return self._glyphs[k]

    def draw(self, frame, look, palette, snap, band_px):
        font = digit_font(look)
        colours = (palette["p1"], palette["p2"])
        phase, ticks = snap["phase"], snap["phase_ticks"]
        for el in layout(font, band_px):
            if el.kind == "points":
                if phase == CRASH and snap["crashed"][el.player] and not _blink_on(ticks):
                    continue
                value = snap["points"][el.player]
                digit = value // 10 if el.index == 0 else value % 10
                col = colours[el.player]
                if look.font == "neon":            # unlit segments glow faintly; in
                    # hardware the ghost is the union of the segment rectangles
                    # (comparators on glyph x/y), not a second ROM read
                    ghost = self._bitmap(("d", font.name, 8), font.glyphs[8], font.scale,
                                         halve(halve(col)))
                    frame.blit(ghost, (el.x, el.y))
                elif look.font == "chrome":
                    col = chrome_rows(col, font.glyph_h)
                bmp = self._bitmap(("d", font.name, digit), font.glyphs[digit], font.scale, col)
            elif el.kind == "life":
                name = "life" if el.index < snap["lives"][el.player] else "life_lost"
                bmp = self._bitmap(name, ICONS[name], 1, colours[el.player])
            else:
                bmp = self._state_icon(el, snap, palette, colours)
                if bmp is None:
                    continue
            frame.blit(bmp, (el.x, el.y))

    def _state_icon(self, el, snap, palette, colours):
        phase = snap["phase"]
        if phase in (IDLE, READY) and _blink_on(snap["phase_ticks"]):
            return self._bitmap("play", ICONS["play"], 1, palette["hud_fg"])
        if phase == MATCH_OVER:                 # winner's colour; white for a Draw
            result = snap["result"]
            colour = palette["hud_fg"] if result == DRAW else colours[result]
            return self._bitmap("crown", ICONS["crown"], 1, colour)
        return None
