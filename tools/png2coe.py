"""Convert sprite PNGs to RGB444 .coe (sprite tips) and .mem ($readmemh) files.

Row by row, top-left first, each channel `v >> 4`, exactly like the viewer's
juego.sprites.load_png: a pixel with alpha below 128 is 000 (transparent);
art uses 0F0 as the tint key. Square, power-of-two sides only.

Usage (from the repository root):
    python3 tools/png2coe.py OUT_DIR PNG...
writes OUT_DIR/<name>.coe and OUT_DIR/<name>.mem for each PNG.
"""

import pathlib
import sys

from PIL import Image


def words(path: pathlib.Path) -> list:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if w != h or w & (w - 1):
        raise ValueError(f"{path.name}: {w}x{h} is not a square power of two")
    out = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            out.append(0 if a < 128 else (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4))
    return out


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    out = pathlib.Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    for name in argv[1:]:
        src = pathlib.Path(name)
        data = words(src)
        hexw = [f"{w:03X}" for w in data]
        (out / f"{src.stem}.coe").write_text(
            "memory_initialization_radix=16;\nmemory_initialization_vector=\n"
            + ",\n".join(hexw) + ";\n")
        (out / f"{src.stem}.mem").write_text("\n".join(hexw) + "\n")
        print(f"{src.stem}: {len(data)} words")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
