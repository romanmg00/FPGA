"""Look Prototype viewer (objective L1), playable on the Game Model (M1).

The PC loop runs at 60 fps and gives the model one game-clock tick per
frame, standing in for the ~60 Hz divided game clock (ADR 0002). Keyboard
keys are swapped for desktop testing only: WASD supplies P1's board-button
samples and arrows supply P2's UART bytes. FPGA ownership is unchanged:
P1 uses BTNU/BTND/BTNL/BTNR, P2 uses browser WASD over UART.
Enter is BTNC and Space supplies UART Start byte 0x20, P is SW0, T steps
{SW15, SW14} and Backspace is CPU_RESETN.

Run from prototipos/tron_fpga/:  python -m juego
"""

import os
import sys
import time
from dataclasses import replace

import pygame

from model import DRAW, BoardInputs, Game, RuleParams
from model.input_batch import BTN_OF, BTN_START, UART_KEY
from model.params import (GAME_HZ, MIN_STEP_TICKS, SCREEN_H, SCREEN_W, STEP_TICKS, SW_GOAL_LSB,
                          SW_PAUSE, goal_from_switches)
from model.turn_unit import DOWN, LEFT, RIGHT, UP

from . import budget, fx
from .candidates import DEFAULT_PRESET, PALETTES, PRESETS, PRESET_STATUS, LookConfig
from .font import ICON_ROM_BITS
from .hud import digit_font
from .render import SIZE, FrameRenderer
from .sprites import SpriteLibrary

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # prototipos/tron_fpga/
ASSETS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets")   # repository root
OUT = os.path.join(HERE, "out")

FPS = 60                     # one game-clock tick per PC frame
PANEL_W = 380

P1_KEYS = {pygame.K_w: UP, pygame.K_d: RIGHT, pygame.K_s: DOWN, pygame.K_a: LEFT}
P2_KEYS = {pygame.K_UP: UP, pygame.K_RIGHT: RIGHT, pygame.K_DOWN: DOWN, pygame.K_LEFT: LEFT}
START_KEYS = {pygame.K_RETURN: "btn", pygame.K_SPACE: "uart"}   # BTNC, UART 0x20
PANEL_PAGES = ("look", "bram", "effects", None)  # Tab cycles; None hides the panel

OK, WARN, BAD, DIM, TEXT = (120, 220, 120), (240, 200, 80), (255, 90, 90), (140, 140, 160), (230, 230, 240)


