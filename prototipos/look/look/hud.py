"""HUD candidates: Points (2 digits) and Lives (pips) per Player, plus icons.

Each HUD element is a fixed box on screen holding one glyph or icon, so the
hardware needs one box comparator per element plus a font/icon ROM read.
The HUD layer is drawn last (on top), in Player colours. No text: digits
and icons only (agreed for L1, fits the planned digit font ROM).
"""

import pygame

from model import CRASH, MATCH_OVER, READY

from .font import FONTS, ICON_PX, ICONS
from .rgb444 import expand, halve, lerp

GAP = 4
BLINK_FRAMES = 16          # on/off half-period while blinking


def digit_font(look):
    """neon and chrome are colour treatments of the seven-segment glyphs."""
    return FONTS["block" if look.font == "block" else "seg"].at_height(look.digit_px)


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


def _blink_on(frames: int) -> bool:
    return (frames // BLINK_FRAMES) % 2 == 0


class Element:
    """One box: a digit of a Player's Points, a Life pip, or a state icon."""

    def __init__(self, kind, x, y, player=None, index=0):
        self.kind = kind            # "points", "life", "state"
        self.x, self.y = x, y
        self.player = player
        self.index = index          # digit position (0 = tens) or pip number


def _group(player, x, y, font, vertical_pips, mirror):
    """Points digits then three Life pips, optionally mirrored for P2."""
    dw, dh = font.shown_w, font.shown_h
    pts_w = 2 * dw + GAP
    els = []
    if not vertical_pips:
        pips_w = 3 * ICON_PX + 2 * GAP
        total = pts_w + 2 * GAP + pips_w
        x0 = x - total if mirror else x
        if mirror:                          # P2 reads [pips][digits] up to x
            px, ix = x0 + pips_w + 2 * GAP, x0
        else:
            px, ix = x0, x0 + pts_w + 2 * GAP
        for d in range(2):
            els.append(Element("points", px + d * (dw + GAP), y, player, d))
        for k in range(3):
            els.append(Element("life", ix + k * (ICON_PX + GAP), y + (dh - ICON_PX) // 2, player, k))
    else:
        for d in range(2):
            els.append(Element("points", x + d * (dw + GAP), y, player, d))
        cx = x + (pts_w - ICON_PX) // 2
        for k in range(3):
            els.append(Element("life", cx, y + dh + 2 * GAP + k * (ICON_PX + GAP), player, k))
    return els


def layout(name: str, font) -> list:
    dh = font.shown_h
    if name == "top":                      # band below the 10 px border
        y = 10 + 3
        els = _group(0, 24, y, font, False, False) + _group(1, 1280 - 24, y, font, False, True)
        els.append(Element("state", 640 - ICON_PX // 2, 10 + (38 - ICON_PX) // 2))
        return els
    if name == "sides":                    # 96 px columns
        pts_w = 2 * font.shown_w + GAP
        x1 = 10 + (86 - pts_w) // 2
        x2 = 1280 - 96 + (86 - pts_w) // 2
        els = _group(0, x1, 24, font, True, False) + _group(1, x2, 24, font, True, False)
        sy = 24 + dh + 2 * GAP + 3 * (ICON_PX + GAP) + 3 * GAP
        els.append(Element("state", 10 + (86 - ICON_PX) // 2, sy, 0))
        els.append(Element("state", 1280 - 96 + (86 - ICON_PX) // 2, sy, 1))
        return els
    if name == "corners":                  # over the Arena; the state icon
        y = 24                             # shows only while no Bike moves
        els = _group(0, 24, y, font, False, False) + _group(1, 1280 - 24, y, font, False, True)
        els.append(Element("state", 640 - ICON_PX // 2, y + (dh - ICON_PX) // 2))
        return els
    raise ValueError(name)


def element_size(el, font) -> tuple:
    if el.kind == "points":
        return font.shown_w, font.shown_h
    return ICON_PX, ICON_PX


def backing_boxes(name: str, font) -> list:
    """Opaque boxes behind the HUD; only the overlay layout needs them."""
    if name != "corners":
        return []
    boxes = []
    for player in (0, 1):
        els = [e for e in layout(name, font) if e.player == player]
        x0 = min(e.x for e in els) - GAP
        y0 = min(e.y for e in els) - GAP
        x1 = max(e.x + element_size(e, font)[0] for e in els) + GAP
        y1 = max(e.y + element_size(e, font)[1] for e in els) + GAP
        boxes.append(pygame.Rect(x0, y0, x1 - x0, y1 - y0))
    return boxes


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

    def draw(self, frame, look, palette, snap):
        font = digit_font(look)
        for box in backing_boxes(look.hud, font):
            frame.fill(expand(palette["hud_bg"]), box)
        colours = (palette["p1"], palette["p2"])
        phase, frames = snap["phase"], snap["phase_frames"]
        for el in layout(look.hud, font):
            if el.kind == "points":
                if phase == CRASH and snap["crashed"][el.player] and not _blink_on(frames):
                    continue
                value = snap["points"][el.player]
                digit = value // 10 if el.index == 0 else value % 10
                col = colours[el.player]
                if look.font == "neon":            # unlit segments glow faintly
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
        if phase == READY and _blink_on(snap["phase_frames"]):
            return self._bitmap("play", ICONS["play"], 1, palette["hud_fg"])
        if phase == MATCH_OVER:
            winner = snap["winner"]
            if el.player is not None and winner is not None and el.player != winner:
                return None
            colour = palette["hud_fg"] if winner is None else colours[winner]
            return self._bitmap("crown", ICONS["crown"], 1, colour)
        return None
