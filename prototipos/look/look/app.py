"""Look Prototype viewer (objective L1), playable on the Game Model (M1).

Run from prototype/:  python -m look
"""

import os
import sys
import time
from dataclasses import replace

import pygame

from model import FrameInputs, Game, RuleParams, ArenaGeometry
from model.params import SCREEN_H, SCREEN_W
from model.steering import DOWN, LEFT, RIGHT, UP

from . import budget
from .art import reward_rom_count
from .candidates import AXES, GEOMETRY_FIELDS, PALETTES, LookConfig, cycle, hud_reserve
from .font import FONTS, ICON_ROM_BITS
from .hud import backing_boxes
from .render import SIZE, FrameRenderer
from .sprites import SpriteLibrary

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # prototype/
ASSETS = os.path.join(os.path.dirname(HERE), "assets")
OUT = os.path.join(HERE, "out")

FPS = 60                     # stands in for the 59.998 Hz frame_tick
FRAME_HZ = 83.46e6 / (1680 * 828)
PANEL_W = 380

P1_KEYS = {pygame.K_UP: UP, pygame.K_RIGHT: RIGHT, pygame.K_DOWN: DOWN, pygame.K_LEFT: LEFT}
P2_KEYS = {pygame.K_w: UP, pygame.K_d: RIGHT, pygame.K_s: DOWN, pygame.K_a: LEFT}
START_KEYS = (pygame.K_SPACE, pygame.K_RETURN)
AXIS_KEYS = {pygame.K_1: "1", pygame.K_2: "2", pygame.K_3: "3", pygame.K_4: "4",
             pygame.K_5: "5", pygame.K_6: "6", pygame.K_7: "7", pygame.K_8: "8",
             pygame.K_9: "9", pygame.K_0: "0", pygame.K_f: "F", pygame.K_h: "H"}

OK, WARN, BAD, DIM, TEXT = (120, 220, 120), (240, 200, 80), (255, 90, 90), (140, 140, 160), (230, 230, 240)


