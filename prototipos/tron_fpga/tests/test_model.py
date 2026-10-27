"""Rule checks for the Game Model, against CS-256 Tron Agreed Specification 2026-10-20.

Crash geometry is checked at the Step block (like a G2 testbench); Round and
Match consequences are checked through Game.tick, one game-clock tick at a
time. Most tests use one tick per Step and a short Crash display.
Run from prototipos/tron_fpga/: python -m unittest discover -s tests
"""

import random
import re
import unittest
from pathlib import Path

from model import (CRASH, DRAW, IDLE, MATCH_OVER, PLAY, READY, GEOMETRY, Game,
                   RuleParams, TickInputs)
from model import arena, params
from model.arena import (EMPTY, HEAD_P1, HEAD_P2, REWARD_SLOT0, TRAIL_P1, TRAIL_P2, WALL,
                         ArenaGrid, is_reward)
from model.lfsr import Lfsr
from model.rewards import find_empty_cell
from model.scoreboard import Scoreboard
from model.step import Bike, run_step
from model.steering import DOWN, LEFT, RIGHT, UP, next_cell

RULES = RuleParams(step_ticks=1, crash_ticks=2, fixed_seed=True)
CONTRACT = (Path(__file__).resolve().parents[3] / "proyecto_final"
            / "Contrato de interfaces game_top (CS 256).md")


def start(game, goal_sw=0, paused=False):
    game.tick(TickInputs(start=True, goal_sw=goal_sw, paused=paused))


def tick(game, p1=(), p2=(), **kw):
    game.tick(TickInputs(turns=(tuple(p1), tuple(p2)), **kw))


def started(rules=RULES, goal_sw=0):
    game = Game(rules)
    start(game, goal_sw)
    return game


def empty_grid():
    grid = ArenaGrid()
    grid.clear()
    return grid


def place(game, player, cell, heading):
    """Arrange a Bike: move its head code and set its Heading."""
    b = game.bikes[player]
    game.grid.write(*b.head, EMPTY)
    game.grid.write(*cell, arena.HEAD[player])
    b.head, b.heading, b.pending = cell, heading, heading


def put_reward_ahead(game, player, slot):
    """Move Reward `slot` to the Cell in front of a Player's Bike."""
    b = game.bikes[player]
    cell = next_cell(b.head, b.heading)
    if game.reward_cells[slot] is not None:
        game.grid.write(*game.reward_cells[slot], EMPTY)
    game.grid.write(*cell, REWARD_SLOT0 + slot)
    game.reward_cells[slot] = cell
    return cell


def run_until(game, phase_left, **kw):
    while game.phase == phase_left:
        tick(game, **kw)


