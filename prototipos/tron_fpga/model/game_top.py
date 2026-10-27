"""game_top: the two clock domains of the Tron core, wired as the HDL will be.

`Game.tick(inputs)` is one tick of the ~60 Hz divided game clock (ADR 0002),
not a video frame. A tick has three parts, in this order:

1. Fast domain, before the edge: the inputs that arrived during the last
   tick (button samples, UART bytes) enter input_batch.
2. Game-clock edge: every game-domain register updates from values that
   were stable before the edge: the captured response and input batch, and
   the switches after their 2-FF synchronizer. The units are turn_unit and
   step_unit (Roman's G1/G2), match_ctrl and score_unit (Alan's G3/G5), and
   the Scoreboard page timer. The edge also loads the capture registers.
3. Fast domain, after the edge (tick_seen): arena_ctrl runs a new command
   and publishes its response, input_batch publishes this tick's batch, and
   the render snapshot and Scoreboard values are latched.

So an input given with tick t reaches the game logic at edge t + 2, as does
a switch change. A Step launched at edge k resolves at k + 2 and its COMMIT
is seen done at k + 4.

match_ctrl phases (game_pkg G_*): G_IDLE waits for Start after power-up or
CPU_RESETN. Start captures the goal, resets Points and Lives and issues
PREPARE (G_PREP); when PREPARE is done the Round is released (G_PLAY). A
Crash freezes play for the Crash display (G_CRASH). Then the next Round is
prepared (G_PREP) and waits for a fresh Start (G_READY), or the Match ends
(G_MATCH). Pause (SW0) holds every phase and game timer; the Scoreboard
page timer keeps running.
"""

from dataclasses import dataclass

from .arena_ctrl import ArenaCtrl
from .arena_map import ArenaMap
from .input_batch import BTN_OF, BTN_START, EMPTY_BATCH, UART_KEY, InputBatch
from .mailbox import OP_COMMIT, OP_PREPARE, OP_READ2, Mailbox
from .params import (G_CRASH, G_IDLE, G_MATCH, G_PLAY, G_PREP, G_READY, GEOMETRY, PHASE_NAMES,
                     SW_GOAL_LSB, SW_PAUSE, SYNC_STAGES, RuleParams, goal_from_switches)
from .score_unit import ScoreUnit
from .seg7 import PageTimer, digits
from .step_unit import S_COMMIT, StepUnit
from .steplog import format_line
from .turn_unit import TurnUnit

IDLE, PLAY, CRASH, READY, MATCH_OVER, PREP = G_IDLE, G_PLAY, G_CRASH, G_READY, G_MATCH, G_PREP
START_PHASES = (G_IDLE, G_READY, G_MATCH)
TICK_MASK = (1 << 32) - 1


@dataclass(frozen=True)
class BoardInputs:
    """What reached the board during one game-clock tick.

    `btn` lists debounced press samples in order, each a btn[4:0] mask
    (BTN_U, BTN_D, BTN_L, BTN_R, BTN_C). `uart` holds the bytes the browser
    controller sent, in order. `sw` is the level of sw[15:0].
    """

    btn: tuple = ()
    uart: bytes = b""
    sw: int = 0

    @staticmethod
    def keys(p1=(), p2=(), start=False, paused=False, goal_sw=0) -> "BoardInputs":
        """Shorthand: P1 Headings (a set is one tied sample), P2 Headings, BTNC Start."""
        btn = []
        for r in p1:
            group = r if isinstance(r, (set, frozenset)) else (r,)
            mask = 0
            for d in group:
                mask |= BTN_OF[d]
            btn.append(mask)
        if start:
            btn.append(BTN_START)
        uart = b"".join(UART_KEY[d] for d in p2)
        return BoardInputs(tuple(btn), uart, (goal_sw & 3) << SW_GOAL_LSB | int(paused) << SW_PAUSE)


