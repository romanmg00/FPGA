"""Write the Look Prototype's candidate art as PNGs into assets/candidates/.

The PNGs are starting points to edit. The viewer loads an edited PNG in
place of the generated art with the same name. Existing files are kept
unless --force is given.

Usage (from the repository root):  python tools/make_candidate_art.py [--force]
"""

import argparse
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "prototipos", "tron_fpga"))

from juego import art                   # noqa: E402
from juego.rgb444 import expand         # noqa: E402

OUT = os.path.join(ROOT, "assets", "candidates")


def save(name: str, size: int, words: list, force: bool) -> None:
    path = os.path.join(OUT, name + ".png")
    if os.path.exists(path) and not force:
        print("kept   ", os.path.relpath(path, ROOT))
        return
    img = Image.new("RGB", (size, size))
    img.putdata([expand(w) for w in words])
    img.save(path)
    print("written", os.path.relpath(path, ROOT))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="overwrite existing PNGs")
    args = parser.parse_args()
    os.makedirs(OUT, exist_ok=True)
    for style, fn in art.BIKE_STYLES.items():
        for size in (16, 32, 64):
            save(f"bike-{style}-{size}", size, fn(size), args.force)
    done = set()
    for small, big in art.REWARD_LOOKS.values():
        for fn in (small, big):
            if fn in done:
                continue
            done.add(fn)
            for size in (4, 8, 16, 32):
                name = fn.__name__[7:].replace("_", "-")
                save(f"reward-{name}-{size}", size, fn(size), args.force)


if __name__ == "__main__":
    main()
