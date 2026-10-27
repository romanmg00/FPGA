"""Rule and block checks for the Game Model, against CS-256 Tron Agreed Specification 2026-10-20.

Block tests drive one planned HDL module through its ports, like a module
testbench: step_resolve, turn_unit, input_batch, the mailbox, arena_ctrl
and the Scoreboard. System tests drive Game.tick with board inputs, one
game-clock tick at a time, at the agreed 6 ticks per Step with a short
Crash display. An input given with tick t reaches the game at edge t + 2,
and a Step resolves STEP_LATENCY ticks after its launch.

Run from prototipos/tron_fpga/: python -m unittest discover -s tests
"""

import random
import re
import unittest
from pathlib import Path

from model import (CRASH, DRAW, IDLE, MATCH_OVER, PLAY, PREP, READY, GEOMETRY, BoardInputs, Game,
                   RuleParams)
from model import arena_map, params
from model.arena_ctrl import ArenaCtrl
from model.arena_map import (EMPTY, HEAD_P1, HEAD_P2, REWARD_SLOT0, TRAIL_P1, TRAIL_P2, WALL,
                             ArenaMap, is_reward)
from model.input_batch import InputBatch, uart_decode
from model.lfsr import Lfsr
from model.mailbox import OP_COMMIT, OP_PREPARE, OP_READ2, Mailbox
from model.reward_place import find_empty_cell
from model.seg7 import GLYPHS, PageTimer, digits, segments
from model.step_unit import S_COMMIT, S_IDLE, S_READ, step_resolve
from model.turn_unit import DOWN, LEFT, RIGHT, UP, TurnUnit, next_cell

RULES = RuleParams(crash_ticks=8, fixed_seed=True)
CONTRACT = (Path(__file__).resolve().parents[3] / "proyecto_final"
            / "Contrato de interfaces game_top (CS 256).md")


# --- system-test helpers -------------------------------------------------------

def tick(game, p1=(), p2=(), start=False, paused=False, goal_sw=0):
    game.tick(BoardInputs.keys(p1=p1, p2=p2, start=start, paused=paused, goal_sw=goal_sw))


def until(game, cond, limit=3000, **kw):
    for _ in range(limit):
        if cond(game):
            return
        tick(game, **kw)
    raise AssertionError("condition not reached")


def started(rules=RULES, goal_sw=0):
    """A Game whose first Round has just been released."""
    game = Game(rules)
    tick(game, start=True, goal_sw=goal_sw)
    until(game, lambda g: g.phase == PLAY, goal_sw=goal_sw)
    return game


def step(game, p1=(), p2=(), **kw):
    """Give inputs in time for the next launch, then run to that Step's outcome."""
    n, rnd = game.step_count, game.round_index
    tick(game, p1=p1, p2=p2, **kw)
    until(game, lambda g: g.step_count != n or g.round_index != rnd, **kw)


def run_until_phase_leaves(game, phase, **kw):
    until(game, lambda g: g.phase != phase, **kw)


def arrange(game, player, cell, heading):
    """Testbench force between Steps: move a Bike's head code, head and Heading."""
    old = game.step.head[player]
    game.grid.write(*old, EMPTY)
    game.grid.write(*cell, arena_map.HEAD[player])
    heads = list(game.step.head)
    heads[player] = cell
    game.step.head = tuple(heads)
    shown = list(game.step.shown)
    shown[player] = heading
    game.step.shown = tuple(shown)
    game.turns[player].load(heading)


def put_reward_ahead(game, player, slot):
    """Testbench force: move Reward `slot` to the Cell in front of a Bike."""
    cell = next_cell(game.step.head[player], game.turns[player].heading)
    old = game.ctrl.slots[slot]
    if old is not None:
        game.grid.write(*old, EMPTY)
    game.grid.write(*cell, REWARD_SLOT0 + slot)
    game.ctrl.slots[slot] = cell
    return cell


