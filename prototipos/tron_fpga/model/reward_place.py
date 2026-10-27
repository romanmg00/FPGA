"""Reward placement search (G4), run by arena_ctrl in the fast domain.

1. Up to RANDOM_DRAWS candidates come from LFSR draws: cx is the low 7 bits
   of the word, cy the next 6 bits. The first whose Arena word is EMPTY
   wins; the HUD band, Walls and padding hold WALL, Bikes and Trails their
   own codes. This is rejection sampling, so no modulo circuit is needed.
2. If every draw was occupied, scan the Arena in address order, starting
   after the last candidate and wrapping, and take the first EMPTY Cell.
3. If there is no EMPTY Cell at all, the slot stays absent (None) until the
   next Round, as agreed. Trails never free a Cell during a Round, so a
   retry could not succeed.

The search reads the Arena as it is when the command runs, and arena_ctrl
runs one command at a time, so the occupancy check never goes stale: no
other write can land between the check and the Reward write.

PROPOSAL (review E1): this generator and schedule are the prototype's
candidate, not the selected HDL design. Cost per placement, at one cycle
per read: up to RANDOM_DRAWS * (32 shifts + 1 read), plus 8192 reads.
"""

from dataclasses import dataclass

from .arena_map import EMPTY, WORDS, ArenaMap, address, cell_of
from .lfsr import SHIFTS_PER_DRAW, Lfsr
from .params import CX_W, CY_W, RANDOM_DRAWS


@dataclass(frozen=True)
class Placement:
    cell: object            # (cx, cy), or None when the Arena has no EMPTY Cell
    draws: int              # LFSR candidates read
    rejected: tuple         # Arena codes of the rejected candidates, in order
    scanned: int            # words read by the fallback scan
    cycles: int             # estimated fast-domain cycles


def find_empty_cell(ram: ArenaMap, lfsr: Lfsr) -> Placement:
    x_mask, y_mask = (1 << CX_W) - 1, (1 << CY_W) - 1
    rejected = []
    for n in range(1, RANDOM_DRAWS + 1):
        word = lfsr.draw()
        x, y = word & x_mask, (word >> CX_W) & y_mask
        code = ram.read(x, y)
        if code == EMPTY:
            return Placement((x, y), n, tuple(rejected), 0, n * (SHIFTS_PER_DRAW + 1))
        rejected.append(code)
    last = address(x, y)
    cycles = RANDOM_DRAWS * (SHIFTS_PER_DRAW + 1)
    for k in range(1, WORDS + 1):
        a = (last + k) & (WORDS - 1)
        if ram.words[a] == EMPTY:
            return Placement(cell_of(a), RANDOM_DRAWS, tuple(rejected), k, cycles + k)
    return Placement(None, RANDOM_DRAWS, tuple(rejected), WORDS, cycles + WORDS)
