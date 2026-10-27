"""step_unit and step_resolve (G1/G2, Roman): one Step as a READ2/COMMIT transaction.

PROPOSAL (review section 5.6, option D2-A), not yet agreed. A Step:

  launch (edge k)   Headings take the Pending Turns; compute both targets;
                    issue READ2.                        S_IDLE -> S_READ
  outcome (k + 2)   the captured codes feed step_resolve, a combinational
                    block; register the new heads and the outcome; issue
                    COMMIT with the writes and collected slots.
                                                        S_READ -> S_COMMIT
  done (k + 4)      the captured response shows the COMMIT finished.
                                                        S_COMMIT -> S_IDLE

Both targets are read before anything is written, so the two Bikes move at
the same time and neither has priority. A crashed Bike stays on its last
valid head Cell; the other Bike still completes its move, and any Reward it
drives into, in the same Step. While paused, a Step waiting for its codes
does not resolve; a COMMIT already issued still completes.
"""

from dataclasses import dataclass

from .arena_map import HEAD, REWARD_SLOT0, TRAIL, is_blocking, is_reward
from .turn_unit import next_cell

S_IDLE, S_READ, S_COMMIT = 0, 1, 2


@dataclass(frozen=True)
class StepOutcome:
    heads: tuple          # head Cells after the Step
    crashed: tuple        # (P1 Crashed, P2 Crashed)
    head_on: bool
    collected: tuple      # Reward slot collected by each Bike, or None
    writes: tuple         # Arena writes for COMMIT: (cx, cy, code)


def step_resolve(heads, targets, codes) -> StepOutcome:
    """Combinational: the Step's result from the heads, targets and target codes."""
    same_cell = targets[0] == targets[1]
    swap = targets[0] == heads[1] and targets[1] == heads[0]
    head_on = same_cell or swap
    crashed = tuple(head_on or is_blocking(code) for code in codes)
    new_heads, collected, writes = [], [], []
    for i in (0, 1):
        if crashed[i]:
            new_heads.append(heads[i])
            collected.append(None)
            continue
        collected.append(codes[i] - REWARD_SLOT0 if is_reward(codes[i]) else None)
        writes.append((*heads[i], TRAIL[i]))            # old head joins the Trail
        writes.append((*targets[i], HEAD[i]))
        new_heads.append(targets[i])
    return StepOutcome(tuple(new_heads), crashed, head_on, tuple(collected), tuple(writes))


class StepUnit:
    def __init__(self, starts):
        self.state = S_IDLE
        self.load(starts)

    def load(self, starts) -> None:
        """round_init: start heads; the shown Headings are the start Headings."""
        self.head = tuple((x, y) for x, y, _ in starts)
        self.shown = tuple(h for _, _, h in starts)   # Headings of the committed Step
        self.targets = self.head
        self.launched = self.shown

    def ready(self, rsp_idle: bool) -> bool:
        """Can launch at this edge: no Step open, or its COMMIT just finished."""
        return self.state == S_IDLE or (self.state == S_COMMIT and rsp_idle)

    def codes_ready(self, rsp_idle: bool, paused: bool) -> bool:
        return self.state == S_READ and rsp_idle and not paused

    # --- edges ---------------------------------------------------------------
    def launch(self, headings) -> tuple:
        """Edge k: register the targets; the caller issues READ2 with them."""
        self.launched = tuple(headings)
        self.targets = tuple(next_cell(h, d) for h, d in zip(self.head, headings))
        self.state = S_READ
        return self.targets

    def resolve(self, codes) -> StepOutcome:
        """Edge k + 2: register the outcome; the caller issues COMMIT."""
        out = step_resolve(self.head, self.targets, codes)
        self.head = out.heads
        self.shown = self.launched
        self.state = S_COMMIT
        return out

    def retire(self) -> None:
        """The COMMIT response arrived."""
        self.state = S_IDLE