def empty_grid():
    ram = ArenaMap()
    ram.clear()
    return ram


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
                base, digits_ = raw.split("'")[1][0], raw.split("'")[1][1:]
                values[name] = int(digits_, 16 if base == "h" else 10)
            else:
                values[name] = int(raw)
        names = ("BORDER_PX", "TILE_SHIFT", "GRID_W", "GRID_H", "HUD_ROWS", "CX_W", "CY_W",
                 "ADDR_W", "PLAY_CX_MIN", "PLAY_CX_MAX", "PLAY_CY_MIN", "PLAY_CY_MAX",
                 "CELL_EMPTY", "CELL_WALL", "CELL_P1_TRAIL", "CELL_P1_HEAD", "CELL_P2_TRAIL",
                 "CELL_P2_HEAD", "CELL_CRASH", "CELL_RESERVED", "DIR_UP", "DIR_RIGHT",
                 "DIR_DOWN", "DIR_LEFT", "G_IDLE", "G_PLAY", "G_CRASH", "G_READY", "G_MATCH",
                 "BTN_U", "BTN_D", "BTN_L", "BTN_R", "BTN_C", "STEP_TICKS", "LIVES_START",
                 "REWARD_PTS0", "REWARD_PTS1", "REWARD_PTS2", "SURVIVAL_BONUS", "CRASH_TICKS",
                 "SCORE_VIEW_TICKS", "SAL_P1_CX", "SAL_P2_CX", "SAL_CY")
        expected = {n: getattr(params, n) for n in names}
        expected.update({"CELL_REWARD0": REWARD_SLOT0, "CELL_REWARD1": REWARD_SLOT0 + 1,
                         "CELL_REWARD2": REWARD_SLOT0 + 2,
                         "COLOR_TRANSPARENT": 0x000, "COLOR_TINT_KEY": 0x0F0})
        for name, value in expected.items():
            self.assertEqual(values.get(name), value, name)
        self.assertNotIn(params.G_PREP, (values[n] for n in ("G_IDLE", "G_PLAY", "G_CRASH",
                                                             "G_READY", "G_MATCH")))

    def test_points_and_lives_widths_hold_every_legal_value(self):
        self.assertEqual(params.POINTS_MAX, 45)            # 39 + 3 + 3 at goal 40
        self.assertLess(params.POINTS_MAX, 1 << params.POINTS_W)
        self.assertEqual(params.POINTS_W, 6)
        self.assertEqual(params.LIVES_W, 2)


class ArenaMapTests(unittest.TestCase):
    def test_layout_is_the_agreed_working_layout(self):
        g = GEOMETRY
        self.assertEqual((g.width, g.height), (78, 44))
        self.assertEqual((g.x0 * 16, g.x1 * 16 - 1, g.y0 * 16, g.y1 * 16 - 1), (16, 1263, 80, 783))
        self.assertEqual(g.hud_px, 64)
        self.assertEqual(g.start_cells(), ((20, 27), (59, 27)))

    def test_clear_leaves_only_the_playable_cells_empty(self):
        ram = empty_grid()
        self.assertEqual(len(ram.words), 8192)
        self.assertEqual(ram.words.count(EMPTY), 78 * 44)
        self.assertEqual(ram.words.count(WALL), 8192 - 78 * 44)
        for x, y in ((40, 0), (40, 3), (40, 4), (40, 49), (0, 27), (79, 27), (100, 27), (40, 60)):
            self.assertEqual(ram.read(x, y), WALL, (x, y))   # HUD band, Wall ring, padding

    def test_address_is_cy_then_cx(self):
        self.assertEqual(arena_map.address(5, 3), (3 << 7) | 5)
        self.assertEqual(arena_map.address(127, 63), 8191)
        self.assertEqual(arena_map.cell_of(8191), (127, 63))

    def test_coordinates_wrap_unsigned_into_padding(self):
        self.assertEqual(next_cell((0, 10), LEFT), (127, 10))
        self.assertEqual(next_cell((10, 0), UP), (10, 63))


