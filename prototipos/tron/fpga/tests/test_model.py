"""Rule checks for the Game Model, against CS-256 Tron Game Mechanics.

Crash geometry is checked at the Step block (like a G2 testbench); Round and
Match consequences are checked through Game.tick, the model's frame boundary.
Run from prototipos/tron_fpga/: python -m unittest discover -s tests
"""

import unittest

from model import CRASH, MATCH_OVER, READY, RUNNING, ArenaGeometry, FrameInputs, Game, HudReserve, RuleParams
from model.arena import EMPTY, REWARD_SLOT0, TRAIL_P1, TRAIL_P2, WALL, ArenaGrid, is_reward
from model.lfsr import Lfsr
from model.rewards import find_empty_cell
from model.step import Bike, run_step
from model.steering import DOWN, LEFT, RIGHT, UP

GEOM = ArenaGeometry(cell_px=8)
RULES = RuleParams(frames_per_step=1, crash_freeze_frames=2)


def start(game):
    game.tick(FrameInputs(start=True))


def step(game, p1=(), p2=()):
    game.tick(FrameInputs(turns=(tuple(p1), tuple(p2))))


def empty_grid():
    grid = ArenaGrid(GEOM)
    grid.clear()
    return grid


def put_reward_ahead(game, player, slot):
    """Move Reward `slot` to the Cell in front of a Player's Bike."""
    x, y = game.bikes[player].head
    dx = 1 if player == 0 else -1
    game.grid.write(*game.reward_cells[slot], EMPTY)
    game.grid.write(x + dx, y, REWARD_SLOT0 + slot)
    game.reward_cells[slot] = (x + dx, y)
    return x + dx, y


class StepBlockTests(unittest.TestCase):
    def test_wall_and_trail_cells_crash_only_the_bike_entering_them(self):
        for code in (WALL, TRAIL_P1, TRAIL_P2):
            grid = empty_grid()
            grid.write(21, 50, code)
            bikes = [Bike((20, 50), RIGHT, RIGHT), Bike((80, 50), LEFT, LEFT)]
            result = run_step(bikes, grid)
            self.assertEqual(result.crashed, (True, False), code)

    def test_head_on_same_cell_crashes_both(self):
        grid = empty_grid()
        bikes = [Bike((40, 50), RIGHT, RIGHT), Bike((41, 49), DOWN, DOWN)]
        result = run_step(bikes, grid)
        self.assertEqual(result.crashed, (True, True))
        self.assertTrue(result.head_on)

    def test_head_on_swap_crashes_both(self):
        grid = empty_grid()
        bikes = [Bike((40, 50), RIGHT, RIGHT), Bike((41, 50), LEFT, LEFT)]
        result = run_step(bikes, grid)
        self.assertEqual(result.crashed, (True, True))
        self.assertTrue(result.head_on)

    def test_crashed_bike_stays_put(self):
        grid = empty_grid()
        grid.write(41, 50, WALL)
        bikes = [Bike((40, 50), RIGHT, RIGHT), Bike((80, 50), LEFT, LEFT)]
        run_step(bikes, grid)
        self.assertEqual(bikes[0].head, (40, 50))
        self.assertEqual(grid.read(41, 50), WALL)


class TurnTests(unittest.TestCase):
    def test_reversal_is_ignored(self):
        game = Game(GEOM, RULES)
        start(game)
        x, y = game.bikes[0].head
        step(game, p1=[LEFT])
        self.assertEqual(game.bikes[0].head, (x + 1, y))

    def test_last_valid_request_between_steps_wins(self):
        # Heading RIGHT, one request per frame across a 4-frame Step:
        # UP then DOWN -> DOWN; UP then LEFT (a reversal) -> UP.
        rules = RuleParams(frames_per_step=4, crash_freeze_frames=2)
        for requests, expected in (([UP, DOWN], DOWN), ([UP, LEFT], UP)):
            game = Game(GEOM, rules)
            start(game)
            for r in requests:
                step(game, p1=[r])
            while game.step_count == 0:
                step(game)
            self.assertEqual(game.bikes[0].heading, expected, requests)


