"""FPGA-limit checks on the Look Prototype's rendered frames.

These guard the Development Plan's FPGA limits, the agreed sprite format
and the handout's white border against new effects, and the pulse Trail's
visibility for both Player colours. Headless (SDL dummy video driver).
Run from prototipos/tron_fpga/: python -m unittest discover -s tests
"""

import os
import unittest
from dataclasses import replace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import numpy as np  # noqa: E402
import pygame  # noqa: E402

pygame.init()
pygame.display.set_mode((1, 1))

from juego import budget  # noqa: E402
from juego.app import App  # noqa: E402
from juego.art import BIKE_STYLES, REWARD_LOOKS  # noqa: E402
from juego.candidates import PALETTES, PRESETS  # noqa: E402
from juego.rgb444 import TINT_KEY, TRANSPARENT, expand  # noqa: E402
from model import CRASH, IDLE, PLAY, BoardInputs, Game, RuleParams  # noqa: E402
from model.arena_map import EMPTY, HEAD_P1, TRAIL_P1, TRAIL_P2  # noqa: E402
from model.input_batch import BTN_OF  # noqa: E402
from model.params import BORDER_PX, SW_PAUSE  # noqa: E402
from model.turn_unit import DOWN, LEFT, RIGHT, UP  # noqa: E402


def luminance(rgb):
    r, g, b = (float(v) for v in rgb)
    return 0.299 * r + 0.587 * g + 0.114 * b


class Viewer:
    """An App driven tick by tick without a window."""

    def __init__(self, preset="core", step_ticks=4):
        self.app = App()
        self.app.look = replace(self.app.look, **PRESETS[preset])
        self.app.rules = RuleParams(step_ticks=step_ticks, crash_ticks=40, fixed_seed=True)
        self.app._new_game()
        self.frame = pygame.Surface((1280, 800), 0, 32)

    def tick(self, p1=(), start=False):
        self.app.game.tick(BoardInputs.keys(p1=p1, start=start))
        return self.draw()

    def start(self):
        self.tick(start=True)
        while self.app.game.phase != PLAY:
            self.tick()

    def draw(self):
        app = self.app
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
            self.assert_frame_ok(v.draw(), f"{preset} waiting for Start")
            v.start()
            v.tick(p1=[UP])
            while v.app.game.phase != CRASH:       # P1 drives into the top Wall
                a = v.tick()
            self.assert_frame_ok(a, f"{preset} running")
            for _ in range(12):                    # flash, then shockwave
                a = v.tick()
                if v.app.game.phase_ticks in (1, 11):
                    self.assert_frame_ok(a, f"{preset} crash")

    def test_bikes_on_edge_cells_stay_under_the_white_border(self):
        g = Viewer().app.geom
        for preset in PRESETS:
            v = Viewer(preset)
            v.start()
            game = v.app.game
            for cell, heading in (((g.x0, 30), LEFT), ((g.x1 - 1, 30), RIGHT),
                                  ((40, g.y1 - 1), DOWN)):
                game.grid.write(*game.step.head[0], EMPTY)      # testbench force
                game.grid.write(*cell, HEAD_P1)
                game.step.head = (cell, game.step.head[1])
                game.step.shown = (heading, game.step.shown[1])
                game._latch_render()
                self.assert_frame_ok(v.draw(), f"{preset} Bike at {cell}")

    def test_pulse_stripes_are_clearly_brighter_on_both_trails(self):
        v = Viewer("synthwave", step_ticks=4)
        v.start()
        for _ in range(60):                    # 15 Steps, before the Bikes meet
            a = v.tick()
        self.assertEqual(v.app.game.phase, PLAY)
        game, c = v.app.game, v.app.geom.cell_px
        pal = PALETTES[v.app.look.palette]
        for i, (code, colour) in enumerate(((TRAIL_P1, pal["p1"]), (TRAIL_P2, pal["p2"]))):
            hx, hy = game.step.head[i]
            best = 0.0
            for y in range(game.geom.y0, game.geom.y1):
                for x in range(game.geom.x0, game.geom.x1):
                    if game.grid.read(x, y) != code or max(abs(x - hx), abs(y - hy)) <= 2:
                        continue                   # skip Cells under the Bike sprite
                    cell = a[x * c:(x + 1) * c, y * c:(y + 1) * c].reshape(-1, 3)
                    best = max(best, max(luminance(p) for p in cell))
            gain = best - luminance(expand(colour))
            self.assertGreater(gain, 40, f"P{i + 1} pulse stripe is only {gain:.0f} brighter")


