"""FPGA-limit checks on the Look Prototype's rendered frames.

These guard the Development Plan's "FPGA limits for the Look Prototype"
and the handout's white border against new effects, and the pulse Trail's
visibility for both Player colours. Headless (SDL dummy video driver).
Run from prototipos/look/: python -m unittest discover -s tests
"""

import os
import unittest
from dataclasses import replace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import numpy as np  # noqa: E402
import pygame  # noqa: E402

pygame.init()
pygame.display.set_mode((1, 1))

from look import budget  # noqa: E402
from look.app import App  # noqa: E402
from look.art import BIKE_STYLES, REWARD_LOOKS  # noqa: E402
from look.candidates import PALETTES, PRESETS  # noqa: E402
from look.rgb444 import expand  # noqa: E402
from model import CRASH, FrameInputs, RuleParams  # noqa: E402
from model.arena import TRAIL_P1, TRAIL_P2  # noqa: E402
from model.params import BORDER_PX  # noqa: E402
from model.steering import UP  # noqa: E402


def luminance(rgb):
    r, g, b = (float(v) for v in rgb)
    return 0.299 * r + 0.587 * g + 0.114 * b


class Viewer:
    """An App driven frame by frame without a window."""

    def __init__(self, preset=None, frames_per_step=1):
        self.app = App()
        if preset:
            self.app.look = replace(self.app.look, **PRESETS[preset])
        self.app.rules = RuleParams(frames_per_step=frames_per_step, crash_freeze_frames=40)
        self.app._new_game()
        self.frame = pygame.Surface((1280, 800), 0, 32)

    def tick(self, p1=(), start=False):
        app = self.app
        app.game.tick(FrameInputs(turns=(tuple(p1), ()), start=start))
        app.renderer.update_cells(app.game.grid)
        app.renderer.draw(self.frame, app.game.snapshot())
        return pygame.surfarray.array3d(self.frame)


class FrameLimitTests(unittest.TestCase):
    def assert_frame_ok(self, a, what):
        self.assertTrue((a % 17 == 0).all(), f"{what}: a channel is not an RGB444 level")
        b = BORDER_PX
        for edge in (a[:b], a[-b:], a[:, :b], a[:, -b:]):
            self.assertTrue((edge == 255).all(), f"{what}: the white border was changed")

    def test_every_preset_stays_rgb444_and_keeps_the_white_border(self):
        for preset in PRESETS:
            v = Viewer(preset)
            v.tick(start=True)
            v.tick(p1=[UP])
            while v.app.game.phase != CRASH:       # P1 drives into the top Wall
                a = v.tick()
            self.assert_frame_ok(a, f"{preset} running")
            for _ in range(12):                    # flash, then shockwave
                a = v.tick()
                if v.app.game.phase_frames in (1, 11):
                    self.assert_frame_ok(a, f"{preset} crash")

    def test_pulse_stripes_are_clearly_brighter_on_both_trails(self):
        v = Viewer("synthwave", frames_per_step=4)
        v.tick(start=True)
        for _ in range(80):
            a = v.tick()
        game, c = v.app.game, v.app.geom.cell_px
        pal = PALETTES[v.app.look.palette]
        for i, (code, colour) in enumerate(((TRAIL_P1, pal["p1"]), (TRAIL_P2, pal["p2"]))):
            hx, hy = game.bikes[i].head
            best = 0.0
            for y in range(game.geom.y0, game.geom.y1):
                for x in range(game.geom.x0, game.geom.x1):
                    if game.grid.read(x, y) != code or max(abs(x - hx), abs(y - hy)) <= 4:
                        continue                   # skip Cells under the Bike sprite
                    cell = a[x * c:(x + 1) * c, y * c:(y + 1) * c].reshape(-1, 3)
                    best = max(best, max(luminance(p) for p in cell))
            gain = best - luminance(expand(colour))
            self.assertGreater(gain, 40, f"P{i + 1} pulse stripe is only {gain:.0f} brighter")


class BudgetTests(unittest.TestCase):
    def test_default_look_fits_bram_and_blanking(self):
        app = App()
        rows, total18, clear, flags, notes = app.checks()
        self.assertLessEqual(total18, 2 * budget.RAMB36_TOTAL)
        self.assertLessEqual(clear, budget.BLANK_US)

    def test_generated_art_is_square_power_of_two(self):
        for size in (16, 32, 64):
            for name, fn in BIKE_STYLES.items():
                self.assertEqual(len(fn(size)), size * size, name)
        for small, big in REWARD_LOOKS.values():
            for fn in (small, big):
                for size in (4, 8, 16, 32):
                    self.assertEqual(len(fn(size)), size * size, fn.__name__)


if __name__ == "__main__":
    unittest.main()
