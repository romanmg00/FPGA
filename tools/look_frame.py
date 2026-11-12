"""Compare one HDL frame of drawcon_game with the Python viewer, quickly.

  scene OUT_DIR [--ticks N]
      Plays a scripted Round in the headless model (prototipos/tron_fpga/model)
      for N game ticks and writes the state drawcon_game reads:
        OUT_DIR/scene-arena.mem  8192 Cell codes, address {cy[5:0], cx[6:0]}
        OUT_DIR/scene-snap.mem   14 snapshot words (order in SNAP_FIELDS)
      and the viewer's synthwave frame of that state at video frame 1 (animation
      phase 0, Trail stripes shifted 2 px), the frame drawcon_frame_tb dumps:
        OUT_DIR/python.png       for comparison: crt off (no scanlines), no
                                 crash flash, which the HDL does not draw yet
        OUT_DIR/python-full.png  the viewer's complete frame, for reference
  compare FRAME.hex OUT_DIR
      Turns the frame dumped by drawcon_frame_tb into OUT_DIR/hdl.png, diffs it
      with OUT_DIR/python.png and writes OUT_DIR/compare.png (Python | HDL |
      differing pixels in red). Prints the differing pixels per region and the
      Arena Cells that differ.

Run with the tron_fpga environment (pygame-ce, NumPy, Pillow), from anywhere.
"""

import argparse
import os
import pathlib
import sys
from dataclasses import replace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "prototipos" / "tron_fpga"))

import numpy as np  # noqa: E402
import pygame  # noqa: E402
from PIL import Image  # noqa: E402

from juego.app import ASSETS  # noqa: E402
from juego.candidates import PALETTES, PRESETS, LookConfig  # noqa: E402
from juego.render import SIZE, FrameRenderer  # noqa: E402
from juego.sprites import SpriteLibrary  # noqa: E402
from model import BoardInputs, Game, RuleParams  # noqa: E402
from model.params import SAL_CY, SAL_P1_CX, SAL_P2_CX  # noqa: E402
from model.score_unit import DRAW  # noqa: E402
from model.turn_unit import DOWN, LEFT, RIGHT, UP  # noqa: E402

W, H, HUD = 1280, 800, 64
SNAP_FIELDS = ("phase", "paused", "blink_ticks", "head_p1", "head_p2", "shown_p1", "shown_p2",
               "crashed_p1", "crashed_p2", "points_p1", "points_p2", "lives_p1", "lives_p2", "result")
# Default script: Start, then both Players turn twice, so Trails have corners.
SCRIPT = {5: dict(start=True), 40: dict(p1=(UP,), p2=(DOWN,)), 80: dict(p1=(RIGHT,), p2=(LEFT,)),
          120: dict(p1=(DOWN,), p2=(UP,))}


def play(ticks: int) -> Game:
    game = Game(RuleParams())
    for t in range(ticks):
        game.tick(BoardInputs.keys(**SCRIPT.get(t, {})))
    return game


def snap_words(game: Game) -> list:
    s = game.snapshot()
    heads = s["heads"] or [(SAL_P1_CX, SAL_CY), (SAL_P2_CX, SAL_CY)]
    headings = s["headings"] or [RIGHT, LEFT]
    result = {None: 0, 0: 1, 1: 2, DRAW: 3}[s["result"]]
    values = dict(phase=s["phase"], paused=int(s["paused"]), blink_ticks=s["phase_ticks"] % 32,
                  head_p1=heads[0][1] << 7 | heads[0][0], head_p2=heads[1][1] << 7 | heads[1][0],
                  shown_p1=headings[0], shown_p2=headings[1],
                  crashed_p1=int(s["crashed"][0]), crashed_p2=int(s["crashed"][1]),
                  points_p1=s["points"][0], points_p2=s["points"][1],
                  lives_p1=s["lives"][0], lives_p2=s["lives"][1], result=result)
    return [values[f] for f in SNAP_FIELDS]


