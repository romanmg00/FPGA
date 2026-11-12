"""Write each M2 scenario as a bench event file, plus the model's Step log.

Run from prototipos/tron_fpga/ (headless; no pygame needed):
    python3 ../../proyecto_final/prototypes/core_blocks/game/make_events.py

Writes game/scenarios/<name>.events and <name>.model.log (mailbox crossing,
the scenario's own Step interval), plus <name>.<crossing>-s<N>.log for the
provisional crossings of crossing/FINDINGS.md at the Step intervals of
ADR 0007 (VARIANTS below). Each Step log has an arena log beside it,
<name>.<ref>.arena.log: one CRC-32 of the whole Arena per Step-log line
(model/steplog.py arena_line), which game_tb.sv also writes. The scenario is
parsed by the model's own parser, so the bench and the model replay the same
inputs. Event file, whitespace-separated integers:
    line 1: seed fixed_seed p1_cx p1_cy p1_dir p2_cx p2_cy p2_dir end_tick
    then:   tick kind value    kind 0 reset, 1 button sample mask btn[4:0],
                               2 UART byte, 3 switch levels sw[15:0]
    last:   -1 0 0
Events of one tick keep the scenario's order.
"""

import pathlib
import sys

sys.path.insert(0, ".")
from model.scenario import BTN_BITS, parse, run  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
SCENARIOS = pathlib.Path("scenarios")
# (crossing, Step interval) pairs; "captured" needs at least 8 ticks.
VARIANTS = [("mailbox", 8), ("mailbox", 10), ("qualified", 6), ("qualified", 8),
            ("qualified", 10), ("captured", 8), ("captured", 10)]


def events(sc):
    for tick in sorted(sc.events):
        for ev in sc.events[tick]:
            if ev == "reset":
                yield tick, 0, 0
                continue
            kind, arg = ev.split(":", 1)
            if kind == "btn":
                yield tick, 1, sum(1 << BTN_BITS[n] for n in arg.split("+"))
            elif kind == "uart":
                yield tick, 2, int(arg, 16) if arg.startswith("0x") else ord(arg)
            elif kind == "sw":
                yield tick, 3, int(arg, 0)
            else:
                raise ValueError(f"unknown event {ev!r}")


def main() -> int:
    out = HERE / "scenarios"
    out.mkdir(exist_ok=True)
    names = []
    for path in sorted(SCENARIOS.glob("*.txt")):
        sc = parse(path.read_text(encoding="utf-8"))
        rules = sc.rules()
        (p1x, p1y, p1d), (p2x, p2y, p2d) = rules.starts
        lines = [f"{rules.seed} {int(rules.fixed_seed)} {p1x} {p1y} {p1d} {p2x} {p2y} {p2d} {sc.end}"]
        lines += [f"{t} {k} {v}" for t, k, v in events(sc)]
        lines.append("-1 0 0")
        (out / f"{path.stem}.events").write_text("\n".join(lines) + "\n")
        for crossing, step in [("mailbox", None)] + VARIANTS:
            ref = "model" if step is None else f"{crossing}-s{step}"
            arena = []
            log = run(sc, crossing=crossing, step_ticks=step, arena_log=arena)
            (out / f"{path.stem}.{ref}.log").write_text("\n".join(log) + "\n")
            (out / f"{path.stem}.{ref}.arena.log").write_text("\n".join(arena) + "\n")
        names.append(path.stem)
    (out / "manifest.txt").write_text("\n".join(names) + "\n")
    print(f"wrote {len(names)} scenarios to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
