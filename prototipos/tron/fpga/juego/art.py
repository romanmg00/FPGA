"""Procedural candidate art: Bikes and Rewards as ROM-ready 12-bit images.

Shapes are described in unit coordinates (0..1) and sampled at pixel
centres, so one description gives 16, 32 and 64 px versions. Every image is
square, points UP, uses black 000 as transparent, green 0F0 as the tint
key and dark green 080 as the dim tint key (half the tint, for glow
halos; an L2 proposal), and is returned row by row, the order png2coe.py writes into a .coe.
No pygame or Pillow here; tools/make_candidate_art.py saves them as PNGs.
"""

import math

from .rgb444 import DIM_TINT_KEY, NEAR_BLACK, TINT_KEY, lerp

T = TINT_KEY
DT = DIM_TINT_KEY
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
                self.px[j][i] = c(u, v) if callable(c) else c

    def ellipse(self, cx, cy, rx, ry, c):
        for i, j, u, v in self._centres():
            if ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1.0:
                self.px[j][i] = c(u, v) if callable(c) else c

    def polygon(self, pts, c):
        for i, j, u, v in self._centres():
            if _inside(u, v, pts):
                self.px[j][i] = c(u, v) if callable(c) else c

    def glow(self, colour=None) -> None:
        """Halo hugging the silhouette: every transparent pixel within
        `radius` (1 px, 2 px from 64 px art) of a drawn pixel gets `colour`."""
        colour = DT if colour is None else colour
        s, r = self.size, 2 if self.size >= 64 else 1
        drawn = [[w != 0x000 for w in row] for row in self.px]
        for j in range(s):
            for i in range(s):
                if drawn[j][i]:
                    continue
                if any(drawn[jj][ii]
                       for jj in range(max(0, j - r), min(s, j + r + 1))
                       for ii in range(max(0, i - r), min(s, i + r + 1))):
                    self.px[j][i] = colour

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


def bike_synth(size: int) -> list:
    """80s light cycle, top-down: glowing wheel rings, gunmetal body shaded
    like a cylinder, light lines down the sides, rider with a tinted visor."""
    gunmetal = lambda u, v: lerp(0x99B, 0x224, min(1.0, abs(u - 0.5) * 3.2))
    c = Canvas(size)
    c.ellipse(0.5, 0.17, 0.18, 0.15, T)                       # front wheel ring
    c.ellipse(0.5, 0.17, 0.10, 0.08, 0x112)
    c.ellipse(0.5, 0.82, 0.21, 0.17, T)                       # rear wheel ring
    c.ellipse(0.5, 0.82, 0.12, 0.09, 0x112)
    c.polygon([(0.38, 0.24), (0.62, 0.24), (0.71, 0.44), (0.71, 0.74),
               (0.60, 0.84), (0.40, 0.84), (0.29, 0.74), (0.29, 0.44)], gunmetal)
    c.rect(0.29, 0.44, 0.34, 0.75, T)                         # side light lines
    c.rect(0.66, 0.44, 0.71, 0.75, T)
    c.rect(0.46, 0.24, 0.54, 0.40, T)                         # nose light
    c.ellipse(0.5, 0.63, 0.11, 0.09, 0x223)                   # rider's back
    c.ellipse(0.5, 0.51, 0.12, 0.12, NEAR_BLACK)              # helmet
    c.ellipse(0.5, 0.47, 0.09, 0.04, T)                       # visor
    c.ellipse(0.5, 0.17, 0.03, 0.03, 0xBCF)                   # hub glints
    c.ellipse(0.5, 0.82, 0.03, 0.03, 0xBCF)
    c.rect(0.42, 0.00, 0.58, 0.03, WHITE)                     # headlight
    c.rect(0.42, 0.96, 0.58, 0.99, 0xF24)                     # tail light
    c.glow()
    return c.words()


def bike_racer(size: int) -> list:
    """80s wedge racer: tinted hull edge, chrome deck, dark canopy, racing
    stripes and two white-hot thrusters."""
    chrome = lambda u, v: lerp(0xDDF, 0x335, min(1.0, abs(u - 0.5) * 2.6 + max(0.0, v - 0.55)))
    c = Canvas(size)
    c.polygon([(0.5, 0.04), (0.74, 0.22), (0.85, 0.70), (0.75, 0.94),
               (0.25, 0.94), (0.15, 0.70), (0.26, 0.22)], T)   # hull edge
    c.polygon([(0.5, 0.12), (0.66, 0.27), (0.75, 0.68), (0.67, 0.87),
               (0.33, 0.87), (0.25, 0.68), (0.34, 0.27)], chrome)
    c.rect(0.39, 0.56, 0.44, 0.86, T)                         # racing stripes
    c.rect(0.56, 0.56, 0.61, 0.86, T)
    c.ellipse(0.5, 0.40, 0.10, 0.15, 0x112)                   # canopy
    c.ellipse(0.47, 0.34, 0.03, 0.05, 0xCEF)                  # canopy glint
    c.rect(0.30, 0.88, 0.42, 0.96, WHITE)                     # thrusters
    c.rect(0.58, 0.88, 0.70, 0.96, WHITE)
    c.glow()
    return c.words()


BIKE_STYLES = {"synth": bike_synth, "racer": bike_racer, "cycle": bike_cycle,
               "arrow": bike_arrow}


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


def reward_neon_gem(size: int) -> list:
    c = Canvas(size)
    c.polygon([(0.5, 0.0), (1.0, 0.5), (0.5, 1.0), (0.0, 0.5)], DT)
    c.polygon([(0.5, 0.12), (0.88, 0.5), (0.5, 0.88), (0.12, 0.5)], T)
    c.polygon([(0.5, 0.32), (0.68, 0.5), (0.5, 0.68), (0.32, 0.5)], WHITE)
    return c.words()


def reward_neon_star(size: int) -> list:
    def star(r_out, r_in):
        pts = []
        for k in range(10):
            r = r_out if k % 2 == 0 else r_in
            a = -math.pi / 2 + k * math.pi / 5
            pts.append((0.5 + r * math.cos(a), 0.53 + r * math.sin(a)))
        return pts
    c = Canvas(size)
    c.ellipse(0.5, 0.52, 0.48, 0.48, DT)
    c.polygon(star(0.46, 0.21), T)
    c.ellipse(0.5, 0.53, 0.10, 0.10, WHITE)
    return c.words()


# look name -> (art for the small Reward, art for the big Reward).
# A look that uses one function for both needs one shared ROM.
REWARD_LOOKS = {
    "gem": (reward_gem, reward_gem),
    "orb": (reward_orb, reward_orb),
    "gem+star": (reward_gem, reward_star),
    "neon": (reward_neon_gem, reward_neon_star),
}
