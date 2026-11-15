"""Turn a frame dumped by tron_system_tb (-g DUMP_FRAMES=1) into a PNG.

The dump holds 1280 x 800 RGB444 words, one hex word per line, row by row.
Each 4-bit level n is shown as n * 17, like the viewer's rgb444.expand.

Usage: python3 proyecto_final/prototypes/core_blocks/tools/hdl_frame_to_png.py FRAME.hex OUT.png
"""

import sys

from PIL import Image

W, H = 1280, 800


def main(src: str, dst: str) -> None:
    with open(src) as f:
        words = [int(line, 16) for line in f if line.strip()]
    if len(words) != W * H:
        raise SystemExit(f"{src}: {len(words)} words, expected {W * H}")
    img = Image.new("RGB", (W, H))
    img.putdata([((w >> 8 & 15) * 17, (w >> 4 & 15) * 17, (w & 15) * 17) for w in words])
    img.save(dst)


if __name__ == "__main__":
    main(*sys.argv[1:3])