class App:
    def __init__(self):
        self.sprites = SpriteLibrary(ASSETS)
        self.preset = DEFAULT_PRESET
        self.look = replace(LookConfig(), **PRESETS[self.preset])
        self.rules = RuleParams()
        self.paused = False                     # SW0
        self.goal_sw = 0                        # {SW15, SW14}
        self.page = 0
        self.show_cells = False
        self.fullscreen = False
        self.message = ""
        self._new_game()

    # --- configuration ---------------------------------------------------
    def _new_game(self):
        self.game = Game(self.rules)
        self.geom = self.game.geom
        self._new_renderer()

    def _new_renderer(self):
        look = self.look
        self.bike_rom = self.sprites.bike(look.bike_style)
        self.reward_roms = tuple(self.sprites.reward(look.reward_look, k) for k in (0, 1))
        self.renderer = FrameRenderer(self.geom, look, PALETTES[look.palette],
                                      self.bike_rom, self.reward_roms)
        self.renderer.redraw_all(self.game.grid)

    def next_preset(self, step):
        names = list(PRESETS)
        self.preset = names[(names.index(self.preset) + step) % len(names)]
        self.look = replace(self.look, **PRESETS[self.preset])
        self._new_renderer()
        self.message = f"{self.preset}: {PRESET_STATUS[self.preset]}"

    def change_speed(self, delta):
        """Playtest tuning only; the first build keeps STEP_TICKS."""
        k = max(MIN_STEP_TICKS, min(30, self.rules.step_ticks + delta))
        self.rules = replace(self.rules, step_ticks=k)
        self.game.rules = self.rules

    # --- checks for the panel ---------------------------------------------
    def checks(self):
        """(budget rows, RAMB18 total, clear time, flags: breaks the agreed
        format or an FPGA limit, notes: extras and estimates)."""
        font = digit_font(self.look)
        distinct = {id(r): r for r in self.reward_roms}.values()     # shared ROM counts once
        hud = self.look.hud == "on"
        rows = budget.items(self.geom, self.bike_rom.size, [r.size for r in distinct],
                            font if hud else None, ICON_ROM_BITS if hud else 0,
                            fx.lut_items(self.look, font.glyph_h))
        flags, notes = [], []
        clear = budget.clear_us(self.geom)
        if clear > budget.BLANK_US:
            flags.append(f"Arena clear {clear:,.0f} us > {budget.BLANK_US:.1f} us blanking")
        place2 = 2 * budget.placement_us(self.geom)
        if place2 > budget.BLANK_US:
            notes.append(f"G4: 2 placements worst {place2:,.0f} us > blank")
        total18 = sum(r.ramb18 for r in rows)
        if total18 > 2 * budget.RAMB36_TOTAL:
            flags.append("BRAM over the XC7A100T total")
        flags += self.bike_rom.problems + [p for r in self.reward_roms for p in r.problems]
        extras = fx.active(self.look)           # includes the HUD, which follows the core
        if extras:
            notes.append(f"{len(extras)} extra effect(s): after the core")
        return rows, total18, clear, flags, notes

    # --- main loop ----------------------------------------------------------
    def run(self):
        if sys.platform == "win32":
            try:
                import ctypes
                ctypes.windll.user32.SetProcessDPIAware()   # 1:1 pixels in fullscreen
            except Exception:
                pass
        pygame.init()
        pygame.display.set_caption("CS-256 Tron - FPGA model (PR #4)")
        self.ui_font = pygame.font.SysFont("consolas,menlo,monospace", 14)
        self.ui_bold = pygame.font.SysFont("consolas,menlo,monospace", 14, bold=True)
        desk_w, desk_h = pygame.display.get_desktop_sizes()[0]
        scale = min(1.0, (desk_w * 0.92 - PANEL_W) / SCREEN_W, desk_h * 0.85 / SCREEN_H)
        self.window_size = (int(SCREEN_W * scale) + PANEL_W, int(SCREEN_H * scale))
        self.screen = pygame.display.set_mode(self.window_size, pygame.RESIZABLE)
        frame = pygame.Surface(SIZE, 0, 32)         # fx.finish works on packed RGB
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
        """This frame's keys as board inputs, in the order they were pressed."""
        btn, uart = [], bytearray()
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
            elif self.paused and (k in P1_KEYS or k in P2_KEYS or k in START_KEYS):
                pass                            # SW0 was up when this key was pressed
            elif k in P1_KEYS:
                btn.append(BTN_OF[P1_KEYS[k]])  # one debounced button sample
            elif k in P2_KEYS:
                uart += UART_KEY[P2_KEYS[k]]
            elif k in START_KEYS:
                if START_KEYS[k] == "btn":
                    btn.append(BTN_START)
                else:
                    uart.append(0x20)
            elif k == pygame.K_m:
                self.next_preset(-1 if ev.mod & pygame.KMOD_SHIFT else 1)
            elif k == pygame.K_p:
                self.paused = not self.paused
            elif k == pygame.K_t:
                self.goal_sw = (self.goal_sw + 1) & 3
                self.message = (f"SW15:14 = {self.goal_sw:02b}: goal "
                                f"{goal_from_switches(self.goal_sw)} from the next Match")
            elif k == pygame.K_BACKSPACE:
                self.game.reset()               # requests before the reset are dropped
                btn, uart = [], bytearray()
                self.message = "Reset (CPU_RESETN)"
            elif k == pygame.K_RIGHTBRACKET:
                self.change_speed(-1)
            elif k == pygame.K_LEFTBRACKET:
                self.change_speed(+1)
            elif k == pygame.K_g:
                self.show_cells = not self.show_cells
            elif k == pygame.K_TAB:
                self.page = (self.page + 1) % len(PANEL_PAGES)
            elif k == pygame.K_F11:
                self._toggle_fullscreen()
            elif k == pygame.K_F12:
                self._screenshot()
        sw = self.goal_sw << SW_GOAL_LSB | int(self.paused) << SW_PAUSE
        return BoardInputs(tuple(btn), bytes(uart), sw)

    def _toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen
        if self.fullscreen:
            self.screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
        else:
            self.screen = pygame.display.set_mode(self.window_size, pygame.RESIZABLE)

    def _screenshot(self):
        os.makedirs(OUT, exist_ok=True)
        lk = self.look
        name = (f"L1-{self.preset}-{lk.bike_style.replace(':', '_')}-{lk.reward_look}"
                f"-{lk.palette}-{lk.trail}-{time.strftime('%Y%m%d-%H%M%S')}.png")
        path = os.path.join(OUT, name)
        pygame.image.save(self.last_frame, path)
        self.message = "Saved " + os.path.relpath(path, HERE)

    # --- drawing the window --------------------------------------------------
    def _present(self, frame, snap, fps):
        self.screen.fill((24, 24, 30))
        sw, sh = self.screen.get_size()
        panel = PANEL_PAGES[self.page] is not None and not self.fullscreen
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

        def line(text, colour=TEXT, bold=False, x=0):
            nonlocal y
            surf = (self.ui_bold if bold else self.ui_font).render(text, True, colour)
            self.screen.blit(surf, (x0 + 10 + x, y))
            y += 17

        line("FPGA MODEL - PC PLAYTEST", bold=True)
        state = snap["phase_name"] + ("  [PAUSED]" if self.paused else "")
        line(f"{state}   Round {snap['round']}  Step {snap['step']}", OK if not self.paused else WARN)
        line(f"P1 {snap['points'][0]:2d} pts {snap['lives'][0]} lives   "
             f"P2 {snap['points'][1]:2d} pts {snap['lives'][1]} lives")
        result = snap["result"]
        outcome = "" if result is None else "  Draw" if result == DRAW else f"  P{result + 1} wins"
        line(f"Goal {snap['goal']}  (T: SW15:14 = {self.goal_sw:02b}){outcome}")
        sb = snap["scoreboard"]
        line(f"Scoreboard  {sb[:4]} {sb[4:]}")
        line(f"view {scale * 100:.0f}%   {fps:4.1f} fps", DIM)
        y += 6
        rows, total18, clear, flags, notes = self.checks()
        if PANEL_PAGES[self.page] == "look":
            line(f"M STYLE: {self.preset} [{PRESET_STATUS[self.preset]}]", bold=True)
            line("Final designs: synthwave / outrun", DIM)
            line("Classic: temporary programming/test view", WARN)
            line("All styles include the HUD", DIM)
            y += 6
            line("ARENA AND SPEED", bold=True)
            line(f" {g.width} x {g.height} Cells of {g.cell_px} px, {g.hud_px} px HUD band")
            steps = GAME_HZ / rules.step_ticks
            tuned = "" if rules.step_ticks == STEP_TICKS else f"  (agreed {STEP_TICKS})"
            line(f" [ ]  {rules.step_ticks} ticks/Step = {steps:.1f} Steps/s{tuned}",
                 TEXT if not tuned else WARN)
            line(f"      {steps * g.cell_px:.0f} px/s, crosses Arena in {g.width / steps:.1f} s")
            y += 6
            line("OUTSIDE THE AGREED FORMAT OR LIMITS", bold=True)
            if not flags:
                line(" none", OK)
            for f in flags:
                line(" ! " + f, BAD)
            for n in notes:
                line(" i " + n, WARN)
        elif PANEL_PAGES[self.page] == "bram":
            line("BRAM (estimate, RAMB18 halves)", bold=True)
            for r in rows:
                tag = " LUT?" if r.maybe_lut else ""
                line(f" {r.name[:20]:<20}{r.instances}x{r.bits / 1024:6.1f}Kb{r.ramb18:3d}{tag}")
            pct = 100 * total18 / (2 * budget.RAMB36_TOTAL)
            line(f" total {total18} of {2 * budget.RAMB36_TOTAL} RAMB18 ({pct:.1f}%)",
                 OK if pct < 100 else BAD)
            line(f" Arena clear {clear:,.1f} us of {budget.BLANK_US:.1f} us",
                 OK if clear <= budget.BLANK_US else BAD)
        else:
            line("EFFECTS AND THEIR HARDWARE", bold=True)
            line(" (all extras: after the core)", DIM)
            for name in fx.active(lk):
                line(f" {name:<13}{fx.HW_COST[name]}")
        if self.message:
            y += 6
            line(self.message, WARN)
        footer = self.screen.get_height() - 7 * 17 - 8
        if y > footer:
            return                                  # window too short for the key help
        y = footer
        line("DESKTOP TEST CONTROLS (swapped)", DIM)
        line("P1 W/A/S/D -> BTNU/BTNL/BTND/BTNR", DIM)
        line("P2 arrows -> UART direction commands", DIM)
        line("Enter BTNC | Space UART Start | P SW0", DIM)
        line("T goal | Backspace reset | G Cells", DIM)
        line("M/Shift+M style | Tab panel | F11 full", DIM)
        line("F12 shot | Esc quit", DIM)


def main():
    App().run()