class App:
    def __init__(self):
        self.sprites = SpriteLibrary(ASSETS)
        self.axes = [(k, f, self.sprites.bike_styles() if f == "bike_style" else ch)
                     for k, f, ch in AXES]
        self.look = LookConfig()
        self.rules = RuleParams()
        self.paused = False
        self.show_panel = True
        self.show_cells = False
        self.fullscreen = False
        self.message = ""
        self._new_game()

    # --- configuration ---------------------------------------------------
    def _new_game(self):
        self.geom = ArenaGeometry(self.look.cell_px, hud_reserve(self.look.hud, self.look.digit_px))
        self.game = Game(self.geom, self.rules)
        self._new_renderer()

    def _new_renderer(self):
        look = self.look
        self.bike_rom = self.sprites.bike(look.bike_style, look.bike_px)
        self.reward_roms = tuple(self.sprites.reward(look.reward_look, k, look.reward_px)
                                 for k in (0, 1))
        self.renderer = FrameRenderer(self.geom, look, PALETTES[look.palette],
                                      self.sprites, self.bike_rom, self.reward_roms)
        self.renderer.redraw_all(self.game.grid)

    def change_axis(self, key, step):
        for k, field, choices in self.axes:
            if k == key:
                self.look = cycle(self.look, field, choices, step)
                if field in GEOMETRY_FIELDS:
                    self._new_game()
                    self.message = "Arena changed: new Match"
                else:
                    self._new_renderer()
                    self.message = ""
                return

    def change_speed(self, delta):
        k = max(1, min(30, self.rules.frames_per_step + delta))
        self.rules = replace(self.rules, frames_per_step=k)
        self.game.rules = self.rules

    # --- checks for the panel ---------------------------------------------
    def checks(self):
        """(budget rows, flags needing a fix before lockdown, notes)."""
        font = FONTS[self.look.font].at_height(self.look.digit_px)
        rows = budget.items(self.geom, self.bike_rom.size, self.reward_roms[0].size,
                            reward_rom_count(self.look.reward_look), font, ICON_ROM_BITS)
        flags, notes = [], []
        clear = budget.clear_us(self.geom)
        if clear > budget.BLANK_US:
            flags.append(f"Arena clear {clear:,.0f} us > {budget.BLANK_US:.1f} us blanking")
        total18 = sum(r.ramb18 for r in rows)
        if total18 > 2 * budget.RAMB36_TOTAL:
            flags.append("BRAM over the XC7A100T total")
        flags += self.bike_rom.problems + [p for r in self.reward_roms for p in r.problems]
        if not font.scale_is_power_of_two:
            notes.append(f"Digits x{font.scale}: scale needs counters, not a bit slice")
        if self.look.hud == "corners":
            covered = self._covered_cells(font)
            flags.append(f"HUD hides {covered} Arena Cells: needs a rule")
        if self.reward_roms[0].size > self.geom.cell_px:
            notes.append("Reward > Cell: neighbours can overlap")
        if self.bike_rom.size != self.look.bike_px:
            notes.append(f"PNG Bike is {self.bike_rom.size} px (size axis ignored)")
        return rows, total18, clear, flags, notes

    def _covered_cells(self, font):
        g, c = self.geom, self.geom.cell_px
        cells = set()
        for box in backing_boxes(self.look.hud, font):
            for y in range(box.top // c, (box.bottom - 1) // c + 1):
                for x in range(box.left // c, (box.right - 1) // c + 1):
                    if g.in_interior(x, y):
                        cells.add((x, y))
        return len(cells)

    # --- main loop ----------------------------------------------------------
    def run(self):
        if sys.platform == "win32":
            try:
                import ctypes
                ctypes.windll.user32.SetProcessDPIAware()   # 1:1 pixels in fullscreen
            except Exception:
                pass
        pygame.init()
        pygame.display.set_caption("CS-256 Tron - Look Prototype (L1)")
        self.ui_font = pygame.font.SysFont("consolas,menlo,monospace", 15)
        self.ui_bold = pygame.font.SysFont("consolas,menlo,monospace", 15, bold=True)
        desk_w, desk_h = pygame.display.get_desktop_sizes()[0]
        scale = min(1.0, (desk_w * 0.92 - PANEL_W) / SCREEN_W, desk_h * 0.85 / SCREEN_H)
        self.window_size = (int(SCREEN_W * scale) + PANEL_W, int(SCREEN_H * scale))
        self.screen = pygame.display.set_mode(self.window_size, pygame.RESIZABLE)
        frame = pygame.Surface(SIZE)
        clock = pygame.time.Clock()

        while True:
            inputs = self._events()
            if inputs is None:
                break
            self.game.tick(inputs)
            self.renderer.update_cells(self.game.grid)
            snap = self.game.snapshot()
            self.renderer.draw(frame, snap)
            self.last_frame = frame
            shown = frame
            if self.show_cells:
                shown = frame.copy()
                self.renderer.draw_cell_overlay(shown, snap)
            self._present(shown, snap, clock.get_fps())
            clock.tick(FPS)
        pygame.quit()

    def _events(self):
        turns = ([], [])
        start = False
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                return None
            if ev.type == pygame.VIDEORESIZE and not self.fullscreen:
                self.window_size = ev.size
                self.screen = pygame.display.set_mode(ev.size, pygame.RESIZABLE)
            if ev.type != pygame.KEYDOWN:
                continue
            k = ev.key
            if k == pygame.K_ESCAPE:
                if self.fullscreen:
                    self._toggle_fullscreen()
                else:
                    return None
            elif k in P1_KEYS:
                turns[0].append(P1_KEYS[k])
            elif k in P2_KEYS:
                turns[1].append(P2_KEYS[k])
            elif k in START_KEYS:
                start = True
            elif k in AXIS_KEYS:
                self.change_axis(AXIS_KEYS[k], -1 if ev.mod & pygame.KMOD_SHIFT else 1)
            elif k == pygame.K_p:
                self.paused = not self.paused
            elif k == pygame.K_BACKSPACE:
                self.game.power_up()
                self.message = "Hard reset (CPU_RESETN)"
            elif k == pygame.K_RIGHTBRACKET:
                self.change_speed(-1)
            elif k == pygame.K_LEFTBRACKET:
                self.change_speed(+1)
            elif k == pygame.K_g:
                self.show_cells = not self.show_cells
            elif k == pygame.K_TAB:
                self.show_panel = not self.show_panel
            elif k == pygame.K_F11:
                self._toggle_fullscreen()
            elif k == pygame.K_F12:
                self._screenshot()
        return FrameInputs(turns=(tuple(turns[0]), tuple(turns[1])), start=start,
                           paused=self.paused)

    def _toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen
        if self.fullscreen:
            self.screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
        else:
            self.screen = pygame.display.set_mode(self.window_size, pygame.RESIZABLE)

    def _screenshot(self):
        os.makedirs(OUT, exist_ok=True)
        lk = self.look
        name = (f"L1-{lk.hud}-c{lk.cell_px}-b{self.bike_rom.size}-{lk.bike_style.replace(':', '_')}"
                f"-{lk.reward_look}-{lk.palette}-{lk.trail}-{time.strftime('%Y%m%d-%H%M%S')}.png")
        path = os.path.join(OUT, name)
        pygame.image.save(self.last_frame, path)
        self.message = "Saved " + os.path.relpath(path, HERE)

    # --- drawing the window --------------------------------------------------
    def _present(self, frame, snap, fps):
        self.screen.fill((24, 24, 30))
        sw, sh = self.screen.get_size()
        panel = self.show_panel and not self.fullscreen
        view_w = sw - (PANEL_W if panel else 0)
        scale = min(view_w / SCREEN_W, sh / SCREEN_H)
        if self.fullscreen and scale >= 1:
            scale = int(scale)                       # whole pixels on the monitor
        w, h = max(1, int(SCREEN_W * scale)), max(1, int(SCREEN_H * scale))
        view = frame if (w, h) == SIZE else pygame.transform.scale(frame, (w, h))
        self.screen.blit(view, ((view_w - w) // 2, (sh - h) // 2))
        if panel:
            self._panel(sw - PANEL_W, snap, fps, scale)
        pygame.display.flip()

    def _panel(self, x0, snap, fps, scale):
        y = 8
        g, lk, rules = self.geom, self.look, self.rules

        def line(text, colour=TEXT, bold=False):
            nonlocal y
            surf = (self.ui_bold if bold else self.ui_font).render(text, True, colour)
            self.screen.blit(surf, (x0 + 10, y))
            y += 18

        line("LOOK PROTOTYPE  L1", bold=True)
        state = snap["phase"] + ("  [PAUSED]" if self.paused else "")
        line(f"{state}   Round {snap['round']}  Step {snap['step']}", OK if not self.paused else WARN)
        line(f"P1 {snap['points'][0]:2d} pts {snap['lives'][0]} lives   "
             f"P2 {snap['points'][1]:2d} pts {snap['lives'][1]} lives")
        line(f"view {scale * 100:.0f}%   {fps:4.1f} fps", DIM)
        y += 6
        line("CANDIDATES (key, Shift = back)", bold=True)
        for k, field, _ in self.axes:
            line(f" {k}  {field:<12} {getattr(lk, field)}")
        y += 6
        line("ARENA AND SPEED", bold=True)
        line(f" {g.width} x {g.height} Cells, Wall {g.wall_cells} Cell(s)")
        steps = FRAME_HZ / rules.frames_per_step
        line(f" [ ]  K = {rules.frames_per_step} frames/Step = {steps:.1f} Steps/s")
        line(f"      {steps * g.cell_px:.0f} px/s, crosses Arena in {g.width / steps:.1f} s")
        y += 6
        rows, total18, clear, flags, notes = self.checks()
        line("BRAM (estimate, RAMB18 halves)", bold=True)
        for r in rows:
            tag = "  LUT?" if r.maybe_lut else ""
            line(f" {r.name:<22}{r.instances}x {r.bits / 1024:7.1f} Kb {r.ramb18:3d}{tag}")
        pct = 100 * total18 / (2 * budget.RAMB36_TOTAL)
        line(f" total {total18} of {2 * budget.RAMB36_TOTAL} RAMB18 ({pct:.1f}%)",
             OK if pct < 100 else BAD)
        line(f" Arena clear {clear:,.1f} us of {budget.BLANK_US:.1f} us",
             OK if clear <= budget.BLANK_US else BAD)
        y += 6
        line("NEEDS FIXING BEFORE LOCKDOWN", bold=True)
        if not flags:
            line(" none", OK)
        for f in flags:
            line(" ! " + f, BAD)
        for n in notes:
            line(" i " + n, WARN)
        if self.message:
            y += 6
            line(self.message, WARN)
        y = self.screen.get_height() - 4 * 18 - 8
        line("P1 arrows  P2 WASD  Start Space/Enter", DIM)
        line("P pause  Backspace reset  G Cells", DIM)
        line("Tab panel  F11 fullscreen  F12 screenshot", DIM)
        line("Esc quit", DIM)


def main():
    App().run()
