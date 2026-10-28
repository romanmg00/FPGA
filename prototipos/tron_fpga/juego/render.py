"""Draws one 1280 x 800 frame from a Game snapshot (FPGA limits 1, 3, 5).

Fixed layer order, bottom to top, as drawcon will compose it:
sky -> stars -> sun -> grid lines -> Walls -> HUD band -> Trails ->
Rewards -> Bikes -> crash ring -> welcome/Pause screen -> HUD -> 10 px white border, then one colour
stage on the result (crash flash, scanlines) that leaves the border alone.
The border is on top, as the contract requires: a 32 px Bike centred on an
edge Cell reaches 2 px into it. Every layer depends only on the pixel
position, a video frame counter and the game state. The finished frame is
forced to RGB444 as a final check.
"""

import pygame

from model import CRASH, PLAY
from model.arena_map import player_of
from model.params import BORDER_PX, SCREEN_H, SCREEN_W
from model.turn_unit import DOWN, RIGHT, UP

from . import fx
from .hud import BLINK_TICKS, HudRenderer
from .rgb444 import expand, halve, lerp
from .screens import ScreenRenderer

SIZE = (SCREEN_W, SCREEN_H)
RING_SPEED = 6             # px per frame
RING_FRAMES = 60
FLASH_FRAMES = 4
PULSE_LEVELS = (0.6, 0.8, 1.0, 0.8)