class ContractTests(unittest.TestCase):
    """Constants must match game_pkg in the interface contract."""

    def test_constants_match_contract_game_pkg(self):
        if not CONTRACT.exists():
            self.skipTest("interface contract not found")
        text = CONTRACT.read_text(encoding="utf-8")
        pkg = text[text.index("package game_pkg;"):text.index("endpackage")]
        values = {}
        for name, raw in re.findall(r"(\w+)\s*=\s*(\d+'[dh][0-9A-Fa-f]+|\d+)\b", pkg):
            if "'" in raw:
                base, digits = raw.split("'")[1][0], raw.split("'")[1][1:]
                values[name] = int(digits, 16 if base == "h" else 10)
            else:
                values[name] = int(raw)
        expected = {
            "BORDER_PX": params.BORDER_PX, "TILE_SHIFT": params.TILE_SHIFT,
            "GRID_W": params.GRID_W, "GRID_H": params.GRID_H, "HUD_ROWS": params.HUD_ROWS,
            "CX_W": params.CX_W, "CY_W": params.CY_W, "ADDR_W": params.ADDR_W,
            "PLAY_CX_MIN": params.PLAY_CX_MIN, "PLAY_CX_MAX": params.PLAY_CX_MAX,
            "PLAY_CY_MIN": params.PLAY_CY_MIN, "PLAY_CY_MAX": params.PLAY_CY_MAX,
            "CELL_EMPTY": arena.EMPTY, "CELL_WALL": arena.WALL,
            "CELL_P1_TRAIL": arena.TRAIL_P1, "CELL_P1_HEAD": arena.HEAD_P1,
            "CELL_P2_TRAIL": arena.TRAIL_P2, "CELL_P2_HEAD": arena.HEAD_P2,
            "CELL_CRASH": arena.CRASH, "CELL_RESERVED": arena.RESERVED,
            "CELL_REWARD0": REWARD_SLOT0, "CELL_REWARD1": REWARD_SLOT0 + 1,
            "CELL_REWARD2": REWARD_SLOT0 + 2,
            "DIR_UP": UP, "DIR_RIGHT": RIGHT, "DIR_DOWN": DOWN, "DIR_LEFT": LEFT,
            "STEP_TICKS": params.STEP_TICKS, "LIVES_START": params.LIVES_START,
            "REWARD_PTS0": params.REWARD_PTS0, "REWARD_PTS1": params.REWARD_PTS1,
            "REWARD_PTS2": params.REWARD_PTS2, "SURVIVAL_BONUS": params.SURVIVAL_BONUS,
            "CRASH_TICKS": params.CRASH_TICKS, "SCORE_VIEW_TICKS": params.SCORE_VIEW_TICKS,
            "SAL_P1_CX": params.SAL_P1_CX, "SAL_P2_CX": params.SAL_P2_CX, "SAL_CY": params.SAL_CY,
            "COLOR_TRANSPARENT": 0x000, "COLOR_TINT_KEY": 0x0F0,
        }
        for name, value in expected.items():
            self.assertEqual(values.get(name), value, name)

    def test_points_and_lives_widths_hold_every_legal_value(self):
        self.assertEqual(params.POINTS_MAX, 45)            # 39 + 3 + 3 at goal 40
        self.assertLess(params.POINTS_MAX, 1 << params.POINTS_W)
        self.assertEqual(params.POINTS_W, 6)
        self.assertEqual(params.LIVES_W, 2)


class ArenaTests(unittest.TestCase):
    def test_layout_is_the_agreed_working_layout(self):
        g = GEOMETRY
        self.assertEqual((g.width, g.height), (78, 44))
        self.assertEqual((g.x0 * 16, g.x1 * 16 - 1, g.y0 * 16, g.y1 * 16 - 1), (16, 1263, 80, 783))
        self.assertEqual(g.hud_px, 64)
        self.assertEqual(g.start_cells(), ((20, 27), (59, 27)))

    def test_clear_leaves_only_the_playable_cells_empty(self):
        grid = empty_grid()
        self.assertEqual(len(grid.words), 8192)
        self.assertEqual(grid.words.count(EMPTY), 78 * 44)
        self.assertEqual(grid.words.count(WALL), 8192 - 78 * 44)
        for x, y in ((40, 0), (40, 3), (40, 4), (40, 49), (0, 27), (79, 27), (100, 27), (40, 60)):
            self.assertEqual(grid.read(x, y), WALL, (x, y))   # HUD band, Wall ring, padding

    def test_address_is_cy_then_cx(self):
        self.assertEqual(arena.address(5, 3), (3 << 7) | 5)
        self.assertEqual(arena.address(127, 63), 8191)

    def test_coordinates_wrap_unsigned_into_padding(self):
        self.assertEqual(next_cell((0, 10), LEFT), (127, 10))
        self.assertEqual(next_cell((10, 0), UP), (10, 63))


