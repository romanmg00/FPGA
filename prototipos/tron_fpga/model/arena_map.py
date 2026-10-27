"""arena_map (A1): the 8192 x 4-bit Arena BRAM.

One word per Cell of the padded 128 x 64 grid, addressed by {cy[5:0], cx[6:0]}.
Port A belongs to arena_ctrl, the only writer; port B is drawcon's read-only
port. Both read synchronously in the HDL; the model returns the word at once
and leaves read latency to arena_ctrl's cycle count. A BRAM cannot be cleared
by `rst`, so arena_ctrl clears it word by word.
"""

from .params import (ADDR_W, CELL_BITS, CELL_CRASH, CELL_EMPTY, CELL_P1_HEAD, CELL_P1_TRAIL,
                     CELL_P2_HEAD, CELL_P2_TRAIL, CELL_RESERVED, CELL_REWARD0, CELL_WALL, CX_W,
                     GEOMETRY)

# Short names for the CELL_* codes
EMPTY, WALL = CELL_EMPTY, CELL_WALL
TRAIL_P1, HEAD_P1 = CELL_P1_TRAIL, CELL_P1_HEAD
TRAIL_P2, HEAD_P2 = CELL_P2_TRAIL, CELL_P2_HEAD
CRASH, RESERVED, REWARD_SLOT0 = CELL_CRASH, CELL_RESERVED, CELL_REWARD0

TRAIL = (TRAIL_P1, TRAIL_P2)
HEAD = (HEAD_P1, HEAD_P2)
PLAYER_CODES = ((TRAIL_P1, HEAD_P1), (TRAIL_P2, HEAD_P2))
WORDS = 1 << ADDR_W


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
    """{cy, cx}: the address is a bit concatenation, no multiplier."""
    return (y << CX_W) | x


def cell_of(addr: int) -> tuple:
    return addr & ((1 << CX_W) - 1), addr >> CX_W


def clear_word(addr: int) -> int:
    """What the Arena clear writes at `addr`: EMPTY on playable Cells, else WALL."""
    return EMPTY if GEOMETRY.in_interior(*cell_of(addr)) else WALL


CLEAR_IMAGE = bytes(clear_word(a) for a in range(WORDS))


class ArenaMap:
    def __init__(self):
        self.geom = GEOMETRY
        self.words = bytearray(WORDS)
        assert max(REWARD_SLOT0 + 2, RESERVED) < 1 << CELL_BITS
        # Change record for the PC renderer and Step logs; no effect on the rules.
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
        self.words[:] = CLEAR_IMAGE
        self.cleared = True
        self.written.clear()

    def drain_changes(self):
        """Return (cleared, written Cells) since the last call, then reset."""
        changes = (self.cleared, self.written)
        self.cleared = False
        self.written = []
        return changes


# The PC renderer and older tests know the memory by this name.
ArenaGrid = ArenaMap
