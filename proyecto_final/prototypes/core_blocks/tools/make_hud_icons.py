"""Write the HUD icon ROM for drawcon_game from the viewer's 1-bit icons.

Four 16 x 16 icons (juego/font.py ICONS): 0 life, 1 life_lost, 2 play,
3 crown. One 16-bit word per icon row, address {icon[1:0], row[3:0]};
bit c of a word is column c, so the hardware reads word[gx].

Usage (from the repository root, with the tron_fpga environment):
    python3 proyecto_final/prototypes/core_blocks/tools/make_hud_icons.py OUT.mem
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
sys.path.insert(0, str(ROOT / "prototipos" / "tron_fpga"))

from juego.font import ICON_PX, ICONS  # noqa: E402

ORDER = ("life", "life_lost", "play", "crown")


def words() -> list:
    out = []
    for name in ORDER:
        for row in ICONS[name]:
            assert len(row) == ICON_PX == 16
            out.append(sum(1 << c for c, on in enumerate(row) if on))
    return out


if __name__ == "__main__":
    path = pathlib.Path(sys.argv[1])
    path.write_text("".join(f"{w:04x}\n" for w in words()))
    print(f"{path}: {len(ORDER)} icons, {len(ORDER) * ICON_PX} words")
