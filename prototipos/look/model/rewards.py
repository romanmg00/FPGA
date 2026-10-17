"""Reward placement (hardware block G4).

A candidate Cell comes from one LFSR draw: x is the low x_bits of the word,
y the next y_bits. The candidate is accepted only if its grid word is EMPTY
(Walls, HUD area and stride padding all hold WALL), otherwise the next draw
is tried. This is rejection sampling, so no modulo circuit is needed.
"""

from .arena import EMPTY, REWARD_SLOT0, ArenaGrid
from .lfsr import Lfsr

MAX_DRAWS = 1 << 16          # model guard only; the Arena is never this full


def draw_empty_cell(grid: ArenaGrid, lfsr: Lfsr):
    g = grid.geom
    x_mask = (1 << g.x_bits) - 1
    y_mask = (1 << g.y_bits) - 1
    for _ in range(MAX_DRAWS):
        word = lfsr.draw()
        x = word & x_mask
        y = (word >> g.x_bits) & y_mask
        if grid.read(x, y) == EMPTY:
            return x, y
    return None


def place_reward(slot: int, cells: list, grid: ArenaGrid, lfsr: Lfsr) -> None:
    """Put Reward `slot` on a random empty Cell (None if none was found)."""
    cell = draw_empty_cell(grid, lfsr)
    cells[slot] = cell
    if cell is not None:
        grid.write(cell[0], cell[1], REWARD_SLOT0 + slot)