def render(game: Game, look: LookConfig) -> np.ndarray:
    sprites = SpriteLibrary(ASSETS)
    bike = sprites.bike(look.bike_style)
    rewards = tuple(sprites.reward(look.reward_look, k) for k in (0, 1))
    r = FrameRenderer(game.geom, look, PALETTES[look.palette], bike, rewards)
    r.redraw_all(game.grid)
    r.frame = 1                                       # the bench's video frame: phase 0, stripes at 2 px
    frame = pygame.Surface(SIZE, 0, 32)
    r.draw(frame, game.snapshot())
    return pygame.surfarray.array3d(frame).transpose(1, 0, 2)


def scene(out: pathlib.Path, ticks: int) -> None:
    out.mkdir(parents=True, exist_ok=True)
    pygame.init()
    pygame.display.set_mode((8, 8))
    game = play(ticks)
    words = [0] * 8192
    for cy in range(50):
        for cx in range(80):
            words[cy << 7 | cx] = game.grid.read(cx, cy)
    (out / "scene-arena.mem").write_text("".join(f"{w:x}\n" for w in words))
    (out / "scene-snap.mem").write_text("".join(f"{w:08x}\n" for w in snap_words(game)))
    full = replace(LookConfig(), **PRESETS["synthwave"])
    Image.fromarray(render(game, full)).save(out / "python-full.png")
    Image.fromarray(render(game, replace(full, crt="off", crash="ring"))).save(out / "python.png")
    s = game.snapshot()
    print(f"scene at tick {ticks}: phase {s['phase_name']}, heads {s['heads']}, "
          f"points {s['points']}, lives {s['lives']} -> {out}")


def compare(frame_hex: pathlib.Path, out: pathlib.Path) -> int:
    words = np.array([int(v, 16) for v in frame_hex.read_text().split()], dtype=np.int32)
    if words.size != W * H:
        raise SystemExit(f"{frame_hex}: {words.size} words, expected {W * H}")
    hdl = np.stack([(words >> 8 & 15), (words >> 4 & 15), (words & 15)], axis=1).reshape(H, W, 3) * 17
    hdl = hdl.astype(np.uint8)
    Image.fromarray(hdl).save(out / "hdl.png")
    py = np.array(Image.open(out / "python.png").convert("RGB"))
    diff = np.any(hdl // 17 != py // 17, axis=2)
    marked = hdl.copy()
    marked[diff] = (255, 0, 0)
    Image.fromarray(np.concatenate([py, hdl, marked], axis=1)).save(out / "compare.png")
    regions = {"HUD band (y < 64)": diff[:HUD], "Wall and border": diff[HUD:].copy(), "Arena": None}
    arena = np.zeros_like(diff)
    arena[80:784, 16:1264] = True
    regions["Wall and border"][arena[HUD:]] = False
    regions["Arena"] = diff & arena
    total = int(diff.sum())
    print(f"differing pixels: {total} of {W * H}")
    for name, m in regions.items():
        print(f"  {name}: {int(m.sum())}")
    ys, xs = np.nonzero(regions["Arena"])
    cells = sorted({(int(x) // 16, int(y) // 16) for x, y in zip(xs, ys)})
    if cells:
        shown = ", ".join(f"({x},{y})" for x, y in cells[:30])
        print(f"  Arena Cells that differ ({len(cells)}): {shown}{' ...' if len(cells) > 30 else ''}")
    print(f"images: {out / 'compare.png'} (Python | HDL | differences in red)")
    return total


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("scene")
    a.add_argument("out", type=pathlib.Path)
    a.add_argument("--ticks", type=int, default=150)
    b = sub.add_parser("compare")
    b.add_argument("frame", type=pathlib.Path)
    b.add_argument("out", type=pathlib.Path)
    args = ap.parse_args()
    if args.cmd == "scene":
        scene(args.out, args.ticks)
    else:
        compare(args.frame, args.out)


if __name__ == "__main__":
    main()