class StepResolveTests(unittest.TestCase):
    """step_resolve is combinational: heads, targets and target codes in, outcome out."""

    def resolve(self, heads, headings, codes):
        targets = tuple(next_cell(h, d) for h, d in zip(heads, headings))
        return step_resolve(heads, targets, codes)

    def test_wall_trail_and_head_codes_crash_only_the_bike_entering_them(self):
        for code in (WALL, TRAIL_P1, HEAD_P1, TRAIL_P2, HEAD_P2, arena_map.CRASH, arena_map.RESERVED):
            out = self.resolve(((20, 20), (60, 20)), (RIGHT, LEFT), (code, EMPTY))
            self.assertEqual(out.crashed, (True, False), code)
            self.assertFalse(out.head_on)

    def test_head_on_same_cell_crashes_both(self):
        out = self.resolve(((40, 20), (41, 19)), (RIGHT, DOWN), (EMPTY, EMPTY))
        self.assertEqual((out.crashed, out.head_on), ((True, True), True))
        self.assertEqual(out.writes, ())

    def test_head_on_swap_crashes_both(self):
        out = self.resolve(((40, 20), (41, 20)), (RIGHT, LEFT), (HEAD_P2, HEAD_P1))
        self.assertEqual((out.crashed, out.head_on), ((True, True), True))

    def test_head_on_into_one_reward_cell_collects_nothing(self):
        out = self.resolve(((40, 20), (42, 20)), (RIGHT, LEFT), (REWARD_SLOT0 + 2,) * 2)
        self.assertEqual((out.crashed, out.collected), ((True, True), (None, None)))

    def test_crashed_bike_stays_and_survivor_writes_trail_then_head(self):
        out = self.resolve(((40, 20), (60, 20)), (RIGHT, LEFT), (WALL, REWARD_SLOT0 + 1))
        self.assertEqual(out.heads, ((40, 20), (59, 20)))
        self.assertEqual(out.collected, (None, 1))
        self.assertEqual(out.writes, ((60, 20, TRAIL_P2), (59, 20, HEAD_P2)))


class TurnUnitTests(unittest.TestCase):
    def batches(self, *events, heading=RIGHT, tie=False):
        """Feed P1 events through input_batch (one tick) into turn_unit; launch."""
        ib, tu = InputBatch(), TurnUnit(heading)
        if tie:
            mask = 0
            for d in events:
                mask |= {UP: 1, DOWN: 2, LEFT: 4, RIGHT: 8}[d]
            ib.button_sample(mask)
        else:
            for d in events:
                ib.button_sample({UP: 1, DOWN: 2, LEFT: 4, RIGHT: 8}[d])
        tu.clock(ib.publish().axes[0], apply=True, launch=True)
        return tu.heading

    def test_reversal_and_same_heading_are_ignored(self):
        self.assertEqual(self.batches(LEFT), RIGHT)
        self.assertEqual(self.batches(RIGHT), RIGHT)

    def test_last_valid_request_wins(self):
        self.assertEqual(self.batches(UP, DOWN), DOWN)

    def test_invalid_requests_do_not_cancel_a_pending_turn(self):
        self.assertEqual(self.batches(UP, LEFT), UP)       # reversal
        self.assertEqual(self.batches(UP, RIGHT), UP)      # same Heading

    def test_tied_board_sample_uses_up_right_down_left(self):
        self.assertEqual(self.batches(UP, DOWN, tie=True), UP)
        self.assertEqual(self.batches(DOWN, LEFT, tie=True), DOWN)       # LEFT is a reversal
        self.assertEqual(self.batches(LEFT, RIGHT, tie=True, heading=UP), RIGHT)
        self.assertEqual(self.batches(UP, RIGHT, tie=True, heading=LEFT), UP)   # RIGHT reverses

    def test_pending_turn_survives_later_batches_until_launch(self):
        tu = TurnUnit(RIGHT)
        tu.clock((UP, None), apply=True, launch=False)
        tu.clock((None, LEFT), apply=True, launch=False)   # reversal of RIGHT: ignored
        tu.clock((None, None), apply=True, launch=True)
        self.assertEqual(tu.heading, UP)
        tu.clock((None, LEFT), apply=True, launch=True)    # now judged against UP
        self.assertEqual(tu.heading, LEFT)

    def test_heading_changes_only_at_launch(self):
        """Review F3: UP is pending, then DOWN arrives before the launch.
        DOWN replaces UP; it is not a reversal of a Heading the Bike never had."""
        tu = TurnUnit(RIGHT)
        tu.clock((UP, None), apply=True, launch=False)
        self.assertEqual((tu.heading, tu.pending), (RIGHT, UP))
        tu.clock((DOWN, None), apply=True, launch=True)
        self.assertEqual(tu.heading, DOWN)