class RoundTests(unittest.TestCase):
    def test_wall_crash_costs_a_life_and_pays_survival_bonus(self):
        game = Game(GEOM, RULES)
        start(game)
        step(game, p1=[UP])
        while game.phase == RUNNING:
            step(game)
        self.assertEqual(game.phase, CRASH)
        self.assertEqual(game.lives, [2, 3])
        self.assertEqual(game.points, [0, RULES.survival_bonus])

    def test_survivor_moves_and_collects_in_the_crash_step(self):
        game = Game(GEOM, RULES)
        x, y = game.geom.x1 - 1, game.bikes[0].head[1]     # P1 faces the right Wall
        game.bikes[0].head = (x, y)
        game.grid.write(x, y, TRAIL_P1)
        cell = put_reward_ahead(game, 1, 0)
        start(game)
        step(game)
        self.assertEqual(game.crashed, (True, False))
        self.assertEqual(game.bikes[1].head, cell)
        self.assertEqual(game.grid.read(*cell), TRAIL_P2)
        self.assertEqual(game.points, [0, RULES.reward_values[0] + RULES.survival_bonus])

    def test_own_trail_crash(self):
        game = Game(GEOM, RULES)
        start(game)
        for turn in (UP, LEFT, DOWN, RIGHT):  # loops back onto the start Cell
            step(game, p1=[turn])
        self.assertEqual(game.crashed, (True, False))

    def test_head_on_between_start_cells_costs_both_a_life_and_no_bonus(self):
        game = Game(GEOM, RULES)
        start(game)
        while game.phase == RUNNING:
            step(game)
        self.assertTrue(game.head_on)
        self.assertEqual(game.lives, [2, 2])
        self.assertEqual(game.points, [0, 0])

    def test_next_round_resets_the_arena_and_waits_for_start(self):
        game = Game(GEOM, RULES)
        start(game)
        while game.phase == RUNNING:
            step(game)
        while game.phase == CRASH:
            step(game)
        self.assertEqual(game.phase, READY)
        trails = sum(1 for w in game.grid.words if w in (TRAIL_P1, TRAIL_P2))
        self.assertEqual(trails, 2)


class RewardTests(unittest.TestCase):
    def test_collecting_pays_its_value_and_respawns_on_an_empty_cell(self):
        game = Game(GEOM, RULES)
        cell = put_reward_ahead(game, 0, 2)             # slot 2 is the +5
        start(game)
        step(game)
        self.assertEqual(game.points[0], RULES.reward_values[2])
        self.assertEqual(game.grid.read(*cell), TRAIL_P1)
        new = game.reward_cells[2]
        self.assertNotEqual(new, cell)
        self.assertTrue(GEOM.in_interior(*new))
        self.assertEqual(game.grid.read(*new), REWARD_SLOT0 + 2)
        self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)

    def test_points_stop_at_cap(self):
        rules = RuleParams(frames_per_step=1, crash_freeze_frames=2, points_cap=99)
        game = Game(GEOM, rules)
        game.points = [97, 0]
        put_reward_ahead(game, 0, 2)
        start(game)
        step(game)
        self.assertEqual(game.points[0], 99)


class RewardPlacementTests(unittest.TestCase):
    def test_last_empty_cell_is_found_and_a_full_arena_gives_none(self):
        grid = empty_grid()
        g = GEOM
        last = (g.x1 - 1, g.y1 - 1)
        for y in range(g.y0, g.y1):
            for x in range(g.x0, g.x1):
                if (x, y) != last:
                    grid.write(x, y, TRAIL_P1)
        self.assertEqual(find_empty_cell(grid, Lfsr(1)), last)
        grid.write(*last, TRAIL_P2)
        self.assertIsNone(find_empty_cell(grid, Lfsr(1)))


class MatchTests(unittest.TestCase):
    def play_round(self, game, p1=()):
        if game.phase == READY:
            start(game)
        step(game, p1=p1)
        while game.phase == RUNNING:
            step(game)
        while game.phase == CRASH:
            step(game)

    def test_points_carry_over_and_decide_the_winner_not_lives(self):
        game = Game(GEOM, RULES)
        game.points = [50, 0]
        self.play_round(game, p1=[UP])       # P1 hits the top Wall every Round
        self.assertEqual(game.points, [50, RULES.survival_bonus])
        for _ in range(2):
            self.play_round(game, p1=[UP])
        self.assertEqual(game.phase, MATCH_OVER)
        self.assertEqual(game.lives, [0, 3])
        self.assertEqual(game.winner, 0)
        start(game)
        self.assertEqual(game.phase, RUNNING)
        self.assertEqual((game.lives, game.points), ([3, 3], [0, 0]))

    def test_both_crash_on_last_life_with_equal_points_is_a_draw(self):
        game = Game(GEOM, RULES)
        for _ in range(3):
            self.play_round(game)            # Head-on in the middle every Round
        self.assertEqual(game.phase, MATCH_OVER)
        self.assertEqual(game.lives, [0, 0])
        self.assertIsNone(game.winner)


class GeometryTests(unittest.TestCase):
    def test_wall_covers_the_border_and_hud_area(self):
        for cell in (4, 8, 16):
            for hud in (HudReserve(), HudReserve(top=48), HudReserve(left=96, right=96)):
                g = ArenaGeometry(cell, hud)
                self.assertGreaterEqual(g.x0 * cell, 10 + hud.left)
                self.assertGreaterEqual(g.y0 * cell, 10 + hud.top)
                self.assertLessEqual(g.x1 * cell, 1280 - 10 - hud.right)
                self.assertLessEqual(g.y1 * cell, 800 - 10 - hud.bottom)


if __name__ == "__main__":
    unittest.main()
