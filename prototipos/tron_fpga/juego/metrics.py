"""Performance and hardware-budget log for the Look Prototype.

Run from prototipos/tron_fpga/:  python -m juego.metrics
Renders each configuration headless, then appends one row per
configuration to metrics/look-metrics.csv (history, with the git commit and
host) and rewrites metrics/latest.md. Commit both files to keep the record.

PC timing is for the viewer only; the FPGA renders in real time by design.
The hardware columns are the panel's estimates (see juego/budget.py, fx.py).
"""

import csv
import os
import platform
import statistics
import subprocess
import time
from dataclasses import replace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import numpy as np  # noqa: E402
import pygame  # noqa: E402

from model import BoardInputs, RuleParams  # noqa: E402
from model.params import BORDER_PX  # noqa: E402
from model.turn_unit import DOWN, LEFT, RIGHT, UP  # noqa: E402

from . import budget, fx  # noqa: E402
from .candidates import PRESETS, LookConfig  # noqa: E402
from .hud import digit_font  # noqa: E402

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))     # prototipos/tron_fpga/
OUT_DIR = os.path.join(HERE, "metrics")
CSV_PATH = os.path.join(OUT_DIR, "look-metrics.csv")
MD_PATH = os.path.join(OUT_DIR, "latest.md")

WARMUP, FRAMES = 30, 240
# frame -> (P1 Turn, P2 Turn): both Bikes keep moving and turning
SCRIPT = {40: (UP, DOWN), 90: (RIGHT, LEFT), 140: (DOWN, UP), 190: (LEFT, RIGHT)}

# Every preset on the agreed 16 px layout. Rows before this layout was fixed
# also compared 4 and 8 px Cells; the cell_px column keeps them comparable.
CONFIGS = [(name, preset) for name, preset in PRESETS.items()]

FIELDS = ["date", "commit", "dirty", "host", "python", "pygame", "config", "cell_px",
          "build_ms", "draw_ms_median", "draw_ms_p95", "ramb18", "ramb18_pct",
          "effect_table_bits", "clear_us", "placement2_us", "blank_us",
          "rgb444_ok", "border_ok", "flags"]


def _git(*args) -> str:
    try:
        return subprocess.run(["git", *args], cwd=HERE, capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def frame_ok(a) -> tuple:
    b = BORDER_PX
    rgb444 = bool((a % 17 == 0).all())
    border = all((e == 255).all() for e in (a[:b], a[-b:], a[:, :b], a[:, -b:]))
    return rgb444, border


def measure(app, look) -> dict:
    app.look = look
    app.rules = RuleParams()
    t0 = time.perf_counter()
    app._new_game()
    build_ms = (time.perf_counter() - t0) * 1000
    frame = pygame.Surface((1280, 800), 0, 32)
    times, rgb444, border = [], True, True
    for f in range(WARMUP + FRAMES):
        p1, p2 = SCRIPT.get(f - WARMUP, (None, None))
        turns = ((p1,), (p2,)) if p1 is not None else ((), ())
        inputs = BoardInputs.keys(p1=turns[0], p2=turns[1], start=(f == 0))
        t0 = time.perf_counter()
        app.game.tick(inputs)
        app.renderer.update_cells(app.game.grid)
        app.renderer.draw(frame, app.game.snapshot())
        dt = (time.perf_counter() - t0) * 1000
        if f >= WARMUP:
            times.append(dt)
            if f % 60 == 0:
                ok = frame_ok(pygame.surfarray.array3d(frame))
                rgb444, border = rgb444 and ok[0], border and ok[1]
    rows, total18, clear, flags, notes = app.checks()
    table_bits = sum(w * d for _, w, d in fx.lut_items(look, digit_font(look).glyph_h))
    return {
        "build_ms": f"{build_ms:.0f}",
        "draw_ms_median": f"{statistics.median(times):.2f}",
        "draw_ms_p95": f"{float(np.percentile(times, 95)):.2f}",
        "ramb18": total18,
        "ramb18_pct": f"{100 * total18 / (2 * budget.RAMB36_TOTAL):.1f}",
        "effect_table_bits": table_bits,
        "clear_us": f"{clear:.1f}",
        "placement2_us": f"{2 * budget.placement_us(app.geom):.1f}",
        "blank_us": f"{budget.BLANK_US:.1f}",
        "rgb444_ok": rgb444,
        "border_ok": border,
        "flags": " | ".join(flags) if flags else "none",
    }


def main():
    pygame.init()
    pygame.display.set_mode((1, 1))
    from .app import App
    app = App()
    stamp = {
        "date": time.strftime("%Y-%m-%d %H:%M"),
        "commit": _git("rev-parse", "--short", "HEAD") or "unknown",
        "dirty": bool(_git("status", "--porcelain")),          # whole repository
        "host": platform.node(),
        "python": platform.python_version(),
        "pygame": pygame.version.ver,
    }
    results = []
    for name, fields in CONFIGS:
        look = replace(LookConfig(), **fields)
        row = dict(stamp, config=name, cell_px=app.geom.cell_px, **measure(app, look))
        results.append(row)
        print(f"{name:<18} draw {row['draw_ms_median']} ms (p95 {row['draw_ms_p95']}), "
              f"RAMB18 {row['ramb18']}, clear {row['clear_us']} us, flags: {row['flags']}")

    os.makedirs(OUT_DIR, exist_ok=True)
    new = not os.path.exists(CSV_PATH)
    with open(CSV_PATH, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        if new:
            w.writeheader()
        w.writerows(results)
    write_latest(stamp, results)
    print("wrote", os.path.relpath(CSV_PATH, HERE), "and", os.path.relpath(MD_PATH, HERE))


def write_latest(stamp, results):
    lines = [
        "# Look Prototype metrics (latest run)",
        "",
        f"Run {stamp['date']} on `{stamp['host']}`, commit `{stamp['commit']}`"
        f"{' with uncommitted changes' if stamp['dirty'] else ''}; Python {stamp['python']}, "
        f"pygame-ce {stamp['pygame']}. History: `look-metrics.csv`. Regenerate with "
        "`python -m juego.metrics` from `prototipos/tron_fpga/`, then commit both files.",
        "",
        "Draw time is the PC viewer's work per 1280 x 800 frame (game tick, Trail update, "
        f"render, final colour stage), headless, {FRAMES} frames after {WARMUP} warm-up; "
        "the 60 fps budget is 16.7 ms. Build time is a renderer rebuild (look change).",
        "",
        "Hardware columns are estimates against the XC7A100T and the handout timing: "
        f"270 RAMB18 halves; vertical blanking {budget.BLANK_US:.1f} us (47,040 pixel clocks). "
        "Arena clear and Reward placement assume one grid access per pixel clock.",
        "",
        "| Configuration | Draw median / p95 (ms) | Build (ms) | RAMB18 | Effect tables (b) "
        "| Arena clear (us) | 2 placements (us) | RGB444 | White border | Lockdown flags |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in results:
        lines.append(
            f"| {r['config']} | {r['draw_ms_median']} / {r['draw_ms_p95']} | {r['build_ms']} "
            f"| {r['ramb18']} ({r['ramb18_pct']}%) | {r['effect_table_bits']} | {r['clear_us']} "
            f"| {r['placement2_us']} | {'yes' if r['rgb444_ok'] else 'NO'} "
            f"| {'yes' if r['border_ok'] else 'NO'} | {r['flags'].replace(' | ', '; ')} |")
    lines.append("")
    with open(MD_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