class InputBatchTests(unittest.TestCase):
    def test_uart_decoder(self):
        self.assertEqual(uart_decode(ord("w")), ("turn", UP))
        self.assertEqual(uart_decode(ord("D")), ("turn", RIGHT))
        self.assertEqual(uart_decode(0x20), ("start", None))
        self.assertEqual(uart_decode(0x0D), ("start", None))
        self.assertIsNone(uart_decode(0x0A))
        self.assertIsNone(uart_decode(ord("x")))

    def test_each_event_lands_in_exactly_one_batch(self):
        ib = InputBatch()
        ib.uart_byte(ord("a"))
        ib.button_sample(1 << params.BTN_C)
        b = ib.publish()
        self.assertEqual((b.axes, b.start), (((None, None), (None, LEFT)), True))
        b = ib.publish()
        self.assertEqual((b.axes, b.start), (((None, None), (None, None)), False))


class MailboxTests(unittest.TestCase):
    def test_one_outstanding_command(self):
        mb = Mailbox()
        mb.issue(OP_READ2, targets=((1, 5), (2, 5)))
        with self.assertRaises(RuntimeError):
            mb.issue(OP_COMMIT)

    def test_step_latency_from_launch_to_outcome(self):
        game = started()
        launches = []
        for _ in range(3 * params.STEP_TICKS):
            before = game.step.state
            tick(game)
            if before == S_IDLE and game.step.state == S_READ:
                launches.append(game.ticks)
            if before == S_READ and game.step.state == S_COMMIT:
                self.assertEqual(game.ticks - launches[-1], params.STEP_LATENCY)
        self.assertEqual(launches[1] - launches[0], params.STEP_TICKS)

    def test_minimum_step_period(self):
        RuleParams(step_ticks=params.MIN_STEP_TICKS)
        with self.assertRaises(ValueError):
            RuleParams(step_ticks=params.MIN_STEP_TICKS - 1)
        game = started(RuleParams(step_ticks=params.MIN_STEP_TICKS, crash_ticks=8, fixed_seed=True))
        until(game, lambda g: g.phase == CRASH)            # no cadence overrun on the way
        self.assertEqual(game.step_count, 20)


class ArenaCtrlTests(unittest.TestCase):
    def test_prepare_writes_heads_and_three_rewards_on_empty_cells(self):
        ram = ArenaMap()
        ctrl = ArenaCtrl(ram, RULES)
        mb = Mailbox()
        mb.issue(OP_PREPARE, new_match=True, heads=((20, 27), (59, 27)))
        rsp = ctrl.execute(mb.take())
        self.assertEqual((ram.read(20, 27), ram.read(59, 27)), (HEAD_P1, HEAD_P2))
        for slot, cell in enumerate(rsp.slots):
            self.assertTrue(GEOMETRY.in_interior(*cell))
            self.assertEqual(ram.read(*cell), REWARD_SLOT0 + slot)
        self.assertLess(rsp.cycles, params.SERVICE_WINDOW)

    def test_last_empty_cell_is_found_and_a_full_arena_gives_none(self):
        ram = empty_grid()
        g = GEOMETRY
        last = (g.x1 - 1, g.y1 - 1)
        for y in range(g.y0, g.y1):
            for x in range(g.x0, g.x1):
                if (x, y) != last:
                    ram.write(x, y, TRAIL_P1)
        found = find_empty_cell(ram, Lfsr(1))
        self.assertEqual(found.cell, last)
        self.assertEqual(found.draws, params.RANDOM_DRAWS)
        ram.write(*last, TRAIL_P2)
        self.assertIsNone(find_empty_cell(ram, Lfsr(1)).cell)
        self.assertLess(find_empty_cell(ram, Lfsr(1)).cycles, params.SERVICE_WINDOW)


