"""80s look effects, each one a function of pixel position, a frame counter
and game state, so drawcon can compute it while racing the beam.

The PC builds the static layers once per animation phase with NumPy; the
hardware would compute the same values pixel by pixel. HW_COST says what
each effect needs on the FPGA, for the panel.
"""

from math import isqrt

import numpy as np
import pygame

from model.params import BORDER_PX, SCREEN_H, SCREEN_W

from .rgb444 import expand, halve, lerp

W, H = SCREEN_W, SCREEN_H
XS = np.arange(W, dtype=np.int32)[:, None]      # surfarray indexing is [x, y]
YS = np.arange(H, dtype=np.int32)[None, :]

PHASES = 4                 # animation phase = frame_counter[4:3]
PHASE_FRAMES = 8
SKY_BAND = 16              # px of screen height per sky LUT entry (50 entries)
SUN_R = 160
SUN_RISE = 64              # sun centre sits this far above the horizon
FLOOR_K = 170              # floor perspective: column spacing at the bottom
FLOOR_Z = 92480            # floor perspective: row spacing at the bottom
FLOOR_SPACING = 32         # world units between floor lines
STRIPE_PERIOD = 64         # px along x+y between pulse stripes on Trails

HW_COST = {                # short enough for one panel line each
    "sky": "row LUT 50x12 b, index y[9:4]",
    "stars": "hash, 3 const mults (shift/add)",
    "sunset": "row LUT: half-width + colour",
    "neon grid": "x/y[4:0] tests, 4 pulse colours",
    "floor grid": "row LUT 1/d,lines,colour; 1 DSP",
    "neon Wall": "4 edge comparators",
    "neon Trail": "Cell-local x/y bit tests",
    "pulse Trail": "(x+y-2f) mod 64 < 6 -> c/4 + 12",
    "crash ring": "max(|dx|,|dy|) vs radius",
    "flash": "c/2+7 per channel, 4 frames",
    "scanlines": "y[0] ? c - c/4 : c",
    "Reward pulse": "4-entry tint table per kind",
    "Reward spin": "Heading = frame[4:3] (address)",
    "speed streaks": "rect compares vs head + Heading",
    "HUD": "box compares + font/icon ROM",
    "neon digits": "ghost = segment-area compares",
    "chrome digits": "row LUT 2 x 16 x 12 b",
}