class StepBlockTests(unittest.TestCase):
    def test_wall_trail_and_head_cells_crash_only_the_bike_entering_them(self):
        for code in (WALL, TRAIL_P1, HEAD_P1, TRAIL_P2, HEAD_P2):
            grid = empty_grid()
            grid.write(21, 20, code)
            bikes = [Bike((20, 20), RIGHT, RIGHT), Bike((60, 20), LEFT, LEFT)]
            result = run_step(bikes, grid)
            self.assertEqual(result.crashed, (True, False), code)

    def test_head_on_same_cell_crashes_both(self):
        grid = empty_grid()
        bikes = [Bike((40, 20), RIGHT, RIGHT), Bike((41, 19), DOWN, DOWN)]
        result = run_step(bikes, grid)
        self.assertEqual(result.crashed, (True, True))
        self.assertTrue(result.head_on)

    def test_head_on_swap_crashes_both(self):
        grid = empty_grid()
        bikes = [Bike((40, 20), RIGHT, RIGHT), Bike((41, 20), LEFT, LEFT)]
        result = run_step(bikes, grid)
        self.assertEqual(result.crashed, (True, True))
        self.assertTrue(result.head_on)

    def test_crashed_bike_stays_put_and_survivor_leaves_trail_and_head(self):
        grid = empty_grid()
        grid.write(40, 20, HEAD_P1)
        grid.write(60, 20, HEAD_P2)
        grid.write(41, 20, WALL)
        bikes = [Bike((40, 20), RIGHT, RIGHT), Bike((60, 20), LEFT, LEFT)]
        run_step(bikes, grid)
        self.assertEqual(bikes[0].head, (40, 20))
        self.assertEqual(grid.read(40, 20), HEAD_P1)
        self.assertEqual(bikes[1].head, (59, 20))
        self.assertEqual((grid.read(60, 20), grid.read(59, 20)), (TRAIL_P2, HEAD_P2))


class TurnTests(unittest.TestCase):
    def pending_after(self, *requests, heading=RIGHT):
        """Feed requests one per tick before a 4-tick Step; return the new Heading."""
        game = started(RuleParams(step_ticks=4, crash_ticks=2, fixed_seed=True))
        place(game, 0, (40, 27), heading)
        for r in requests:
            tick(game, p1=[r])
        while game.step_count == 0:
            tick(game)
        return game.bikes[0].heading

    def test_reversal_is_ignored(self):
        self.assertEqual(self.pending_after(LEFT), RIGHT)

    def test_last_valid_request_wins(self):
        self.assertEqual(self.pending_after(UP, DOWN), DOWN)

    def test_invalid_requests_do_not_cancel_a_pending_turn(self):
        self.assertEqual(self.pending_after(UP, LEFT), UP)      # reversal
        self.assertEqual(self.pending_after(UP, RIGHT), UP)     # same Heading

    def test_tied_board_sample_uses_up_right_down_left(self):
        self.assertEqual(self.pending_after(frozenset((UP, DOWN))), UP)
        self.assertEqual(self.pending_after(frozenset((DOWN, LEFT))), DOWN)   # LEFT is a reversal
        self.assertEqual(self.pending_after(frozenset((LEFT, RIGHT)), heading=UP), RIGHT)

    def test_turns_are_ignored_outside_play(self):
        game = started()
        tick(game, p1=[UP], paused=True)
        self.assertEqual(game.bikes[0].pending, RIGHT)
        tick(game, p1=[UP])                                     # P1 heads for the top Wall
        run_until(game, PLAY)
        tick(game, p1=[DOWN], p2=[UP])                          # Crash display
        run_until(game, CRASH)
        self.assertEqual(game.phase, READY)
        tick(game, p1=[UP], p2=[UP])                            # ready wait
        self.assertEqual([b.pending for b in game.bikes], [RIGHT, LEFT])