class RoundTests(unittest.TestCase):
    def test_power_up_waits_for_start_with_walls_only(self):
        game = Game(RULES)
        self.assertEqual(game.phase, IDLE)
        self.assertIsNone(game.snapshot()["heads"])
        self.assertEqual(game.grid.words.count(EMPTY), 78 * 44)
        for _ in range(5):
            tick(game, p1=[UP])
        self.assertEqual(game.phase, IDLE)

    def test_one_start_prepares_everything_then_releases_the_round(self):
        game = Game(RULES)
        tick(game, start=True)
        tick(game)
        tick(game)                                          # edge 3: Start reaches the game
        self.assertEqual(game.phase, PREP)
        until(game, lambda g: g.phase != PREP)
        self.assertEqual(game.phase, PLAY)
        self.assertEqual(game.grid.read(20, 27), HEAD_P1)
        self.assertEqual(game.grid.read(59, 27), HEAD_P2)
        self.assertTrue(all(c is not None for c in game.reward_cells))
        self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)
        self.assertEqual((game.points, game.lives, game.goal), ([0, 0], [3, 3], 10))

    def test_first_step_comes_step_ticks_after_release(self):
        game = started()
        for _ in range(params.STEP_TICKS + params.STEP_LATENCY - 1):
            tick(game)
        self.assertEqual(game.step_count, 0)
        tick(game)
        self.assertEqual(game.step.head[0], (21, 27))

    def test_turn_given_two_ticks_before_launch_counts(self):
        # started() returns after the release edge r; the first launch is r + 6
        game = started()
        for _ in range(params.STEP_TICKS - 3):
            tick(game)
        tick(game, p1=[UP])                                 # edge r + 4: reaches the launch edge
        until(game, lambda g: g.step_count == 1)
        self.assertEqual(game.step.head[0], (20, 26))
        game = started()
        for _ in range(params.STEP_TICKS - 2):
            tick(game)
        tick(game, p1=[UP])                                 # one tick too late: next Step
        until(game, lambda g: g.step_count == 1)
        self.assertEqual(game.step.head[0], (21, 27))
        until(game, lambda g: g.step_count == 2)
        self.assertEqual(game.step.head[0], (21, 26))

    def test_turns_are_ignored_outside_play(self):
        game = started()
        step(game, p1=[UP])                                 # P1 heads for the top Wall
        run_until_phase_leaves(game, PLAY)
        self.assertEqual(game.phase, CRASH)
        tick(game, p1=[DOWN], p2=[UP])                      # during the Crash display
        until(game, lambda g: g.phase == READY)
        tick(game, p1=[UP], p2=[UP])                        # during the ready wait
        tick(game)
        tick(game)
        self.assertEqual([u.pending for u in game.turns], [RIGHT, LEFT])

    def test_each_wall_crashes(self):
        for heading, cell in ((UP, (40, 5)), (DOWN, (40, 48)), (LEFT, (1, 20)), (RIGHT, (78, 20))):
            game = started()
            arrange(game, 0, cell, heading)
            step(game)
            self.assertEqual(game.crashed, (True, False), heading)
            self.assertEqual(game.step.head[0], cell)

    def test_wall_crash_costs_a_life_and_pays_the_survival_bonus(self):
        game = started()
        step(game, p1=[UP])
        run_until_phase_leaves(game, PLAY)
        self.assertEqual(game.phase, CRASH)
        self.assertEqual(game.lives, [2, 3])
        self.assertEqual(game.points, [0, 3])

    def test_own_trail_and_other_trail_crash(self):
        game = started()
        for turn in (UP, LEFT, DOWN, RIGHT):                # loops back onto its Trail
            step(game, p1=[turn])
        self.assertEqual(game.crashed, (True, False))
        game = started()
        arrange(game, 1, (20, 25), DOWN)                    # P2 drives into P1's Trail
        step(game)
        step(game)
        self.assertEqual(game.crashed, (False, True))

    def test_swap_head_on_from_the_default_starts_costs_both_a_life_and_no_bonus(self):
        game = started()
        run_until_phase_leaves(game, PLAY)
        self.assertTrue(game.head_on)
        self.assertEqual(game.step_count, 20)
        self.assertEqual(game.lives, [2, 2])
        self.assertEqual(game.points, [0, 0])
        self.assertEqual(game.step.head, ((39, 27), (40, 27)))   # last valid head Cells

    def test_survivor_moves_and_collects_in_the_crash_step(self):
        game = started()
        arrange(game, 0, (78, 27), RIGHT)                   # P1 faces the right Wall
        cell = put_reward_ahead(game, 1, 2)
        step(game)
        self.assertEqual(game.crashed, (True, False))
        self.assertEqual(game.step.head[1], cell)
        self.assertEqual(game.grid.read(*cell), HEAD_P2)
        self.assertEqual(game.points, [0, 3 + 3])

    def test_crash_display_ignores_start_then_next_round_needs_a_fresh_start(self):
        game = started()
        run_until_phase_leaves(game, PLAY)
        run_until_phase_leaves(game, CRASH, start=True)     # Start pressed every tick
        self.assertEqual(game.phase, PREP)
        run_until_phase_leaves(game, PREP)
        self.assertEqual(game.phase, READY)
        self.assertEqual(game.step_count, 0)
        self.assertEqual(sum(1 for w in game.grid.words if w in (TRAIL_P1, TRAIL_P2)), 0)
        self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)
        for _ in range(5):
            tick(game)
        self.assertEqual(game.phase, READY)
        tick(game, start=True)
        tick(game)
        tick(game)
        self.assertEqual(game.phase, PLAY)

    def test_start_late_in_the_final_crash_display_is_not_carried_over(self):
        """Review finding: a Start pressed on the display's last tick reached
        the game after it had entered Match-over and began a new Match."""
        game = started()
        game.score.lives = [1, 1]
        run_until_phase_leaves(game, PLAY)
        until(game, lambda g: g.phase_ticks == RULES.crash_ticks - 1)
        tick(game, start=True)                              # last tick of the display
        for _ in range(10):
            tick(game)
        self.assertEqual(game.phase, MATCH_OVER)
        tick(game, start=True)                              # a fresh press after it
        until(game, lambda g: g.phase == PLAY)

    def test_steering_in_the_ready_wait_does_not_reach_the_round(self):
        """Review finding: UP pressed in READY, just after Start, arrived after
        the release and turned P1 on the first Step."""
        game = started()
        run_until_phase_leaves(game, PLAY)
        until(game, lambda g: g.phase == READY)
        tick(game, start=True)
        tick(game, p1=[UP])                                 # still READY when pressed
        until(game, lambda g: g.step_count == 1)
        self.assertEqual(game.step.head[0], (21, 27))

    def test_speed_change_takes_effect_at_the_next_launch(self):
        """Review finding: shortening the period after step_cnt had passed the
        new threshold stopped all Steps."""
        game = started()
        for _ in range(5):
            tick(game)
        game.rules = RuleParams(step_ticks=5, crash_ticks=8, fixed_seed=True)
        until(game, lambda g: g.step_count == 2, limit=40)
        launches = []
        for _ in range(20):
            before = game.step.state
            tick(game)
            if before != S_READ and game.step.state == S_READ:
                launches.append(game.ticks)
        self.assertEqual([b - a for a, b in zip(launches, launches[1:])], [5] * (len(launches) - 1))

    def test_seed_mix_is_the_tick_count_before_the_start_edge(self):
        """Review finding: PREPARE carried the counter already incremented at
        that edge; a capture register takes the value from before it."""
        game = Game(RuleParams(crash_ticks=8))
        tick(game, start=True)                              # accepted at edge 3
        tick(game)
        tick(game)
        self.assertEqual(game.mbox.cmd.op, OP_PREPARE)
        self.assertEqual(game.mbox.cmd.seed_mix, 2)

    def test_uart_start_and_steering_work_like_the_board(self):
        game = Game(RULES)
        game.tick(BoardInputs(uart=b"\r"))
        until(game, lambda g: g.phase == PLAY)
        game.tick(BoardInputs(uart=b"S"))                   # P2 turns DOWN
        until(game, lambda g: g.step_count == 1)
        self.assertEqual(game.step.head[1], (59, 28))


