"""Write drawcon_game's synthwave background tables from the viewer's fx.py.

Three $readmemh files, all from juego/fx.py with the synthwave palette
(juego/candidates.py), so the HDL background is the viewer's build_base:

  synthwave-sky.mem   64 x 12 bit: sky_lut(pal, None), one colour per 16 px
                      row band, index y[9:4] (rows 50..63 repeat the last).
  synthwave-sun.mem   (2 R + 1) x 21 bit: one word per sun row from its top,
                      {lit, half_width[7:0], colour[11:0]} from
                      sun_rows_full(pal); lit = 0 for a cut stripe.
  synthwave-grid.mem  4 x 12 bit: the neon grid line colour per animation
                      phase, lerp(grid_glow, grid, level) as fx._grid.

Usage (from the repository root, with the tron_fpga environment):
    python3 proyecto_final/prototypes/core_blocks/tools/make_bg_luts.py OUT_DIR
"""

import os
import pathlib
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
sys.path.insert(0, str(ROOT / "prototipos" / "tron_fpga"))

from juego import fx  # noqa: E402
from juego.candidates import PALETTES  # noqa: E402
from juego.rgb444 import lerp  # noqa: E402

PAL = PALETTES["synthwave"]
GRID_LEVELS = (0.45, 0.75, 1.0, 0.75)          # fx._grid, per phase


def sky() -> list:
    lut = fx.sky_lut(PAL, None)
    return lut + [lut[-1]] * (64 - len(lut))


def sun() -> list:
    rows = {dy: (w, col) for dy, w, col in fx.sun_rows_full(PAL)}
    out = []
    for dy in range(-fx.SUN_R, fx.SUN_R + 1):
        if dy in rows:
            w, col = rows[dy]
            assert w < 256
            out.append(1 << 20 | w << 12 | col)
        else:
            out.append(0)
    return out


def grid() -> list:
    return [lerp(PAL["grid_glow"], PAL["grid"], level) for level in GRID_LEVELS]


def write(path: pathlib.Path, words: list, digits: int) -> None:
    path.write_text("".join(f"{w:0{digits}x}\n" for w in words))
    print(f"{path}: {len(words)} words")


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1])
    write(out / "synthwave-sky.mem", sky(), 3)
    write(out / "synthwave-sun.mem", sun(), 6)
    write(out / "synthwave-grid.mem", grid(), 3)
