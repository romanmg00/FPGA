"""Reward-placement LFSR in arena_ctrl: this prototype's candidate, not yet selected.

32-bit Fibonacci LFSR, shift left, XOR feedback from bits 31, 21, 1 and 0
(polynomial x^32 + x^22 + x^2 + x + 1, maximal length; XAPP052 Table 3 lists
taps 32,22,2,1 in XNOR form, this is the XOR form). The all-zero state is
illegal. The register advances only when a placement candidate is drawn:
one draw is 32 shifts, so each draw is a fresh 32-bit word. It resets to
LFSR_SEED; at each new Match, PREPARE either reloads LFSR_SEED (fixed-seed
mode) or XORs in the game-domain tick counter captured at Start.
"""

WIDTH = 32
MASK = (1 << WIDTH) - 1
TAPS = (31, 21, 1, 0)
SHIFTS_PER_DRAW = WIDTH


class Lfsr:
    def __init__(self, seed: int):
        if seed & MASK == 0:
            raise ValueError("LFSR seed must be non-zero")
        self.state = seed & MASK

    def mix(self, value: int) -> None:
        """XOR in Start-timing entropy; a result of zero keeps the old state."""
        mixed = (self.state ^ value) & MASK
        if mixed:
            self.state = mixed

    def shift(self) -> None:
        fb = 0
        for t in TAPS:
            fb ^= (self.state >> t) & 1
        self.state = ((self.state << 1) | fb) & MASK

    def draw(self) -> int:
        for _ in range(SHIFTS_PER_DRAW):
            self.shift()
        return self.state