class RewardTests(unittest.TestCase):
    def test_collecting_pays_its_value_and_respawns_on_an_empty_cell(self):
        for slot, value in enumerate((1, 1, 3)):
            game = started()
            cell = put_reward_ahead(game, 0, slot)
            step(game)
            self.assertEqual(game.points[0], value)
            self.assertEqual(game.grid.read(*cell), HEAD_P1)
            new = game.reward_cells[slot]
            self.assertNotEqual(new, cell)
            self.assertTrue(GEOMETRY.in_interior(*new))
            self.assertEqual(game.grid.read(*new), REWARD_SLOT0 + slot)
            self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)), 3)

    def test_two_collections_in_one_step_are_replaced_in_slot_order(self):
        game = started()
        arrange(game, 1, (40, 30), LEFT)
        put_reward_ahead(game, 0, 2)
        put_reward_ahead(game, 1, 0)
        before = len(game.ctrl.placements)
        step(game)
        self.assertEqual([s for s, _ in game.ctrl.placements[before:]], [0, 2])

    def test_full_arena_leaves_a_collected_slot_absent(self):
        game = started()
        cell = put_reward_ahead(game, 0, 1)
        for y in range(GEOMETRY.y0, GEOMETRY.y1):
            for x in range(GEOMETRY.x0, GEOMETRY.x1):
                if game.grid.read(x, y) == EMPTY:
                    game.grid.write(x, y, TRAIL_P2)
        step(game)
        self.assertEqual(game.step.head[0], cell)
        self.assertIsNone(game.reward_cells[1])
        self.assertFalse(game.ctrl.overrun)

    def test_fixed_seed_repeats_and_start_timing_changes_the_sequence(self):
        def rewards(rules, idle_ticks):
            game = Game(rules)
            for _ in range(idle_ticks):
                tick(game)
            tick(game, start=True)
            until(game, lambda g: g.phase == PLAY)
            return list(game.reward_cells)
        self.assertEqual(rewards(RULES, 3), rewards(RULES, 50))
        normal = RuleParams(crash_ticks=8)
        self.assertNotEqual(rewards(normal, 3), rewards(normal, 50))