class RoundTests(unittest.TestCase):
    def test_power_up_waits_for_start_with_walls_only(self):
        game = Game(RULES)
        self.assertEqual(game.phase, IDLE)
        self.assertIsNone(game.bikes)
        self.assertEqual(game.grid.words.count(EMPTY), 78 * 44)
        for _ in range(5):
            tick(game, p1=[UP])
        self.assertEqual(game.phase, IDLE)

    def test_one_start_prepares_everything_and_releases_the_round(self):
        game = started()
        self.assertEqual(game.phase, PLAY)
        self.assertEqual(game.grid.read(20, 27), HEAD_P1)
        self.assertEqual(game.grid.read(59, 27), HEAD_P2)
        self.assertTrue(all(c is not None for c in game.reward_cells))
        self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)
        self.assertEqual((game.points, game.lives, game.goal), ([0, 0], [3, 3], 10))

    def test_first_step_comes_step_ticks_after_start(self):
        game = started(RuleParams(fixed_seed=True))
        for _ in range(params.STEP_TICKS - 1):
            tick(game)
        self.assertEqual(game.step_count, 0)
        tick(game)
        self.assertEqual(game.bikes[0].head, (21, 27))

    def test_each_wall_crashes(self):
        for heading, cell in ((UP, (40, 5)), (DOWN, (40, 48)), (LEFT, (1, 20)), (RIGHT, (78, 20))):
            game = started()
            place(game, 0, cell, heading)
            tick(game)
            self.assertEqual(game.crashed, (True, False), heading)

    def test_wall_crash_costs_a_life_and_pays_the_survival_bonus(self):
        game = started()
        tick(game, p1=[UP])
        run_until(game, PLAY)
        self.assertEqual(game.phase, CRASH)
        self.assertEqual(game.lives, [2, 3])
        self.assertEqual(game.points, [0, 3])

    def test_own_trail_and_other_trail_crash(self):
        game = started()
        for turn in (UP, LEFT, DOWN, RIGHT):                    # loops back onto its Trail
            tick(game, p1=[turn])
        self.assertEqual(game.crashed, (True, False))
        game = started()
        place(game, 1, (20, 25), DOWN)                          # P2 drives into P1's Trail
        tick(game)
        tick(game)
        self.assertEqual(game.crashed, (False, True))

    def test_swap_head_on_from_the_default_starts_costs_both_a_life_and_no_bonus(self):
        game = started()
        run_until(game, PLAY)
        self.assertTrue(game.head_on)
        self.assertEqual(game.lives, [2, 2])
        self.assertEqual(game.points, [0, 0])
        self.assertEqual(game.bikes[0].head, (39, 27))          # last valid head Cells
        self.assertEqual(game.bikes[1].head, (40, 27))

    def test_survivor_moves_and_collects_in_the_crash_step(self):
        game = started()
        place(game, 0, (78, 27), RIGHT)                         # P1 faces the right Wall
        cell = put_reward_ahead(game, 1, 2)
        tick(game)
        self.assertEqual(game.crashed, (True, False))
        self.assertEqual(game.bikes[1].head, cell)
        self.assertEqual(game.grid.read(*cell), HEAD_P2)
        self.assertEqual(game.points, [0, 3 + 3])

    def test_crash_display_ignores_start_then_next_round_needs_a_fresh_start(self):
        game = started()
        run_until(game, PLAY)
        crash_step = game.step_count
        run_until(game, CRASH, start=True)                      # Start held through the display
        self.assertEqual(game.phase, READY)
        self.assertEqual(game.step_count, 0)
        self.assertNotEqual(crash_step, 0)
        trails = sum(1 for w in game.grid.words if w in (TRAIL_P1, TRAIL_P2))
        self.assertEqual(trails, 0)
        self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)
        tick(game)
        self.assertEqual(game.phase, READY)
        start(game)
        self.assertEqual(game.phase, PLAY)


