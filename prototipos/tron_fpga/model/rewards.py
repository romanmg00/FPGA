"""Reward placement (hardware block G4).

1. Up to RANDOM_DRAWS candidates come from LFSR draws: cx is the low 7 bits
   of the word, cy the next 6 bits. The first whose Arena word is EMPTY
   wins; the HUD band, Walls and padding hold WALL, Bikes and Trails their
   own codes. This is rejection sampling, so no modulo circuit is needed.
2. If every draw was occupied, scan the Arena in address order, starting
   after the last candidate and wrapping, and take the first EMPTY Cell.
3. If there is no EMPTY Cell at all, the slot stays absent (None) until the
   next Round, as agreed. Trails never free a Cell during a Round, so a
   retry could not succeed.

This search is the prototype's candidate, not the selected HDL schedule:
the agreement leaves the generator and placement service to be chosen, and
lets a replacement stay absent while the hardware searches. The model
places synchronously inside the Step, so it never shows that absence.
Worst case per placement: RANDOM_DRAWS * 32 shifts plus one read per word.
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
        a = (last + k) & (size - 1)
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
