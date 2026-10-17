"""Reward placement (hardware block G4).

1. Up to RANDOM_DRAWS candidates come from LFSR draws: x is the low x_bits
   of the word, y the next y_bits. The first whose grid word is EMPTY wins
   (Walls, HUD area and stride padding all hold WALL). This is rejection
   sampling, so no modulo circuit is needed.
2. If every draw was occupied, scan the grid in address order, starting
   after the last candidate and wrapping, and take the first EMPTY Cell.
3. If there is no EMPTY Cell at all, the slot stays empty (None) until the
   next Round. Trails never free a Cell during a Round, so a retry could
   not succeed. (🔵 proposal: the mechanics note says three Rewards at all
   times, which a full Arena cannot satisfy.)

The HDL must follow the same order so Step logs match. Worst case per
placement: RANDOM_DRAWS * 32 shifts plus one read per grid word.
"""

from .arena import EMPTY, REWARD_SLOT0, ArenaGrid
from .lfsr import Lfsr

RANDOM_DRAWS = 64


def find_empty_cell(grid: ArenaGrid, lfsr: Lfsr):
    g = grid.geom
    x_mask = (1 << g.x_bits) - 1
    y_mask = (1 << g.y_bits) - 1
    for _ in range(RANDOM_DRAWS):
        word = lfsr.draw()
        x = word & x_mask
        y = (word >> g.x_bits) & y_mask
        if grid.read(x, y) == EMPTY:
            return x, y
    size = g.stride_w * g.stride_h
    last = grid.address(x, y)
    for k in range(1, size + 1):
        a = (last + k) % size
        x, y = a & x_mask, a >> g.x_bits
        if grid.read(x, y) == EMPTY:
            return x, y
    return None


def place_reward(slot: int, cells: list, grid: ArenaGrid, lfsr: Lfsr) -> None:
    """Put Reward `slot` on a random empty Cell (None if the Arena is full)."""
    cell = find_empty_cell(grid, lfsr)
    cells[slot] = cell
    if cell is not None:
        grid.write(cell[0], cell[1], REWARD_SLOT0 + slot)
