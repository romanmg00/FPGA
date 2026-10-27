"""Game top: Match/Round FSM (hardware block G3) wiring the other blocks.

`tick()` is one tick of the ~60 Hz divided game clock (ADR 0002), not a
video frame. A Step runs every `step_ticks` ticks during Play. Inputs are
the requests that reached the game domain for that tick; the model does not
yet represent the transfer latency between the fast input/Arena service and
the game clock, which the X1 interface still has to define.

Phases follow the contract's proposed game_pkg states:
IDLE = G_IDLE, PLAY = G_PLAY, CRASH = G_CRASH, READY = G_READY, MATCH_OVER = G_MATCH.
"""

from dataclasses import dataclass, field

from .arena import HEAD, ArenaGrid
from .lfsr import Lfsr
from .params import GEOMETRY, RuleParams, goal_from_switches
from .rewards import place_reward
from .scoreboard import Scoreboard
from .scoring import match_result
from .step import Bike, run_step
from .steering import LEFT, RIGHT, latch_requests

IDLE = "IDLE"              # power-up or CPU_RESETN: wait for Start
PLAY = "PLAY"              # Steps happen
CRASH = "CRASH"            # ~2 s freeze with the crashed Bike(s) blinking
READY = "READY"            # next Round prepared, wait for a fresh Start
MATCH_OVER = "MATCH_OVER"  # final Points and Lives kept until Start


@dataclass(frozen=True)
class TickInputs:
    """Everything the game sees in one game-clock tick.

    turns[i] lists Player i's Turn requests in arrival order. An item is a
    Heading, or a set of Headings tied in one board-button sample.
    `paused` is SW0 and `goal_sw` is {SW15, SW14}.
    """

    turns: tuple = field(default_factory=lambda: ((), ()))
    start: bool = False
    paused: bool = False
    goal_sw: int = 0


class Game:
    def __init__(self, rules: RuleParams = RuleParams()):
        self.geom = GEOMETRY
        self.rules = rules
        self.grid = ArenaGrid()
        self.scoreboard = Scoreboard(rules.score_view_ticks)
        self.free_ticks = 0
        self.reset()

    # --- phases -------------------------------------------------------
    def reset(self) -> None:
        """CPU_RESETN: clear the game and wait for Start."""
        self.lfsr = Lfsr(self.rules.seed)
        self.grid.clear()
        self.bikes = None
        self.reward_cells = [None, None, None]
        self.goal = goal_from_switches(0)
        self.points = [0, 0]
        self.lives = [self.rules.lives] * 2
        self.round_index = 0
        self.result = None
        self.crashed = (False, False)
        self.head_on = False
        self.step_count = 0
        self.step_timer = 0
        self.scoreboard.restart()
        self._enter(IDLE)

    def _new_match(self, goal_sw: int) -> None:
        """Start from IDLE or MATCH_OVER: capture the goal, then prepare and release."""
        self.goal = goal_from_switches(goal_sw)
        self.points = [0, 0]
        self.lives = [self.rules.lives] * 2
        self.round_index = 0
        self.result = None
        if self.rules.fixed_seed:
            self.lfsr = Lfsr(self.rules.seed)
        else:
            self.lfsr.mix(self.free_ticks)
        self.scoreboard.restart()
        self._prepare_round()
        self._enter(PLAY)

    def _prepare_round(self) -> None:
        """Walls, both Bikes and all three Rewards, before the Round is released."""
        self.grid.clear()
        (c1, c2) = self.geom.start_cells()
        self.bikes = [Bike(c1, RIGHT, RIGHT), Bike(c2, LEFT, LEFT)]
        for i, b in enumerate(self.bikes):
            self.grid.write(*b.head, HEAD[i])
        self.reward_cells = [None, None, None]
        for slot in range(3):
            place_reward(slot, self.reward_cells, self.grid, self.lfsr)
        self.crashed = (False, False)
        self.head_on = False
        self.step_count = 0
        self.step_timer = 0
        self.round_index += 1

    def _enter(self, phase: str) -> None:
        self.phase = phase
        self.phase_ticks = 0

    # --- per-tick update ----------------------------------------------
    def tick(self, inputs: TickInputs) -> None:
        self.free_ticks += 1
        self.scoreboard.tick()                 # the Scoreboard keeps cycling in Pause
        if inputs.paused:                      # game state, timers and steering stop
            return
        self.phase_ticks += 1

        if self.phase in (IDLE, MATCH_OVER):
            if inputs.start:
                self._new_match(inputs.goal_sw)
        elif self.phase == READY:
            if inputs.start:
                self._enter(PLAY)
        elif self.phase == PLAY:
            for b, requests in zip(self.bikes, inputs.turns):
                b.pending = latch_requests(b.pending, b.heading, requests)
            self.step_timer += 1
            if self.step_timer >= self.rules.step_ticks:
                self.step_timer = 0
                self._step()
        elif self.phase == CRASH:              # Start and Turns are ignored
            if self.phase_ticks >= self.rules.crash_ticks:
                self._after_crash()

    def _step(self) -> None:
        """Resolve moves and Crashes, award Rewards and the Survival Bonus,
        then evaluate victory, all in one Step."""
        result = run_step(self.bikes, self.grid)
        self.step_count += 1
        for i, slot in enumerate(result.collected):
            if slot is not None:
                self.points[i] += self.rules.reward_values[slot]
        # Replace collected Rewards in slot order. In a full Arena the slot
        # stays absent until the next Round (see rewards.py).
        for slot in sorted(s for s in result.collected if s is not None):
            place_reward(slot, self.reward_cells, self.grid, self.lfsr)
        if any(result.crashed):
            self.crashed = result.crashed
            self.head_on = result.head_on
            for i in range(2):
                if result.crashed[i]:
                    self.lives[i] -= 1
                elif result.crashed[1 - i]:
                    self.points[i] += self.rules.survival_bonus
        self.result = match_result(self.points, self.lives, self.goal)
        if any(result.crashed):
            self._enter(CRASH)                 # a Match-ending Crash still shows the display
        elif self.result is not None:
            self._enter(MATCH_OVER)            # goal reached without a Crash

    def _after_crash(self) -> None:
        if self.result is not None:
            self._enter(MATCH_OVER)
            return
        self._prepare_round()
        self._enter(READY)

    # --- read-only view for renderers and Step logs -------------------
    def snapshot(self) -> dict:
        return {
            "phase": self.phase,
            "phase_ticks": self.phase_ticks,
            "round": self.round_index,
            "step": self.step_count,
            "heads": [b.head for b in self.bikes] if self.bikes else None,
            "headings": [b.heading for b in self.bikes] if self.bikes else None,
            "crashed": self.crashed,
            "head_on": self.head_on,
            "goal": self.goal,
            "points": list(self.points),
            "lives": list(self.lives),
            "rewards": list(self.reward_cells),
            "reward_values": self.rules.reward_values,
            "result": self.result,
            "scoreboard": self.scoreboard.digits(self.points, self.lives),
        }