def phase(frame: int) -> int:
    return (frame // PHASE_FRAMES) % PHASES


def _rgb(c12):
    return np.array(expand(c12), dtype=np.uint8)


def horizon_y(geom) -> int:
    """Screen row of the horizon: the Arena's middle, on a LUT band edge."""
    c = geom.cell_px
    return ((geom.y0 + geom.y1) * c // 2) // SKY_BAND * SKY_BAND


def sky_lut(pal, horizon) -> list:
    """One colour per 16-row band. horizon=None: one gradient, zenith (bg)
    to sky_low. Otherwise zenith -> horizon glow (bg2) above the horizon,
    floor colour -> zenith colour below it."""
    n = H // SKY_BAND
    if horizon is None:
        return [lerp(pal["bg"], pal["sky_low"], i / (n - 1)) for i in range(n)]
    out = []
    for i in range(n):
        y = i * SKY_BAND
        if y < horizon:
            out.append(lerp(pal["bg"], pal["bg2"], y / max(1, horizon - SKY_BAND)))
        else:
            out.append(lerp(pal["floor"], pal["bg"], (y - horizon) / max(1, H - horizon)))
    return out


def sun_rows_full(pal):
    """Whole sun centred in the Arena; cut stripes widen towards the bottom."""
    rows = []
    for dy in range(-SUN_R, SUN_R + 1):
        if dy > 0 and dy % 22 < 2 + (dy * 8) // SUN_R:
            continue
        w = isqrt(SUN_R * SUN_R - dy * dy)
        rows.append((dy, w, lerp(pal["sun_hi"], pal["sun_lo"], (dy + SUN_R) / (2 * SUN_R))))
    return rows


def sun_rows(pal):
    """Setting sun for the floor grid: (dy, half-width, colour) per lit row,
    dy from the sun's centre, cut at the horizon. Stripes widen downwards."""
    rows = []
    stripe_top = -SUN_R // 3
    for dy in range(-SUN_R, SUN_RISE):
        if dy >= stripe_top:
            k = dy - stripe_top
            gap = 2 + k * 7 // (SUN_RISE - stripe_top)
            if k % 16 < gap:
                continue
        w = isqrt(SUN_R * SUN_R - dy * dy)
        rows.append((dy, w, lerp(pal["sun_hi"], pal["sun_lo"], (dy + SUN_R) / (SUN_R + SUN_RISE))))
    return rows


def _star_hash():
    hx, hy = XS >> 1, YS >> 1                      # 2 x 2 px stars
    return ((hx * 0x2C9 + 7) ^ (hy * 0x1F3 + (hx >> 3))) * 0x3B & 0xFFFF


STAR_HASH = _star_hash()


def build_base(geom, look, pal, ph) -> pygame.Surface:
    """Everything below the Trails: sky, stars, sun, grid, Walls, HUD band,
    the handout's white border (the renderer draws it again on top).
    `ph` is the animation phase."""
    a = np.empty((W, H, 3), np.uint8)
    a[:] = _rgb(pal["wall"])
    c = geom.cell_px
    x0, y0, x1, y1 = geom.x0 * c, geom.y0 * c, geom.x1 * c, geom.y1 * c
    inner = np.zeros((W, H), bool)
    inner[x0:x1, y0:y1] = True

    floor = look.grid == "floor"
    horizon = horizon_y(geom) if floor else None
    if look.bg == "plain":
        a[inner] = _rgb(pal["bg"])
    else:
        lut = np.array([expand(v) for v in sky_lut(pal, horizon)], np.uint8)
        sky = np.broadcast_to(lut[YS[0] // SKY_BAND][None, :, :], (W, H, 3))
        a[inner] = sky[inner]

    sun = np.zeros((W, H), bool)
    if look.bg == "sunset":
        cx = (x0 + x1) // 2
        cy = horizon - SUN_RISE if floor else (y0 + y1) // 2
        for dy, w, col in (sun_rows(pal) if floor else sun_rows_full(pal)):
            y = cy + dy
            if y0 <= y < y1:
                xa, xb = max(x0, cx - w), min(x1, cx + w)
                a[xa:xb, y] = _rgb(col)
                sun[xa:xb, y] = True

    if look.bg in ("stars", "sunset"):
        h = STAR_HASH
        sky_only = YS < horizon if floor else True
        is_star = (((h >> 5) & 0x1FF) == 0) & inner & ~sun & sky_only
        dim = ((h >> 2) & 3) == ph                  # a quarter twinkle each phase
        a[is_star & ~dim] = _rgb(pal["star"])
        a[is_star & dim] = _rgb(halve(pal["star"]))

    _grid(a, inner, look.grid, c, pal, ph, horizon, (x0 + x1) // 2)
    if look.wall == "neon":
        _neon_wall(a, x0, y0, x1, y1, pal)

    a[:, :geom.hud_px] = _rgb(pal["hud_bg"])
    b, white = BORDER_PX, _rgb(pal["border"])
    a[:, :b] = white
    a[:, H - b:] = white
    a[:b, :] = white
    a[W - b:, :] = white
    return pygame.surfarray.make_surface(a)


def _grid(a, inner, style, c, pal, ph, horizon, cx):
    if style == "off":
        return
    if style == "floor":
        _floor(a, inner, pal, ph, horizon, cx)
        return
    if style == "neon":
        level = (0.45, 0.75, 1.0, 0.75)[ph]
        line = _rgb(lerp(pal["grid_glow"], pal["grid"], level))
        xm, ym = XS & 31, YS & 31
        halo = ((xm == 1) | (xm == 31) | (ym == 1) | (ym == 31)) & inner
        core = ((xm == 0) | (ym == 0)) & inner
        a[halo & ~core] = _rgb(pal["grid_glow"])
        a[core] = line
        return
    step = 32 if style == "32px" else c
    core = (((XS % step) == 0) | ((YS % step) == 0)) & inner
    a[core] = _rgb(pal["grid"])


def _floor(a, inner, pal, ph, horizon, cx):
    """80s perspective floor below the horizon. Row d below the horizon has
    depth FLOOR_Z / d; columns are (x - cx) * FLOOR_K / d in world units.
    A line is drawn where the world coordinate crosses a multiple of
    FLOOR_SPACING between neighbouring pixels. The rows scroll towards the
    viewer by a quarter spacing per phase."""
    d = np.arange(1, H - horizon + 1, dtype=np.int64)               # rows below
    inv = (FLOOR_K * 256) // d                                       # row LUT
    xs = np.arange(W + 1, dtype=np.int64) - cx
    u = (xs[:, None] * inv[None, :]) >> 8
    cell = np.floor_divide(u, FLOOR_SPACING)
    vline = cell[1:, :] != cell[:-1, :]                              # (W, rows)
    z = FLOOR_Z / d - ph * FLOOR_SPACING / PHASES
    zc = np.floor(z / FLOOR_SPACING)
    hline = np.append(zc[:-1] != zc[1:], False)                      # (rows,)
    near = d >= 6                                                    # no moire at the horizon
    lines = (vline | hline[None, :]) & near[None, :]
    rows = np.arange(horizon, H)
    shade = [lerp(pal["grid_glow"], pal["grid"], min(1.0, k / (0.55 * len(d)))) for k in range(len(d))]
    col = np.array([expand(v) for v in shade], np.uint8)            # (rows, 3)
    region = a[:, horizon:H]
    m = lines & inner[:, horizon:H]
    region[m] = np.broadcast_to(col[None, :, :], region.shape)[m]
    edge = inner[:, horizon:horizon + 2]
    a[:, horizon:horizon + 2][edge] = _rgb(pal["grid"])               # horizon line


def _neon_wall(a, x0, y0, x1, y1, pal):
    """A neon tube on the Wall's inner edge: 2 px bright, 2 px glow outside
    and 1 px glow inside the Arena."""
    def ring(d):
        m = np.zeros((W, H), bool)
        m[max(0, x0 - d):x1 + d, max(0, y0 - d):y1 + d] = True
        m[x0 - d + 1 if d > 0 else x0 + 1:x1 + d - 1, y0 - d + 1 if d > 0 else y0 + 1:y1 + d - 1] = False
        return m
    glow = _rgb(halve(pal["wall_line"]))
    for d in (4, 3):
        a[ring(d)] = glow
    for d in (2, 1):
        a[ring(d)] = _rgb(pal["wall_line"])
    a[ring(0)] = glow


def shine(c12: int) -> int:
    """Pulse-stripe colour: near white, c/4 + 12 per channel. Unlike a
    fixed add it brightens every colour, including channels already at 15."""
    return ((c12 >> 2) & 0x333) + 0xCCC


def stripe_surface() -> pygame.Surface:
    """Diagonal stripe mask for the pulse Trail (white on stripes), 2 periods
    wide so it can scroll."""
    w = W + STRIPE_PERIOD
    xs = np.arange(w, dtype=np.int32)[:, None]
    on = (((xs + YS) % STRIPE_PERIOD) < 6)
    a = np.zeros((w, H, 3), np.uint8)
    a[on] = 255
    return pygame.surfarray.make_surface(a)


def finish(surface: pygame.Surface, flash: bool, scanlines: bool) -> None:
    """Final colour stage on 4-bit levels: crash flash, scanlines, RGB444.
    The handout's white border is left out, so it stays all 1s."""
    assert surface.get_bitsize() == 32 and max(surface.get_masks()[:3]) <= 0xFF0000
    p = pygame.surfarray.pixels2d(surface)       # 0x00RRGGBB per pixel
    p[...] = ((p >> 4) & 0x0F0F0F) * 0x11         # RGB444: n -> n * 17
    b = BORDER_PX
    inside = p[b:W - b, b:H - b]                  # starts on an even row (b = 10)
    if flash or scanlines:
        v = (inside >> 4) & 0x0F0F0F
        if flash:
            v = ((v >> 1) & 0x070707) + 0x070707
        if scanlines:
            odd = v[:, 1::2]
            odd -= (odd >> 2) & 0x030303
        inside[...] = v * 0x11
    del inside, p


def active(look) -> list:
    """HW_COST keys of the effects the look uses, in layer order."""
    on = []
    if look.bg != "plain":
        on.append("sky")
    if look.bg in ("stars", "sunset"):
        on.append("stars")
    if look.bg == "sunset":
        on.append("sunset")
    if look.grid in ("neon", "floor"):
        on.append(look.grid + " grid")
    if look.wall == "neon":
        on.append("neon Wall")
    if look.trail in ("neon", "pulse"):
        on.append(look.trail + " Trail")
    if look.bike_fx == "streaks":
        on.append("speed streaks")
    if look.reward_anim != "still":
        on.append("Reward " + look.reward_anim)
    if look.crash != "blink":
        on.append("crash ring")
    if look.crash == "ring+flash":
        on.append("flash")
    if look.hud == "on":
        on.append("HUD")
        if look.font in ("neon", "chrome"):
            on.append(look.font + " digits")
    if look.crt == "scanlines":
        on.append("scanlines")
    return on


def lut_items(look, glyph_h: int) -> list:
    """(name, width, depth) of the effect tables, for the BRAM budget."""
    rows = []
    if look.bg != "plain":
        rows.append(("Sky gradient LUT", 12, H // SKY_BAND))
    if look.bg == "sunset":                       # half-width 8 b + colour 12 b
        rows.append(("Sun row LUT", 20, SUN_R + SUN_RISE if look.grid == "floor" else 2 * SUN_R + 1))
    if look.grid == "floor":                      # 1/d 16 b + 4 phase line bits + colour 12 b
        rows.append(("Floor row LUT", 32, H // 2))
    pulses = (4 if look.grid == "neon" else 0) + (8 if look.reward_anim == "pulse" else 0)
    if pulses:
        rows.append(("Pulse colour table", 12, pulses))
    if look.hud == "on" and look.font == "chrome":    # one bank per Player
        rows.append(("Chrome row LUT", 12, 2 * glyph_h))
    return rows
