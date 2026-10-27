"""Step controller (hardware block G1/G2): read, check, then write.

Both Bikes' target Cells are read and checked before either is written, so
the two Bikes move at the same time and neither has priority. A Bike that
Crashes stays on its last valid head Cell; the other Bike still completes
its move (and any Reward it drives into) in the same Step.
"""

from dataclasses import dataclass

from .arena import HEAD, REWARD_SLOT0, TRAIL, ArenaGrid, is_blocking, is_reward
from .steering import next_cell


@dataclass
class Bike:
    head: tuple
    heading: int
    pending: int          # Heading to apply at the next Step


@dataclass(frozen=True)
class StepResult:
    crashed: tuple        # (P1 Crashed, P2 Crashed)
    head_on: bool
    collected: tuple      # Reward slot collected by each Bike, or None


def run_step(bikes: list, grid: ArenaGrid) -> StepResult:
    for b in bikes:
        b.heading = b.pending
    nxt = [next_cell(b.head, b.heading) for b in bikes]
    seen = [grid.read(*c) for c in nxt]

    same_cell = nxt[0] == nxt[1]
    swap = nxt[0] == bikes[1].head and nxt[1] == bikes[0].head
    head_on = same_cell or swap
    crashed = tuple(head_on or is_blocking(code) for code in seen)

    collected = []
    for i, b in enumerate(bikes):
        if crashed[i]:
            collected.append(None)
            continue
        collected.append(seen[i] - REWARD_SLOT0 if is_reward(seen[i]) else None)
        grid.write(b.head[0], b.head[1], TRAIL[i])     # old head joins the Trail
        grid.write(nxt[i][0], nxt[i][1], HEAD[i])
        b.head = nxt[i]
    return StepResult(crashed, head_on, tuple(collected))