class MatchTests(unittest.TestCase):
    def test_goal_without_a_crash_ends_the_match_at_once(self):
        game = started(goal_sw=1)                           # goal 20
        game.score.points = [19, 0]
        put_reward_ahead(game, 0, 2)
        step(game, goal_sw=1)
        self.assertEqual(game.points[0], 22)                # full total, no clamp
        self.assertEqual((game.phase, game.result), (MATCH_OVER, 0))

    def test_match_ending_crash_shows_the_display_and_keeps_the_full_total(self):
        game = started(goal_sw=3)                           # goal 40
        game.score.points = [39, 0]
        put_reward_ahead(game, 0, 2)
        arrange(game, 1, (78, 30), RIGHT)                   # P2 drives into the right Wall
        step(game, goal_sw=3)
        self.assertEqual(game.points[0], 45)
        self.assertEqual((game.phase, game.result), (CRASH, 0))
        rounds, heads = game.round_index, game.step.head
        run_until_phase_leaves(game, CRASH, start=True, goal_sw=3)
        self.assertEqual(game.phase, MATCH_OVER)
        self.assertEqual(game.round_index, rounds)          # no new Round prepared
        self.assertEqual(game.step.head, heads)

    def test_both_reach_the_goal_in_one_step(self):
        for slots, points, result in (((2, 0), [12, 10], 0), ((0, 1), [10, 10], DRAW)):
            game = started()
            arrange(game, 1, (40, 30), LEFT)
            game.score.points = [9, 9]
            put_reward_ahead(game, 0, slots[0])
            put_reward_ahead(game, 1, slots[1])
            step(game)
            self.assertEqual(game.points, points)
            self.assertEqual((game.phase, game.result), (MATCH_OVER, result))

    def test_both_lose_their_final_life_in_one_step(self):
        for points, result in (([5, 3], 0), ([3, 5], 1), ([4, 4], DRAW)):
            game = started()
            game.score.lives, game.score.points = [1, 1], list(points)
            run_until_phase_leaves(game, PLAY)
            self.assertEqual(game.result, result)
            run_until_phase_leaves(game, CRASH)
            self.assertEqual(game.phase, MATCH_OVER)
            self.assertEqual(game.lives, [0, 0])

    def test_losing_the_final_life_loses_even_with_more_points(self):
        game = started()
        game.score.lives, game.score.points = [1, 3], [9, 0]
        step(game, p1=[UP])
        run_until_phase_leaves(game, PLAY)
        self.assertEqual((game.points, game.result), ([9, 3], 1))

    def test_goal_is_captured_only_when_a_new_match_starts(self):
        game = started(goal_sw=1)
        self.assertEqual(game.goal, 20)
        for _ in range(4):
            tick(game, goal_sw=3)
        self.assertEqual(game.goal, 20)
        game.score.points = [19, 0]
        put_reward_ahead(game, 0, 0)
        step(game, goal_sw=3)
        self.assertEqual((game.phase, game.result), (MATCH_OVER, 0))
        tick(game, goal_sw=3)
        tick(game, start=True, goal_sw=3)
        until(game, lambda g: g.phase == PLAY, goal_sw=3)
        self.assertEqual(game.goal, 40)
        self.assertEqual((game.points, game.lives), ([0, 0], [3, 3]))