class RewardTests(unittest.TestCase):
    def test_collecting_pays_its_value_and_respawns_on_an_empty_cell(self):
        for slot, value in enumerate((1, 1, 3)):
            game = started()
            cell = put_reward_ahead(game, 0, slot)
            tick(game)
            self.assertEqual(game.points[0], value)
            self.assertEqual(game.grid.read(*cell), HEAD_P1)
            new = game.reward_cells[slot]
            self.assertNotEqual(new, cell)
            self.assertTrue(GEOMETRY.in_interior(*new))
            self.assertEqual(game.grid.read(*new), REWARD_SLOT0 + slot)
            self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)

    def test_no_points_cap(self):
        game = started(goal_sw=3)
        game.points = [99, 0]
        put_reward_ahead(game, 0, 2)
        tick(game)
        self.assertEqual(game.points[0], 102)

    def test_last_empty_cell_is_found_and_a_full_arena_gives_none(self):
        grid = empty_grid()
        g = GEOMETRY
        last = (g.x1 - 1, g.y1 - 1)
        for y in range(g.y0, g.y1):
            for x in range(g.x0, g.x1):
                if (x, y) != last:
                    grid.write(x, y, TRAIL_P1)
        self.assertEqual(find_empty_cell(grid, Lfsr(1)), last)
        grid.write(*last, TRAIL_P2)
        self.assertIsNone(find_empty_cell(grid, Lfsr(1)))

    def test_full_arena_leaves_a_collected_slot_absent(self):
        game = started()
        cell = put_reward_ahead(game, 0, 1)
        for y in range(GEOMETRY.y0, GEOMETRY.y1):
            for x in range(GEOMETRY.x0, GEOMETRY.x1):
                if game.grid.read(x, y) == EMPTY:
                    game.grid.write(x, y, TRAIL_P2)
        tick(game)
        self.assertEqual(game.bikes[0].head, cell)
        self.assertIsNone(game.reward_cells[1])

    def test_fixed_seed_repeats_and_start_timing_changes_the_sequence(self):
        def rewards(rules, idle_ticks):
            game = Game(rules)
            for _ in range(idle_ticks):
                tick(game)
            start(game)
            return list(game.reward_cells)
        self.assertEqual(rewards(RULES, 3), rewards(RULES, 50))
        normal = RuleParams(step_ticks=1, crash_ticks=2)
        self.assertNotEqual(rewards(normal, 3), rewards(normal, 50))


class MatchTests(unittest.TestCase):
    def crash_p2_into_wall(self, game):
        place(game, 1, (78, 30), RIGHT)

    def test_goal_without_a_crash_ends_the_match_at_once(self):
        game = started(goal_sw=1)                               # goal 20
        game.points = [19, 0]
        put_reward_ahead(game, 0, 2)
        tick(game)
        self.assertEqual(game.points[0], 22)                    # full total, no clamp
        self.assertEqual((game.phase, game.result), (MATCH_OVER, 0))

    def test_match_ending_crash_shows_the_display_and_keeps_the_full_total(self):
        game = started(goal_sw=3)                               # goal 40
        game.points = [39, 0]
        put_reward_ahead(game, 0, 2)
        self.crash_p2_into_wall(game)
        tick(game)
        self.assertEqual(game.points[0], 45)
        self.assertEqual((game.phase, game.result), (CRASH, 0))
        rounds, heads = game.round_index, [b.head for b in game.bikes]
        run_until(game, CRASH, start=True)
        self.assertEqual(game.phase, MATCH_OVER)
        self.assertEqual(game.round_index, rounds)              # no new Round prepared
        self.assertEqual([b.head for b in game.bikes], heads)

    def test_both_reach_the_goal_in_one_step(self):
        for slots, points, result in (((2, 0), [12, 10], 0), ((0, 1), [10, 10], DRAW)):
            game = started()
            place(game, 1, (40, 30), LEFT)
            game.points = [9, 9]
            put_reward_ahead(game, 0, slots[0])
            put_reward_ahead(game, 1, slots[1])
            tick(game)
            self.assertEqual(game.points, points)
            self.assertEqual((game.phase, game.result), (MATCH_OVER, result))

    def test_both_lose_their_final_life_in_one_step(self):
        for points, result in (([5, 3], 0), ([3, 5], 1), ([4, 4], DRAW)):
            game = started()
            game.lives, game.points = [1, 1], list(points)
            run_until(game, PLAY)
            self.assertEqual(game.result, result)
            run_until(game, CRASH)
            self.assertEqual(game.phase, MATCH_OVER)
            self.assertEqual(game.lives, [0, 0])

    def test_losing_the_final_life_loses_even_with_more_points(self):
        game = started()
        game.lives, game.points = [1, 3], [9, 0]
        tick(game, p1=[UP])
        run_until(game, PLAY)
        self.assertEqual((game.points, game.result), ([9, 3], 1))

    def test_goal_is_captured_only_when_a_new_match_starts(self):
        game = started(goal_sw=1)
        self.assertEqual(game.goal, 20)
        tick(game, goal_sw=3)
        self.assertEqual(game.goal, 20)
        game.points = [19, 0]
        put_reward_ahead(game, 0, 0)
        tick(game, goal_sw=3)
        self.assertEqual((game.phase, game.result), (MATCH_OVER, 0))
        start(game, goal_sw=3)
        self.assertEqual((game.phase, game.goal), (PLAY, 40))
        self.assertEqual((game.points, game.lives), ([0, 0], [3, 3]))


