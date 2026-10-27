"""Arena grid memory (hardware block A1/A2: grid BRAM and its controller).

One word per Cell over the whole screen, padded to a power-of-two stride.
The Cell encoding below is the model's proposal for the pending encoding
decision (VGA plan, open question 8): 3 bits, with the Reward slot number
stored in the Cell so a collected Reward knows which slot to respawn.
"""

from .params import ArenaGeometry

EMPTY = 0
WALL = 1
TRAIL_P1 = 2
TRAIL_P2 = 3
REWARD_SLOT0 = 4          # Reward slots 0..2 are codes 4..6
CELL_BITS = 3

TRAIL = (TRAIL_P1, TRAIL_P2)


def is_reward(code: int) -> bool:
    return REWARD_SLOT0 <= code < REWARD_SLOT0 + 3


def is_blocking(code: int) -> bool:
    """A Bike moving into this Cell Crashes (Wall or any Trail)."""
    return code == WALL or code in TRAIL


class ArenaGrid:
    def __init__(self, geom: ArenaGeometry):
        self.geom = geom
        self.words = bytearray(geom.stride_w * geom.stride_h)
        # Change record for viewers and Step logs: no effect on the rules.
        self.cleared = False
        self.written: list = []

    def address(self, x: int, y: int) -> int:
        """{cell_y, cell_x}: the address is a bit concatenation."""
        return (y << self.geom.x_bits) | x

    def read(self, x: int, y: int) -> int:
        return self.words[self.address(x, y)]

    def write(self, x: int, y: int, code: int) -> None:
        self.words[self.address(x, y)] = code
        self.written.append((x, y))

    def clear(self) -> None:
        """Arena clear: every word written once (the full padded allocation)."""
        g = self.geom
        for y in range(g.stride_h):
            for x in range(g.stride_w):
                self.words[self.address(x, y)] = EMPTY if g.in_interior(x, y) else WALL
        self.cleared = True
        self.written.clear()

    def drain_changes(self):
        """Return (cleared, written Cells) since the last call, then reset."""
        changes = (self.cleared, self.written)
        self.cleared = False
        self.written = []
        return changes
