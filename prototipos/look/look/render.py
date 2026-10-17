"""Draws one 1280 x 800 frame from a Game snapshot (FPGA limits 1, 3, 5).

Fixed layer order, bottom to top, as drawcon will compose it:
sky -> stars -> sun -> grid lines -> Walls -> HUD area -> 10 px border ->
Trails -> Rewards -> Bikes -> crash ring -> HUD, then one colour stage on
the result (crash flash, scanlines). Every layer depends only on the pixel
position, a frame counter and the game state. The finished frame is forced
to RGB444 as a final check.
"""

import pygame

from model import CRASH
from model.arena import TRAIL_P1, TRAIL_P2
from model.params import SCREEN_H, SCREEN_W
from model.steering import DOWN, LEFT, RIGHT, UP

from . import fx
from .hud import BLINK_FRAMES, HudRenderer
from .rgb444 import expand, halve, lerp

SIZE = (SCREEN_W, SCREEN_H)
RING_SPEED = 6             # px per frame
RING_FRAMES = 60
FLASH_FRAMES = 4
PULSE_LEVELS = (0.6, 0.8, 1.0, 0.8)


def sprite_origin(cell, cell_px, size, heading, anchor):
    """Top-left pixel of a size x size sprite placed on a Cell.

    centre: the sprite is centred on the Cell (VGA plan: head*8 - 12).
    nose:   the sprite's front edge lines up with the Cell's leading edge.
    """
    cx = cell[0] * cell_px + cell_px // 2 - size // 2
    cy = cell[1] * cell_px + cell_px // 2 - size // 2
    if anchor == "nose":
        if heading == UP:
            cy = cell[1] * cell_px
        elif heading == DOWN:
            cy = cell[1] * cell_px + cell_px - size
        elif heading == LEFT:
            cx = cell[0] * cell_px
        elif heading == RIGHT:
            cx = cell[0] * cell_px + cell_px - size
    return cx, cy


class FrameRenderer:
    def __init__(self, geom, look, palette, sprites, bike_rom, reward_roms):
        self.geom = geom
        self.look = look
        self.pal = palette
        self.bike_rom = bike_rom
        self.reward_roms = reward_roms        # (small kind, big kind)
        self.hud = HudRenderer()
        animated = look.grid in ("neon", "floor") or look.bg in ("stars", "sunset")
        phases = range(fx.PHASES) if animated else (0,)
        self.bases = [fx.build_base(geom, look, palette, p) for p in phases]
        self.trails = pygame.Surface(SIZE)
        self.trails.set_colorkey((0, 0, 0))
        self.pulse = look.trail == "pulse"
        if self.pulse:
            self.mask = pygame.Surface(SIZE)
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
                if code in (TRAIL_P1, TRAIL_P2):
                    self._draw_cell(x, y, code)

    def _clear_trails(self):
        self.trails.fill((0, 0, 0))
        if self.pulse:
            self.mask.fill((0, 0, 0))

    def _draw_cell(self, x, y, code) -> None:
        c = self.geom.cell_px
        r = pygame.Rect(x * c, y * c, c, c)
        self.trails.fill((0, 0, 0), r)
        if self.pulse:
            self.mask.fill((0, 0, 0), r)
        if code not in (TRAIL_P1, TRAIL_P2):
            return
        col = self.pal["p1"] if code == TRAIL_P1 else self.pal["p2"]
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
            self.mask.fill((255, 255, 255), r)

    # --- frame ------------------------------------------------------------
    def draw(self, frame: pygame.Surface, snap: dict) -> None:
        c = self.geom.cell_px
        ph = fx.phase(self.frame)
        frame.blit(self.bases[ph % len(self.bases)], (0, 0))
        frame.blit(self.trails, (0, 0))
        if self.pulse:
            shine = self.mask.copy()
            shift = (2 * self.frame) % fx.STRIPE_PERIOD
            shine.blit(self.stripes, (shift - fx.STRIPE_PERIOD, 0),
                       special_flags=pygame.BLEND_RGB_MULT)
            frame.blit(shine, (0, 0), special_flags=pygame.BLEND_RGB_ADD)

        self._draw_rewards(frame, snap, ph)

        crashing = snap["phase"] == CRASH
        blink_off = (snap["phase_frames"] // BLINK_FRAMES) % 2 == 1
        for i in (0, 1):
            if crashing and snap["crashed"][i] and blink_off:
                continue
            heading = snap["headings"][i]
            tint = self.pal["p1"] if i == 0 else self.pal["p2"]
            rom = self.bike_rom
            pos = sprite_origin(snap["heads"][i], c, rom.size, heading, self.look.anchor)
            frame.blit(rom.surface(heading, tint), pos)

        crash_fx = self.look.crash
        if crashing and crash_fx != "blink":
            self._draw_rings(frame, snap)

        self.hud.draw(frame, self.look, self.pal, snap)
        flash = (crashing and crash_fx == "ring+flash" and snap["phase_frames"] < FLASH_FRAMES)
        fx.finish(frame, flash, self.look.crt == "scanlines")
        self.frame += 1

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
            frame.blit(rom.surface(heading, tint), sprite_origin(cell, c, rom.size, UP, "centre"))

    def _draw_rings(self, frame, snap):
        """Square shockwaves from each crashed Bike's Cell."""
        c = self.geom.cell_px
        t = snap["phase_frames"]
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
        for head in snap["heads"]:
            pygame.draw.rect(frame, (255, 255, 255), (head[0] * c, head[1] * c, c, c), 1)
        for cell in snap["rewards"]:
            if cell is not None:
                pygame.draw.rect(frame, (255, 255, 0), (cell[0] * c, cell[1] * c, c, c), 1)
