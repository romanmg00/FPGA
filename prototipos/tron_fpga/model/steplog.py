"""Step-log format (M2): one line per Step outcome and per prepared Round.

The model and the HDL testbench each write this format, and
tools/steplog_diff.py reports the first line where two logs differ. Fields
are space-separated `key=value` pairs in a fixed order:

    tick=128 round=1 step=20 phase=CRASH p1=39,27,R p2=40,27,L crash=11
    points=0,0 lives=2,2 goal=10 r0=52,40 r1=11,31 r2=- result=-

- tick: game-clock ticks since reset, counting the tick of this outcome.
- round, step: Round in the Match, Step in the Round. A line with step=0
  is written when a Round's PREPARE is done; it shows the start state and
  the three initial Rewards.
- phase: match_ctrl phase after this edge (PHASE_NAMES).
- p1, p2: head Cell cx,cy and the Heading shown (U, R, D, L).
- crash: P1 and P2 Crash flags of this Step (1 = Crashed).
- points, lives: P1,P2 after the Step's Rewards, Survival Bonus and Lives.
- goal: the Points Goal captured when this Match started.
- r0, r1, r2: Reward slot Cells after the Step's COMMIT, or `-` if absent.
- result: `-` while the Match goes on, `P1`, `P2` or `draw`.

In SystemVerilog, $fwrite with "%0d" fields and two small functions for
the Heading letter and the phase name produce the same text. The testbench
reads the slot Cells from arena_ctrl's slot registers.
"""

from .params import PHASE_NAMES
from .score_unit import DRAW
from .turn_unit import HEADING_LETTERS

FIELDS = ("tick", "round", "step", "phase", "p1", "p2", "crash", "points", "lives", "goal",
          "r0", "r1", "r2", "result")


def _cell(c):
    return "-" if c is None else f"{c[0]},{c[1]}"


def format_line(game, kind: str = "step") -> str:
    heads, headings = game.step.head, game.step.shown
    result = game.score.result
    res = "-" if result is None else "draw" if result == DRAW else f"P{result + 1}"
    crash = "".join("1" if c else "0" for c in game.crashed)
    slots = game.ctrl.slots
    values = (
        game.ticks, game.round_index, 0 if kind == "round" else game.step_count,
        PHASE_NAMES[game.phase],
        f"{heads[0][0]},{heads[0][1]},{HEADING_LETTERS[headings[0]]}",
        f"{heads[1][0]},{heads[1][1]},{HEADING_LETTERS[headings[1]]}",
        crash, "{},{}".format(*game.score.points), "{},{}".format(*game.score.lives), game.goal,
        _cell(slots[0]), _cell(slots[1]), _cell(slots[2]), res,
    )
    return " ".join(f"{k}={v}" for k, v in zip(FIELDS, values))


def parse_line(line: str) -> dict:
    return dict(item.split("=", 1) for item in line.split())