class PauseAndResetTests(unittest.TestCase):
    def test_pause_freezes_steps_and_timers_and_ignores_start(self):
        game = started()
        for _ in range(30):
            tick(game, paused=True)
        self.assertEqual(game.step_count, 0)
        game = started()
        run_until_phase_leaves(game, PLAY)
        ticks = game.phase_ticks
        for _ in range(30):
            tick(game, paused=True)
        self.assertEqual(game.phase, CRASH)
        self.assertLessEqual(game.phase_ticks, ticks + params.SYNC_STAGES)
        run_until_phase_leaves(game, CRASH)
        run_until_phase_leaves(game, PREP)
        tick(game, start=True, paused=True)
        for _ in range(5):
            tick(game, paused=True)
        self.assertEqual(game.phase, READY)

    def test_pause_during_an_open_step_holds_its_outcome_until_resume(self):
        game = started()                                    # release edge r, launch at r + 6
        for _ in range(params.STEP_TICKS - 2):
            tick(game)
        for _ in range(20):                                 # SW0 reaches the game at r + 7
            tick(game, paused=True)
        self.assertEqual(game.step_count, 0)                # codes arrived, not resolved
        self.assertEqual(game.step.state, S_READ)
        until(game, lambda g: g.step_count == 1)
        self.assertEqual(game.step.head, ((21, 27), (58, 27)))

    def test_reset_returns_to_waiting_for_start(self):
        game = started(goal_sw=2)
        step(game, p1=[UP])
        tick(game, start=True)                              # in flight when reset comes
        game.reset()
        for _ in range(5):
            tick(game)
        self.assertEqual(game.phase, IDLE)
        self.assertIsNone(game.snapshot()["heads"])
        self.assertEqual((game.points, game.lives), ([0, 0], [3, 3]))
        self.assertEqual(game.grid.words.count(EMPTY), 78 * 44)
        self.assertEqual(game.reward_cells, [None, None, None])


class ScoreboardTests(unittest.TestCase):
    def test_banks_and_views(self):
        pt = PageTimer(3)
        self.assertEqual(digits(pt.view, [7, 12], [3, 1]), "P212P107")   # P2 left, P1 right
        for _ in range(3):
            pt.clock()
        self.assertEqual(digits(pt.view, [7, 12], [3, 1]), "L201L103")
        for _ in range(3):
            pt.clock()
        self.assertEqual(pt.view, 0)

    def test_glyph_decoder_has_p_and_l_and_is_active_low(self):
        self.assertTrue({"P", "L"} <= set(GLYPHS))
        self.assertEqual(segments("8"), 0)
        self.assertEqual(segments("1"), 0b1111001)

    def test_view_keeps_cycling_in_pause_and_a_new_match_starts_on_points(self):
        game = Game(RuleParams(score_view_ticks=10, crash_ticks=8, fixed_seed=True))
        for _ in range(10):
            tick(game, paused=True)
        self.assertTrue(game.snapshot()["scoreboard"].startswith("L2"))
        for _ in range(3):                                  # SW0 down reaches the game
            tick(game)
        tick(game, start=True)                              # tick 14, accepted at edge 16
        tick(game)
        tick(game)
        self.assertTrue(game.snapshot()["scoreboard"].startswith("P2"))


class LongGameTests(unittest.TestCase):
    def test_random_play_keeps_the_arena_and_scores_consistent(self):
        rng = random.Random(1)
        game = Game(RULES)
        for _ in range(12000):
            p1 = [rng.randrange(4)] if rng.random() < 0.1 else []
            p2 = [rng.randrange(4)] if rng.random() < 0.1 else []
            tick(game, p1, p2, start=rng.random() < 0.05, goal_sw=rng.randrange(4))
            if not game.show_bikes:
                continue
            for slot, cell in enumerate(game.reward_cells):
                if cell is not None:
                    self.assertTrue(GEOMETRY.in_interior(*cell))
                    self.assertEqual(game.grid.read(*cell), REWARD_SLOT0 + slot)
            if game.phase != PREP:
                for i, head in enumerate(game.step.head):
                    self.assertEqual(game.grid.read(*head), arena_map.HEAD[i])
            self.assertLessEqual(max(game.points), params.POINTS_MAX)
            self.assertTrue(all(0 <= n <= 3 for n in game.lives))
            if game.phase == PLAY:
                self.assertEqual(sum(1 for w in game.grid.words if is_reward(w)),
                                 sum(c is not None for c in game.reward_cells))
        self.assertFalse(game.ctrl.overrun)
        self.assertGreater(game.round_index, 0)


if __name__ == "__main__":
    unittest.main()