def sprite_origin(cell, cell_px, size):
    """Top-left pixel of a size x size sprite centred on a Cell (agreed:
    a 32 px Bike on a 16 px Cell starts at cx * 16 - 8)."""
    return (cell[0] * cell_px + cell_px // 2 - size // 2,
            cell[1] * cell_px + cell_px // 2 - size // 2)


def draw_border(frame, colour) -> None:
    b = BORDER_PX
    for r in ((0, 0, SCREEN_W, b), (0, SCREEN_H - b, SCREEN_W, b),
              (0, 0, b, SCREEN_H), (SCREEN_W - b, 0, b, SCREEN_H)):
        frame.fill(colour, r)


class FrameRenderer:
    def __init__(self, geom, look, palette, bike_rom, reward_roms):
        self.geom = geom
        self.look = look
        self.pal = palette
        self.bike_rom = bike_rom
        self.reward_roms = reward_roms        # (small kind, big kind)
        self.hud = HudRenderer()
        self.screens = ScreenRenderer()
        animated = look.grid in ("neon", "floor") or look.bg in ("stars", "sunset")
        phases = range(fx.PHASES) if animated else (0,)
        self.bases = [fx.build_base(geom, look, palette, p) for p in phases]
        self.trails = pygame.Surface(SIZE)
        self.trails.set_colorkey((0, 0, 0))
        self.pulse = look.trail == "pulse"
        if self.pulse:                        # each Trail Cell's stripe colour
            self.shine_src = pygame.Surface(SIZE)
            self.stripes = fx.stripe_surface()
        self.frame = 0

    # --- Trails -----------------------------------------------------------
    def update_cells(self, grid) -> None:
        cleared, written = grid.drain_changes()
        if cleared:
            self._clear_trails()
        for x, y in written:
            self._draw_cell(x, y, grid.read(x, y))

    def redraw_all(self, grid) -> None:
        grid.drain_changes()
        self._clear_trails()
        g = self.geom
        for y in range(g.y0, g.y1):
            for x in range(g.x0, g.x1):
                code = grid.read(x, y)
                if player_of(code) is not None:
                    self._draw_cell(x, y, code)

    def _clear_trails(self):
        self.trails.fill((0, 0, 0))
        if self.pulse:
            self.shine_src.fill((0, 0, 0))

    def _draw_cell(self, x, y, code) -> None:
        c = self.geom.cell_px
        r = pygame.Rect(x * c, y * c, c, c)
        self.trails.fill((0, 0, 0), r)
        if self.pulse:
            self.shine_src.fill((0, 0, 0), r)
        player = player_of(code)               # Trail and head Cells
        if player is None:
            return
        col = self.pal["p1"] if player == 0 else self.pal["p2"]
        style = self.look.trail
        edge = max(1, c // 8)
        if style == "inset":
            self.trails.fill(expand(col), r.inflate(-2 * edge, -2 * edge))
        elif style == "core":                 # dim Cell edge, bright centre
            self.trails.fill(expand(halve(col)), r)
            self.trails.fill(expand(col), r.inflate(-2 * edge, -2 * edge))
        elif style == "neon":                 # colour edge, white-hot core
            self.trails.fill(expand(col), r)
            self.trails.fill(expand(lerp(col, 0xFFF, 0.6)), r.inflate(-c // 2, -c // 2))
        else:                                 # full, pulse
            self.trails.fill(expand(col), r)
        if self.pulse:
            self.shine_src.fill(expand(fx.shine(col)), r)

    # --- frame ------------------------------------------------------------
    def draw(self, frame: pygame.Surface, snap: dict) -> None:
        c = self.geom.cell_px
        ph = fx.phase(self.frame)
        frame.blit(self.bases[ph % len(self.bases)], (0, 0))
        frame.blit(self.trails, (0, 0))
        if self.pulse:                        # stripe pixels take the shine colour
            shine = self.shine_src.copy()
            shift = (2 * self.frame) % fx.STRIPE_PERIOD
            shine.blit(self.stripes, (shift - fx.STRIPE_PERIOD, 0),
                       special_flags=pygame.BLEND_RGB_MULT)
            shine.set_colorkey((0, 0, 0))
            frame.blit(shine, (0, 0))

        self._draw_rewards(frame, snap, ph)

        crashing = snap["phase"] == CRASH
        blink_off = (snap["phase_ticks"] // BLINK_TICKS) % 2 == 1
        for i in (0, 1) if snap["heads"] else ():   # no Bikes before the first Start
            if crashing and snap["crashed"][i] and blink_off:
                continue
            heading = snap["headings"][i]
            tint = self.pal["p1"] if i == 0 else self.pal["p2"]
            rom = self.bike_rom
            pos = sprite_origin(snap["heads"][i], c, rom.size)
            if self.look.bike_fx == "streaks" and snap["phase"] == PLAY:
                self._draw_streaks(frame, pos, rom.size, heading, tint)
            frame.blit(rom.surface(heading, tint), pos)

        crash_fx = self.look.crash
        if crashing and crash_fx != "blink":
            self._draw_rings(frame, snap)

        self.screens.draw(frame, snap, self.pal)
        if self.look.hud == "on":
            self.hud.draw(frame, self.look, self.pal, snap, self.geom.hud_px)
        draw_border(frame, expand(self.pal["border"]))
        flash = (crashing and crash_fx == "ring+flash" and snap["phase_ticks"] < FLASH_FRAMES)
        fx.finish(frame, flash, self.look.crt == "scanlines")
        self.frame += 1

    def _draw_streaks(self, frame, pos, size, heading, tint):
        """Speed lines trailing the sprite's back edge, flickering in length.
        In hardware: a few rectangle compares against the head position."""
        ox, oy = pos
        w = max(1, size // 16)
        flick = (self.frame >> 2) & 1
        for off, length, colour in ((0.42, 0.8, halve(tint)), (0.58, 0.45, halve(halve(tint)))):
            d = int(size * off)
            n = int(size * length) + flick * size // 8
            for side in (-1, 1):
                if heading in (UP, DOWN):
                    x = ox + size // 2 + side * d - w // 2
                    y = oy + size if heading == UP else oy - n
                    r = (x, y, w, n)
                else:
                    y = oy + size // 2 + side * d - w // 2
                    x = ox - n if heading == RIGHT else ox + size
                    r = (x, y, n, w)
                frame.fill(expand(colour), r)

    def _draw_rewards(self, frame, snap, ph):
        c = self.geom.cell_px
        values = snap["reward_values"]
        small = min(values)
        anim = self.look.reward_anim
        heading = ph if anim == "spin" else UP
        for slot, cell in enumerate(snap["rewards"]):
            if cell is None:
                continue
            kind = 0 if values[slot] == small else 1
            rom = self.reward_roms[kind]
            tint = self.pal["reward_small"] if kind == 0 else self.pal["reward_big"]
            if anim == "pulse":
                tint = lerp(halve(tint), tint, PULSE_LEVELS[ph])
            frame.blit(rom.surface(heading, tint), sprite_origin(cell, c, rom.size))

    def _draw_rings(self, frame, snap):
        """Square shockwaves from each crashed Bike's Cell."""
        c = self.geom.cell_px
        t = snap["phase_ticks"]
        b = BORDER_PX                         # rings stay inside the white border
        frame.set_clip(pygame.Rect(b, b, SCREEN_W - 2 * b, SCREEN_H - 2 * b))
        self._ring_cells(frame, snap, c, t)
        frame.set_clip(None)

    def _ring_cells(self, frame, snap, c, t):
        for i in (0, 1):
            if not snap["crashed"][i]:
                continue
            hx, hy = snap["heads"][i]
            cx, cy = hx * c + c // 2, hy * c + c // 2
            col = self.pal["p1"] if i == 0 else self.pal["p2"]
            for lag, colour in ((0, col), (10, halve(col)), (20, halve(halve(col)))):
                r = (t - lag) * RING_SPEED
                if 0 < r and t - lag < RING_FRAMES:
                    pygame.draw.rect(frame, expand(colour), (cx - r, cy - r, 2 * r, 2 * r), 3)

    def draw_cell_overlay(self, frame, snap) -> None:
        """Debug only (not part of the image): the Cells the rules use."""
        c = self.geom.cell_px
        for head in snap["heads"] or ():
            pygame.draw.rect(frame, (255, 255, 255), (head[0] * c, head[1] * c, c, c), 1)
        for cell in snap["rewards"]:
            if cell is not None:
                pygame.draw.rect(frame, (255, 255, 0), (cell[0] * c, cell[1] * c, c, c), 1)