class Game:
    def __init__(self, rules: RuleParams = RuleParams(), steplog=None):
        """`steplog`, if given, is called with each Step-log line (see steplog.py)."""
        self.geom = GEOMETRY
        self.rules = rules
        self.steplog = steplog
        self.grid = ArenaMap()                       # arena_map
        self.reset()

    # --- CPU_RESETN ---------------------------------------------------------
    def reset(self) -> None:
        """Clear both domains and wait for Start. The model's reset is the
        stretched reset the HDL needs: nothing in flight survives it."""
        r = self.rules
        # fast domain
        self.ctrl = ArenaCtrl(self.grid, r)        # clears the Arena: Walls only
        self.inputs = InputBatch()
        self.mbox = Mailbox()
        self.batch_bus = EMPTY_BATCH
        # game domain
        self.sw_sync = [0] * SYNC_STAGES
        self.batch_cap = EMPTY_BATCH
        self.turns = [TurnUnit(h) for _, _, h in r.starts]
        self.step = StepUnit(r.starts)
        self.score = ScoreUnit(r)
        self.page = PageTimer(r.score_view_ticks)
        self.phase = G_IDLE
        self.phase_ticks = 0
        self.prep_match = False
        self.step_cnt = 0
        self.step_period = r.step_ticks
        self.paused = False
        self.goal = goal_from_switches(0)
        self.round_index = 0
        self.step_count = 0
        self.show_bikes = False
        self.crashed = (False, False)
        self.head_on = False
        self.tick_cnt = 0
        self.ticks = 0                               # ticks since reset, for logs
        self._log_pending = None
        self._latch_render()

    # --- one game-clock tick ------------------------------------------------
    def tick(self, inputs: BoardInputs = BoardInputs()) -> None:
        rs = self.render                             # 1. fast domain, before the edge
        self.inputs.enable(turns=rs["phase"] == G_PLAY and not rs["paused"],
                           start=rs["phase"] in START_PHASES and not rs["paused"])
        for mask in inputs.btn:
            self.inputs.button_sample(mask)
        for byte in inputs.uart:
            self.inputs.uart_byte(byte)
        self._game_edge(inputs.sw)                   # 2. game-clock edge
        self._fast_after_edge()                      # 3. fast domain, after the edge

    def _game_edge(self, sw_pins: int) -> None:
        r = self.rules
        # Values stable before the edge
        batch = self.batch_cap
        sw = self.sw_sync[-1]
        paused = bool(sw >> SW_PAUSE & 1)
        goal_sw = sw >> SW_GOAL_LSB & 3
        idle = self.mbox.idle()
        rsp = self.mbox.rsp_cap
        ph = self.phase
        tick_cnt = self.tick_cnt
        running = ph == G_PLAY and not paused
        launch = running and self.step_cnt == self.step_period - 1
        resolve = self.step.codes_ready(idle, paused)
        if launch and not self.step.ready(idle):
            raise RuntimeError("Step cadence overrun: the last COMMIT is not done")

        # Capture registers and synchronizers
        self.batch_cap = self.batch_bus
        self.mbox.capture()
        self.sw_sync = [sw_pins] + self.sw_sync[:-1]
        self.tick_cnt = (self.tick_cnt + 1) & TICK_MASK
        self.ticks += 1
        self.page.clock()                            # runs through Pause
        self.paused = paused

        if paused:
            if self.step.state == S_COMMIT and idle:
                self.step.retire()                   # an issued COMMIT still completes
            return

        self.phase_ticks += 1

        # step_unit and score_unit: a Step's outcome (edge k + 2)
        if resolve:
            out = self.step.resolve(rsp.codes)
            self.score.clock_outcome(out, self.goal)
            self.mbox.issue(OP_COMMIT, writes=out.writes,
                            collected=tuple(s for s in out.collected if s is not None))
            self.step_count += 1
            self.crashed, self.head_on = out.crashed, out.head_on
            if any(out.crashed):
                self._enter(G_CRASH)                 # a Match-ending Crash still shows it
            elif self.score.result is not None:
                self._enter(G_MATCH)                 # goal reached without a Crash
            self._log_pending = "step"
        elif self.step.state == S_COMMIT and idle:
            self.step.retire()

        # turn_unit and step_unit: the Step launch (edge k)
        for unit, axes in zip(self.turns, batch.axes):
            unit.clock(axes, apply=running, launch=launch)
        if launch:
            if self.step.state == S_COMMIT:
                self.step.retire()
            targets = self.step.launch([u.heading for u in self.turns])
            self.mbox.issue(OP_READ2, targets=targets)
        if running:
            self.step_cnt = 0 if launch else self.step_cnt + 1
        if launch:
            self.step_period = r.step_ticks          # a playtest speed change starts here

        # match_ctrl: Start, preparation and the Crash display. These read the
        # phase from before the edge; a Step outcome only happens in G_PLAY.
        start = batch.start and ph in START_PHASES and idle
        if start and ph in (G_IDLE, G_MATCH):
            self.goal = goal_from_switches(goal_sw)
            self.score.new_match()
            self.page.restart()
            self._prepare(new_match=True, seed_mix=tick_cnt)
        elif start:                                  # G_READY: release the prepared Round
            self._release()
        elif ph == G_PREP and idle:
            if self.prep_match:
                self._release()
            else:
                self._enter(G_READY)
            self._log_pending = "round"
        elif ph == G_CRASH and self.phase_ticks >= r.crash_ticks and idle:
            if self.score.result is not None:
                self._enter(G_MATCH)
            else:
                self._prepare(new_match=False, seed_mix=tick_cnt)

    def _prepare(self, new_match: bool, seed_mix: int) -> None:
        """round_init plus PREPARE: start heads and Headings, then clear and place."""
        starts = self.rules.starts
        for unit, (_, _, heading) in zip(self.turns, starts):
            unit.load(heading)
        self.step.load(starts)
        self.mbox.issue(OP_PREPARE, new_match=new_match, seed_mix=seed_mix,
                        heads=self.step.head)
        self.prep_match = new_match
        self.round_index = 1 if new_match else self.round_index + 1
        self.step_count = 0
        self.crashed, self.head_on = (False, False), False
        self.show_bikes = True
        self._enter(G_PREP)

    def _release(self) -> None:
        self.step_cnt = 0
        self.step_period = self.rules.step_ticks
        self._enter(G_PLAY)

    def _enter(self, phase: int) -> None:
        self.phase = phase
        self.phase_ticks = 0

    def _fast_after_edge(self) -> None:
        cmd = self.mbox.take()
        if cmd is not None:
            self.mbox.publish(self.ctrl.execute(cmd))
        self.batch_bus = self.inputs.publish()
        self._latch_render()
        if self._log_pending and self.steplog is not None:
            self.steplog(format_line(self, self._log_pending))
        self._log_pending = None

    def _latch_render(self) -> None:
        """Slow-domain state as the fast domain sees it after this edge: the
        render snapshot for drawcon and the values for seg7_driver."""
        self.render = {
            "phase": self.phase,
            "phase_ticks": self.phase_ticks,
            "show_bikes": self.show_bikes,
            "heads": self.step.head,
            "headings": self.step.shown,
            "crashed": self.crashed,
            "paused": self.paused,
        }
        self.seg7_digits = digits(self.page.view, self.score.points, self.score.lives)

    # --- read-only views ----------------------------------------------------
    @property
    def points(self):
        return self.score.points

    @property
    def lives(self):
        return self.score.lives

    @property
    def result(self):
        return self.score.result

    @property
    def reward_cells(self):
        return list(self.ctrl.slots)

    def snapshot(self) -> dict:
        """What the PC renderer draws, plus panel values."""
        rs = self.render
        bikes = rs["show_bikes"]
        return {
            "phase": rs["phase"],
            "phase_name": PHASE_NAMES[rs["phase"]],
            "phase_ticks": rs["phase_ticks"],
            "round": self.round_index,
            "step": self.step_count,
            "heads": list(rs["heads"]) if bikes else None,
            "headings": list(rs["headings"]) if bikes else None,
            "crashed": rs["crashed"],
            "head_on": self.head_on,
            "goal": self.goal,
            "points": list(self.score.points),
            "lives": list(self.score.lives),
            "rewards": list(self.ctrl.slots),
            "reward_values": self.rules.reward_values,
            "result": self.score.result,
            "scoreboard": self.seg7_digits,
        }
