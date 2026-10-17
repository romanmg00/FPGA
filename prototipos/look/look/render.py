"""Draws one 1280 x 800 frame from a Game snapshot (FPGA limits 1, 3, 5).

Fixed layer order, bottom to top, as drawcon will compose it:
background -> grid lines -> Walls -> HUD area -> 10 px border -> Trails ->
Rewards -> Bikes -> HUD. Every layer depends only on the pixel position and
the game state. The finished frame is forced to RGB444 as a final check.
"""

import pygame
import pygame.surfarray

from model import CRASH
from model.arena import TRAIL_P1, TRAIL_P2
from model.params import BORDER_PX, SCREEN_H, SCREEN_W
from model.steering import DOWN, LEFT, RIGHT, UP

from .hud import BLINK_FRAMES, HudRenderer
from .rgb444 import expand, halve

SIZE = (SCREEN_W, SCREEN_H)


def reduce_to_rgb444(surface: pygame.Surface) -> None:
    a = pygame.surfarray.pixels3d(surface)
    a[...] = (a >> 4) * 17
    del a


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
        self.sprites = sprites
        self.bike_rom = bike_rom
        self.reward_roms = reward_roms        # (small kind, big kind)
        self.hud = HudRenderer()
        self.base = self._build_base()
        self.cells = self.base.copy()

    # --- static layers --------------------------------------------------
    def _build_base(self) -> pygame.Surface:
        g, p, c = self.geom, self.pal, self.geom.cell_px
        s = pygame.Surface(SIZE)
        s.fill(expand(p["wall"]))
        inner = pygame.Rect(g.x0 * c, g.y0 * c, g.width * c, g.height * c)
        s.fill(expand(p["bg"]), inner)
        step = {"off": 0, "32px": 32, "cell": c}[self.look.grid]
        if step:
            col = expand(p["grid"])
            for x in range(0, SCREEN_W, step):
                if inner.left <= x < inner.right:
                    s.fill(col, (x, inner.top, 1, inner.height))
            for y in range(0, SCREEN_H, step):
                if inner.top <= y < inner.bottom:
                    s.fill(col, (inner.left, y, inner.width, 1))
        hud = g.hud
        hud_bg = expand(p["hud_bg"])
        if hud.top:
            s.fill(hud_bg, (0, 0, SCREEN_W, hud.top))
        if hud.bottom:
            s.fill(hud_bg, (0, SCREEN_H - hud.bottom, SCREEN_W, hud.bottom))
        if hud.left:
            s.fill(hud_bg, (0, 0, hud.left, SCREEN_H))
        if hud.right:
            s.fill(hud_bg, (SCREEN_W - hud.right, 0, hud.right, SCREEN_H))
        white = expand(p["border"])
        b = BORDER_PX
        for r in ((0, 0, SCREEN_W, b), (0, SCREEN_H - b, SCREEN_W, b),
                  (0, 0, b, SCREEN_H), (SCREEN_W - b, 0, b, SCREEN_H)):
            s.fill(white, r)
        return s

    # --- Trails -----------------------------------------------------------
    def update_cells(self, grid) -> None:
        cleared, written = grid.drain_changes()
        if cleared:
            self.cells = self.base.copy()
        for x, y in written:
            self._draw_cell(x, y, grid.read(x, y))

    def redraw_all(self, grid) -> None:
        grid.drain_changes()
        self.cells = self.base.copy()
        g = self.geom
        for y in range(g.y0, g.y1):
            for x in range(g.x0, g.x1):
                code = grid.read(x, y)
                if code in (TRAIL_P1, TRAIL_P2):
                    self._draw_cell(x, y, code)

    def _draw_cell(self, x, y, code) -> None:
        c = self.geom.cell_px
        r = pygame.Rect(x * c, y * c, c, c)
        if code not in (TRAIL_P1, TRAIL_P2):
            self.cells.blit(self.base, r, r)
            return
        col = self.pal["p1"] if code == TRAIL_P1 else self.pal["p2"]
        style = self.look.trail
        if style == "full":
            self.cells.fill(expand(col), r)
        elif style == "inset":
            self.cells.blit(self.base, r, r)
            self.cells.fill(expand(col), r.inflate(-2 * max(1, c // 8), -2 * max(1, c // 8)))
        else:  # core: dim Cell edge, bright centre
            edge = max(1, c // 8)
            self.cells.fill(expand(halve(col)), r)
            self.cells.fill(expand(col), r.inflate(-2 * edge, -2 * edge))

    # --- frame ------------------------------------------------------------
    def draw(self, frame: pygame.Surface, snap: dict) -> None:
        g, c = self.geom, self.geom.cell_px
        frame.blit(self.cells, (0, 0))

        values = snap["reward_values"]
        small = min(values)
        for slot, cell in enumerate(snap["rewards"]):
            if cell is None:
                continue
            kind = 0 if values[slot] == small else 1
            rom = self.reward_roms[kind]
            tint = self.pal["reward_small"] if kind == 0 else self.pal["reward_big"]
            frame.blit(rom.surface(UP, tint), sprite_origin(cell, c, rom.size, UP, "centre"))

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

        self.hud.draw(frame, self.look, self.pal, snap)
        reduce_to_rgb444(frame)

    def draw_cell_overlay(self, frame, snap) -> None:
        """Debug only (not part of the image): the Cells the rules use."""
        c = self.geom.cell_px
        for head in snap["heads"]:
            pygame.draw.rect(frame, (255, 255, 255), (head[0] * c, head[1] * c, c, c), 1)
        for cell in snap["rewards"]:
            if cell is not None:
                pygame.draw.rect(frame, (255, 255, 0), (cell[0] * c, cell[1] * c, c, c), 1)
