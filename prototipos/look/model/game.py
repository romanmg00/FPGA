"""Game top: Round/Match FSM (hardware block G3) wiring the other blocks.

`tick()` is called once per frame, the model's `frame_tick` (ADR 0001).
A Step runs every `frames_per_step` ticks while a Round is running.
"""

from dataclasses import dataclass, field

from .arena import TRAIL_P1, TRAIL_P2, ArenaGrid
from .lfsr import Lfsr
from .params import ArenaGeometry, RuleParams
from .rewards import place_reward
from .scoring import add_points
from .step import Bike, run_step
from .steering import LEFT, RIGHT, latch_turn

READY = "READY"            # Round set up, waiting for Start
RUNNING = "RUNNING"        # Steps happen
CRASH = "CRASH"            # freeze with the crashed Bike(s) blinking
MATCH_OVER = "MATCH_OVER"  # final Scoreboard shown until Start


@dataclass
class FrameInputs:
    """Everything the game sees in one frame.

    turns[i] lists Player i's Turn requests (Headings) in the order they
    arrived since the previous frame. `paused` is the reset/pause switch.
    """

    turns: tuple = field(default_factory=lambda: ((), ()))
    start: bool = False
    paused: bool = False


class Game:
    def __init__(self, geom: ArenaGeometry, rules: RuleParams = RuleParams()):
        self.geom = geom
        self.rules = rules
        self.grid = ArenaGrid(geom)
        self.power_up()

    # --- phases -------------------------------------------------------
    def power_up(self) -> None:
        """CPU_RESETN: back to the power-up state."""
        self.lfsr = Lfsr(self.rules.lfsr_seed)
        self.new_match()

    def new_match(self) -> None:
        self.lives = [self.rules.lives] * 2
        self.points = [0, 0]
        self.round_index = 0
        self.winner = None
        self.new_round()

    def new_round(self) -> None:
        self.grid.clear()
        (c1, c2) = self.geom.start_cells()
        self.bikes = [Bike(c1, RIGHT, RIGHT), Bike(c2, LEFT, LEFT)]
        self.grid.write(*c1, TRAIL_P1)
        self.grid.write(*c2, TRAIL_P2)
        self.reward_cells = [None, None, None]
        for slot in range(3):
            place_reward(slot, self.reward_cells, self.grid, self.lfsr)
        self.crashed = (False, False)
        self.head_on = False
        self.step_count = 0
        self.frame_count = 0
        self.phase_frames = 0
        self.round_index += 1
        self._enter(READY)

    def _enter(self, phase: str) -> None:
        self.phase = phase
        self.phase_frames = 0

    # --- per-frame update ---------------------------------------------
    def tick(self, inputs: FrameInputs) -> None:
        if inputs.paused:
            return
        self.phase_frames += 1

        if self.phase == READY:
            if inputs.start:
                self.frame_count = 0
                self._enter(RUNNING)
        elif self.phase == RUNNING:
            for b, requests in zip(self.bikes, inputs.turns):
                for r in requests:
                    b.pending = latch_turn(b.pending, b.heading, r)
            self.frame_count += 1
            if self.frame_count >= self.rules.frames_per_step:
                self.frame_count = 0
                self._step()
        elif self.phase == CRASH:
            if self.phase_frames >= self.rules.crash_freeze_frames:
                self._after_crash()
        elif self.phase == MATCH_OVER:
            if inputs.start:
                self.new_match()
                self.frame_count = 0
                self._enter(RUNNING)

    def _step(self) -> None:
        result = run_step(self.bikes, self.grid)
        self.step_count += 1
        if any(result.crashed):
            self.crashed = result.crashed
            self.head_on = result.head_on
            for i in range(2):
                if result.crashed[i]:
                    self.lives[i] -= 1
                elif result.crashed[1 - i]:
                    self.points[i] = add_points(
                        self.points[i], self.rules.survival_bonus, self.rules.points_cap)
            self._enter(CRASH)
            return
        for i, slot in enumerate(result.collected):
            if slot is not None:
                self.points[i] = add_points(
                    self.points[i], self.rules.reward_values[slot], self.rules.points_cap)
        for slot in result.collected:          # respawn P1's first, then P2's
            if slot is not None:
                place_reward(slot, self.reward_cells, self.grid, self.lfsr)

    def _after_crash(self) -> None:
        if min(self.lives) <= 0:
            p1, p2 = self.points
            self.winner = 0 if p1 > p2 else 1 if p2 > p1 else None   # None = Draw
            self._enter(MATCH_OVER)
            return
        self.new_round()
        if not self.rules.next_round_needs_start:
            self._enter(RUNNING)

    # --- read-only view for renderers and Step logs -------------------
    def snapshot(self) -> dict:
        return {
            "phase": self.phase,
            "phase_frames": self.phase_frames,
            "round": self.round_index,
            "step": self.step_count,
            "heads": [b.head for b in self.bikes],
            "headings": [b.heading for b in self.bikes],
            "crashed": self.crashed,
            "head_on": self.head_on,
            "points": list(self.points),
            "lives": list(self.lives),
            "rewards": list(self.reward_cells),
            "reward_values": self.rules.reward_values,
            "winner": self.winner,
        }
