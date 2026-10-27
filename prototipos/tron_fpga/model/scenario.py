"""Scenario files (M2): tick-indexed board inputs that the model and the HDL testbench both replay.

Format, one item per line; `#` starts a comment:

    param step_ticks 6          rule parameter (testbench: module parameter)
    param start_p2 58,27,L      start Cell and Heading override
    3 btn:U                     at tick 3, one button sample: P1 UP
    3 btn:U+R                   one sample with two buttons (a tie)
    9 uart:w uart:0x20          UART bytes in order: a character or 0xNN
    40 sw:0x0001                switch levels from this tick on (SW0 = Pause)
    90 reset                    CPU_RESETN before this tick's inputs
    end 400                     run through tick 400

Ticks count from 1 and must not decrease. Button names: U, D, L, R, C
(BTNC, Start). Parameters: step_ticks, crash_ticks, score_view_ticks,
lives, seed, fixed_seed (default 1: repeatable), start_p1, start_p2.

Run a scenario and print its Step log:
    python -m model.scenario scenarios/04-head-on-same-cell.txt
"""

import sys
from dataclasses import dataclass, field

from .game_top import BoardInputs, Game
from .params import BTN_C, BTN_D, BTN_L, BTN_R, BTN_U, DEFAULT_STARTS, RuleParams
from .turn_unit import HEADING_LETTERS

BTN_BITS = {"U": BTN_U, "D": BTN_D, "L": BTN_L, "R": BTN_R, "C": BTN_C}
INT_PARAMS = ("step_ticks", "crash_ticks", "score_view_ticks", "lives", "seed", "fixed_seed")


@dataclass
class Scenario:
    params: dict = field(default_factory=dict)
    events: dict = field(default_factory=dict)      # tick -> [event, ...]
    end: int = 0

    def rules(self) -> RuleParams:
        kw = {k: v for k, v in self.params.items() if k in INT_PARAMS}
        kw["fixed_seed"] = bool(kw.get("fixed_seed", 1))
        starts = list(DEFAULT_STARTS)
        for i, key in enumerate(("start_p1", "start_p2")):
            if key in self.params:
                starts[i] = self.params[key]
        return RuleParams(**kw, starts=tuple(starts))


def _start(text: str) -> tuple:
    x, y, d = text.split(",")
    return int(x), int(y), HEADING_LETTERS.index(d)


def parse(text: str) -> Scenario:
    sc = Scenario()
    last = 0
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].split()
        if not line:
            continue
        if line[0] == "param":
            name, value = line[1], line[2]
            sc.params[name] = _start(value) if name.startswith("start_") else int(value, 0)
        elif line[0] == "end":
            sc.end = int(line[1])
        else:
            tick = int(line[0])
            if tick < last:
                raise ValueError(f"line {n}: tick {tick} comes before tick {last}")
            last = tick
            sc.events.setdefault(tick, []).extend(line[1:])
    sc.end = max(sc.end, last)
    return sc


def run(sc: Scenario, game=None) -> list:
    """Replay `sc` and return its Step log lines."""
    log = []
    game = game or Game(sc.rules(), steplog=log.append)
    game.steplog = log.append
    sw = 0
    for tick in range(1, sc.end + 1):
        btn, uart = [], bytearray()
        for ev in sc.events.get(tick, ()):
            if ev == "reset":
                game.reset()
                continue
            kind, arg = ev.split(":", 1)
            if kind == "btn":
                mask = 0
                for name in arg.split("+"):
                    mask |= 1 << BTN_BITS[name]
                btn.append(mask)
            elif kind == "uart":
                uart.append(int(arg, 16) if arg.startswith("0x") else ord(arg))
            elif kind == "sw":
                sw = int(arg, 0)
            else:
                raise ValueError(f"tick {tick}: unknown event {ev!r}")
        game.tick(BoardInputs(tuple(btn), bytes(uart), sw))
    return log


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        print("usage: python -m model.scenario SCENARIO.txt", file=sys.stderr)
        return 2
    with open(argv[0], encoding="utf-8") as f:
        for line in run(parse(f.read())):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