class PauseAndResetTests(unittest.TestCase):
    def test_pause_freezes_steps_and_timers_and_ignores_start(self):
        game = started(RuleParams(step_ticks=3, crash_ticks=2, fixed_seed=True))
        for _ in range(10):
            tick(game, paused=True)
        self.assertEqual((game.step_count, game.step_timer), (0, 0))
        game = started()
        run_until(game, PLAY)
        for _ in range(10):
            tick(game, paused=True)
        self.assertEqual(game.phase, CRASH)
        run_until(game, CRASH)
        start(game, paused=True)
        self.assertEqual(game.phase, READY)

    def test_reset_returns_to_waiting_for_start(self):
        game = started(goal_sw=2)
        tick(game, p1=[UP])
        game.reset()
        self.assertEqual(game.phase, IDLE)
        self.assertIsNone(game.bikes)
        self.assertEqual((game.points, game.lives), ([0, 0], [3, 3]))
        self.assertEqual(game.grid.words.count(EMPTY), 78 * 44)


class ScoreboardTests(unittest.TestCase):
    def test_banks_and_views(self):
        sb = Scoreboard(3)
        self.assertEqual(sb.digits([7, 12], [3, 1]), "P212P107")   # P2 left, P1 right
        for _ in range(3):
            sb.tick()
        self.assertEqual(sb.digits([7, 12], [3, 1]), "L201L103")
        for _ in range(3):
            sb.tick()
        self.assertEqual(sb.view, 0)

    def test_view_keeps_cycling_in_pause_and_a_new_match_starts_on_points(self):
        game = Game(RuleParams(score_view_ticks=4, fixed_seed=True))
        for _ in range(4):
            tick(game, paused=True)
        self.assertTrue(game.snapshot()["scoreboard"].startswith("L2"))
        start(game)
        self.assertTrue(game.snapshot()["scoreboard"].startswith("P2"))


class LongGameTests(unittest.TestCase):
    def test_random_play_keeps_the_arena_and_scores_consistent(self):
        rng = random.Random(1)
        game = Game(RuleParams(step_ticks=1, crash_ticks=2, fixed_seed=True))
        for _ in range(6000):
            turns = [[rng.randrange(4)] if rng.random() < 0.3 else [] for _ in range(2)]
            tick(game, *turns, start=rng.random() < 0.2, goal_sw=rng.randrange(4))
            if game.bikes is None:
                continue
            for slot, cell in enumerate(game.reward_cells):
                if cell is not None:
                    self.assertTrue(GEOMETRY.in_interior(*cell))
                    self.assertEqual(game.grid.read(*cell), REWARD_SLOT0 + slot)
            for i, b in enumerate(game.bikes):
                self.assertEqual(game.grid.read(*b.head), arena.HEAD[i])
            self.assertLessEqual(max(game.points), params.POINTS_MAX)
            self.assertTrue(all(0 <= n <= 3 for n in game.lives))
            if game.phase == PLAY:
                self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)),
                                 sum(c is not None for c in game.reward_cells))


if __name__ == "__main__":
    unittest.main()
