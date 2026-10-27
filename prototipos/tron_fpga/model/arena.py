"""Arena memory (hardware block A1/A2: arena_map and its controller).

8192 x 4-bit words, one per Cell of the padded 128 x 64 grid, addressed by
{cy[5:0], cx[6:0]}. The Cell codes are the agreed ones and match game_pkg.
"""

from .params import ADDR_W, CX_W, GEOMETRY

EMPTY = 0
WALL = 1                  # Wall or any inaccessible Cell (HUD band, padding)
TRAIL_P1, HEAD_P1 = 2, 3
TRAIL_P2, HEAD_P2 = 4, 5
CRASH = 6                 # defined by the agreement; this model does not write it yet
RESERVED = 7
REWARD_SLOT0 = 8          # Reward slots 0..2 are codes 8..10
CELL_BITS = 4

TRAIL = (TRAIL_P1, TRAIL_P2)
HEAD = (HEAD_P1, HEAD_P2)
PLAYER_CODES = ((TRAIL_P1, HEAD_P1), (TRAIL_P2, HEAD_P2))


def is_reward(code: int) -> bool:
    return REWARD_SLOT0 <= code < REWARD_SLOT0 + 3


def is_blocking(code: int) -> bool:
    """A Bike moving into this Cell Crashes: anything but EMPTY or a Reward."""
    return code != EMPTY and not is_reward(code)


def player_of(code: int):
    """0 or 1 for a Trail or head Cell, otherwise None."""
    for i, codes in enumerate(PLAYER_CODES):
        if code in codes:
            return i
    return None


def address(x: int, y: int) -> int:
    """{cy, cx}: the address is a bit concatenation."""
    return (y << CX_W) | x


class ArenaGrid:
    def __init__(self):
        self.geom = GEOMETRY
        self.words = bytearray(1 << ADDR_W)
        # Change record for viewers and Step logs: no effect on the rules.
        self.cleared = False
        self.written: list = []

    def address(self, x: int, y: int) -> int:
        return address(x, y)

    def read(self, x: int, y: int) -> int:
        return self.words[address(x, y)]

    def write(self, x: int, y: int, code: int) -> None:
        self.words[address(x, y)] = code
        self.written.append((x, y))

    def clear(self) -> None:
        """Arena clear: every one of the 8192 words written once."""
        g = self.geom
        for y in range(g.stride_h):
            for x in range(g.stride_w):
                self.words[address(x, y)] = EMPTY if g.in_interior(x, y) else WALL
        self.cleared = True
        self.written.clear()

    def drain_changes(self):
        """Return (cleared, written Cells) since the last call, then reset."""
        changes = (self.cleared, self.written)
        self.cleared = False
        self.written = []
        return changes
