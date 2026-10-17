"""Procedural candidate art: Bikes and Rewards as ROM-ready 12-bit images.

Shapes are described in unit coordinates (0..1) and sampled at pixel
centres, so one description gives 16, 32 and 64 px versions. Every image is
square, points UP, uses black 000 as transparent and green 0F0 as the tint
key, and is returned row by row, the order png2coe.py writes into a .coe.
No pygame or Pillow here; tools/make_candidate_art.py saves them as PNGs.
"""

import math

from .rgb444 import NEAR_BLACK, TINT_KEY

T = TINT_KEY
DARK = 0x333
GREY = 0x666
LIGHT = 0xCCC
WHITE = 0xFFF


class Canvas:
    def __init__(self, size: int, fill: int = 0x000):
        self.size = size
        self.px = [[fill] * size for _ in range(size)]

    def _centres(self):
        s = self.size
        for j in range(s):
            for i in range(s):
                yield i, j, (i + 0.5) / s, (j + 0.5) / s

    def rect(self, x0, y0, x1, y1, c):
        for i, j, u, v in self._centres():
            if x0 <= u < x1 and y0 <= v < y1:
                self.px[j][i] = c

    def ellipse(self, cx, cy, rx, ry, c):
        for i, j, u, v in self._centres():
            if ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1.0:
                self.px[j][i] = c

    def polygon(self, pts, c):
        for i, j, u, v in self._centres():
            if _inside(u, v, pts):
                self.px[j][i] = c

    def words(self) -> list:
        return [w for row in self.px for w in row]


def _inside(u, v, pts) -> bool:
    inside = False
    n = len(pts)
    for k in range(n):
        (x0, y0), (x1, y1) = pts[k], pts[(k + 1) % n]
        if (y0 > v) != (y1 > v) and u < x0 + (v - y0) * (x1 - x0) / (y1 - y0):
            inside = not inside
    return inside


# --- Bikes ---------------------------------------------------------------

def bike_cycle(size: int) -> list:
    """Top-down light cycle: tinted capsule shell, wheel hubs, rider."""
    c = Canvas(size)
    c.ellipse(0.5, 0.5, 0.31, 0.49, T)            # shell
    c.ellipse(0.5, 0.5, 0.20, 0.40, DARK)
    c.ellipse(0.5, 0.21, 0.13, 0.12, GREY)        # front hub
    c.ellipse(0.5, 0.80, 0.15, 0.13, GREY)        # rear hub
    c.ellipse(0.5, 0.80, 0.05, 0.05, T)
    c.ellipse(0.5, 0.51, 0.12, 0.15, NEAR_BLACK)  # rider
    c.ellipse(0.5, 0.44, 0.08, 0.04, LIGHT)       # visor
    c.rect(0.42, 0.00, 0.58, 0.05, WHITE)         # headlight
    return c.words()


def bike_arrow(size: int) -> list:
    """Delta shape: tinted hull edge, grey core, white cockpit and exhaust."""
    c = Canvas(size)
    c.polygon([(0.5, 0.02), (0.95, 0.94), (0.5, 0.74), (0.05, 0.94)], T)
    c.polygon([(0.5, 0.22), (0.76, 0.80), (0.5, 0.66), (0.24, 0.80)], GREY)
    c.ellipse(0.5, 0.46, 0.07, 0.12, WHITE)
    c.rect(0.44, 0.70, 0.56, 0.80, LIGHT)
    return c.words()


BIKE_STYLES = {"cycle": bike_cycle, "arrow": bike_arrow}


# --- Rewards (tinted per kind with the palette's Reward colours) ----------

def reward_gem(size: int) -> list:
    c = Canvas(size)
    c.polygon([(0.5, 0.04), (0.96, 0.5), (0.5, 0.96), (0.04, 0.5)], T)
    c.polygon([(0.5, 0.30), (0.70, 0.5), (0.5, 0.70), (0.30, 0.5)], WHITE)
    return c.words()


def reward_orb(size: int) -> list:
    c = Canvas(size)
    c.ellipse(0.5, 0.5, 0.46, 0.46, T)
    c.ellipse(0.5, 0.5, 0.30, 0.30, 0x000)
    c.ellipse(0.5, 0.5, 0.14, 0.14, WHITE)
    return c.words()


def reward_star(size: int) -> list:
    pts = []
    for k in range(10):
        r = 0.48 if k % 2 == 0 else 0.20
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((0.5 + r * math.cos(a), 0.53 + r * math.sin(a)))
    c = Canvas(size)
    c.polygon(pts, T)
    c.ellipse(0.5, 0.53, 0.09, 0.09, WHITE)
    return c.words()


# look name -> (art for the small Reward, art for the big Reward).
# A look that uses one function for both needs one shared ROM.
REWARD_LOOKS = {
    "gem": (reward_gem, reward_gem),
    "orb": (reward_orb, reward_orb),
    "gem+star": (reward_gem, reward_star),
}


def reward_rom_count(look: str) -> int:
    small, big = REWARD_LOOKS[look]
    return 1 if small is big else 2