class KeyboardAdapterTests(unittest.TestCase):
    """The viewer's key handling, through App._events, as in one PC frame."""

    def events(self, app, *keys):
        pygame.event.clear()
        for k in keys:
            pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=k, mod=0))
        return app._events()

    def test_reset_drops_requests_queued_before_it(self):
        app = App()
        inputs = self.events(app, pygame.K_SPACE, pygame.K_UP, pygame.K_BACKSPACE)
        self.assertEqual((inputs.btn, inputs.uart), ((), b""))
        for _ in range(5):
            app.game.tick(inputs)
        self.assertEqual(app.game.phase, IDLE)

    def test_keys_become_board_samples_and_uart_bytes(self):
        app = App()
        inputs = self.events(app, pygame.K_UP, pygame.K_LEFT, pygame.K_a, pygame.K_w,
                             pygame.K_SPACE, pygame.K_RETURN)
        self.assertEqual(inputs.btn, (BTN_OF[UP], BTN_OF[LEFT], 1 << 4))
        self.assertEqual(inputs.uart, b"aw\r")

    def test_steering_and_start_while_paused_do_not_survive_resume(self):
        app = App()
        self.events(app, pygame.K_p)                              # pause
        inputs = self.events(app, pygame.K_UP, pygame.K_w, pygame.K_SPACE, pygame.K_p)
        self.assertFalse(inputs.sw >> SW_PAUSE & 1)
        self.assertEqual((inputs.btn, inputs.uart), ((), b""))
        inputs = self.events(app, pygame.K_UP)                    # after resuming
        self.assertEqual(inputs.btn, (BTN_OF[UP],))

    def test_style_changes_preserve_the_running_match_and_arena(self):
        app = App()
        app.rules = RuleParams(fixed_seed=True)
        app._new_game()
        reference = Game(app.rules)
        game = app.game
        # Change the presentation during Play, then follow both games through
        # the same head-on Crash. Every tick must retain the reference state.
        for tick in range(135):
            if tick == 30:
                self.assertEqual(game.phase, PLAY)
                app.next_preset(1)
                app.change_axis("H", 1)
                app.change_axis("3", 1)
            if tick == 60:
                app.next_preset(-1)
            inputs = BoardInputs.keys(start=(tick == 0))
            app.game.tick(inputs)
            reference.tick(inputs)
            self.assertIs(app.game, game)
            self.assertEqual(app.game.snapshot(), reference.snapshot(), f"tick {tick}")
            self.assertEqual(app.game.grid.words, reference.grid.words, f"tick {tick}")
        self.assertEqual(game.phase, CRASH)


class FormatAndBudgetTests(unittest.TestCase):
    def test_every_look_fits_bram_and_blanking_without_flags(self):
        app = App()
        for preset in PRESETS:
            app.look = replace(app.look, **PRESETS[preset])
            app._new_game()
            rows, total18, clear, flags, notes = app.checks()
            self.assertLessEqual(total18, 2 * budget.RAMB36_TOTAL, preset)
            self.assertLessEqual(clear, budget.BLANK_US, preset)
            self.assertEqual(flags, [], preset)

    def test_arena_is_8192_four_bit_words(self):
        app = App()
        arena = next(r for r in app.checks()[0] if r.name.startswith("Arena"))
        self.assertEqual((arena.depth, arena.width), (8192, 4))

    def test_core_preset_uses_no_extras(self):
        app = App()
        app.next_preset(-1)                                     # synthwave -> core
        self.assertEqual(app.preset, "core")
        self.assertEqual(app.checks()[4], [])
        self.assertEqual(app.look.hud, "off")                     # the HUD follows the core
        self.assertFalse(any(r.name.startswith("Digit font") for r in app.checks()[0]))

    def test_sprites_are_native_size_and_use_only_the_core_keys(self):
        app = App()
        for style in app.sprites.bike_styles():
            rom = app.sprites.bike(style)
            self.assertEqual((rom.size, len(rom.words)), (32, 1024), style)
            self.assertEqual(rom.problems, [], style)
        for look in REWARD_LOOKS:
            for kind in (0, 1):
                rom = app.sprites.reward(look, kind)
                self.assertEqual((rom.size, len(rom.words)), (16, 256), look)
                self.assertNotIn(0x080, rom.words, f"{look}: legacy 080 dim key")
                self.assertIn(TINT_KEY, rom.words, look)
                self.assertIn(TRANSPARENT, rom.words, look)
        for name, fn in BIKE_STYLES.items():
            self.assertNotIn(0x080, fn(32), name)


if __name__ == "__main__":
    unittest.main()
