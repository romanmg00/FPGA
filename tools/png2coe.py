#!/usr/bin/env python3
"""Convert a sprite PNG to a Vivado .coe file for a Block Memory Generator ROM.

Follows the course sprite tips and the CS-256 VGA and Sprite Design Plan:
- RGB444: each 8-bit channel keeps its top 4 bits (v >> 4), one 12-bit word per pixel.
- Row by row: word r * width + c is the pixel at row r, column c.
- 000 is transparent and 0F0 is the Player tint key. A pixel with alpha < 128
  becomes 000, so a PNG with a transparent background also works.

Usage:
    python3 tools/png2coe.py assets/candidates/bike-synth-32.png proyecto_final/sprites/bike_synth.coe

Needs Pillow (pip install pillow).
"""

import argparse
import sys
from collections import Counter

from PIL import Image

TRANSPARENT = 0x000
TINT_KEY = 0x0F0


def png_words(path):
    """Return (width, height, words) for the PNG at path, in row order."""
    img = Image.open(path).convert("RGBA")
    width, height = img.size
    words = []
    for r, g, b, a in img.getdata():
        if a < 128:
            words.append(TRANSPARENT)
        else:
            words.append(((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4))
    return width, height, words


def write_coe(path, words):
    with open(path, "w", newline="\n") as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        last = len(words) - 1
        for i, w in enumerate(words):
            f.write(f"{w:03X}{';' if i == last else ','}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("png", help="input sprite PNG")
    parser.add_argument("coe", help="output .coe file")
    args = parser.parse_args()

    width, height, words = png_words(args.png)

    problems = []
    if width != height:
        problems.append(f"{width}x{height} is not square")
    if width & (width - 1):
        problems.append(f"side {width} is not a power of two, so the address is not a bit concatenation")
    if problems:
        for p in problems:
            print(f"ERROR {args.png}: {p}", file=sys.stderr)
        return 1

    write_coe(args.coe, words)

    counts = Counter(words)
    addr_bits = (len(words) - 1).bit_length()
    print(f"{args.coe}: {width}x{height}, {len(words)} words of 12 bits, address width {addr_bits}")
    print(f"  transparent 000: {counts[TRANSPARENT]}, tint 0F0: {counts[TINT_KEY]}, "
          f"other colours: {len(counts) - (TRANSPARENT in counts) - (TINT_KEY in counts)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
