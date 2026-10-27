"""arena_ctrl (A2, with G4 placement): the fast Arena controller.

It is the only writer of arena_map (port A). It executes the game's
commands and returns facts; it makes no rule decisions. PROPOSAL (review
section 5.6, option D2-A), not yet agreed:

- PREPARE: clear all 8192 words, write both start heads, reseed the LFSR
  for a new Match, then place Reward slots 0, 1 and 2.
- READ2: read the two target Cells of a Step and return their codes.
- COMMIT: write the Step's head and Trail codes, then replace each
  collected Reward in ascending slot order.

Reward slot positions live here (`slots`), in the fast domain, because only
the controller knows where a placement landed. drawcon does not need them:
a Reward is one Cell, so it finds Rewards in the Arena word it reads.

The model runs each command at once and counts the fast cycles it would
take (one per Arena read or write, 32 per LFSR draw). A command that would
not finish within SERVICE_WINDOW sets `overrun`.
"""

from .arena_map import HEAD, REWARD_SLOT0, WORDS, ArenaMap
from .lfsr import Lfsr
from .mailbox import OP_COMMIT, OP_PREPARE, OP_READ2, Command, Response
from .reward_place import find_empty_cell
from .params import SERVICE_WINDOW, RuleParams


class ArenaCtrl:
    def __init__(self, ram: ArenaMap, rules: RuleParams):
        self.ram = ram
        self.rules = rules
        self.reset()

    def reset(self) -> None:
        """CPU_RESETN (held long enough to finish): Walls only, no Rewards."""
        self.lfsr = Lfsr(self.rules.seed)
        self.slots = [None, None, None]
        self.placements = []          # every placement since reset, for tests and logs
        self.max_cycles = 0
        self.overrun = False
        self.ram.clear()

    def execute(self, cmd: Command) -> Response:
        if cmd.op == OP_PREPARE:
            cycles = self._prepare(cmd)
        elif cmd.op == OP_READ2:
            codes = tuple(self.ram.read(*c) for c in cmd.targets)
            return self._respond(cmd, 2, codes)
        elif cmd.op == OP_COMMIT:
            cycles = self._commit(cmd)
        else:
            raise ValueError(f"unknown op {cmd.op}")
        return self._respond(cmd, cycles)

    def _respond(self, cmd, cycles, codes=(0, 0)) -> Response:
        self.max_cycles = max(self.max_cycles, cycles)
        self.overrun |= cycles > SERVICE_WINDOW
        return Response(seq=cmd.seq, codes=codes, slots=tuple(self.slots), cycles=cycles)

    def _prepare(self, cmd: Command) -> int:
        self.ram.clear()
        for i, cell in enumerate(cmd.heads):
            self.ram.write(*cell, HEAD[i])
        if cmd.new_match:
            if self.rules.fixed_seed:
                self.lfsr = Lfsr(self.rules.seed)
            else:
                self.lfsr.mix(cmd.seed_mix)
        self.slots = [None, None, None]
        cycles = WORDS + len(cmd.heads)
        for slot in range(3):
            cycles += self._place(slot)
        return cycles

    def _commit(self, cmd: Command) -> int:
        for x, y, code in cmd.writes:
            self.ram.write(x, y, code)
        cycles = len(cmd.writes)
        for slot in sorted(cmd.collected):
            self.slots[slot] = None    # its Cell now holds the collecting Bike's head
            cycles += self._place(slot)
        return cycles

    def _place(self, slot: int) -> int:
        p = find_empty_cell(self.ram, self.lfsr)
        self.placements.append((slot, p))
        self.slots[slot] = p.cell
        if p.cell is not None:
            self.ram.write(*p.cell, REWARD_SLOT0 + slot)
        return p.cycles + 1
