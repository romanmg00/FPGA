"""turn_unit (G1, Roman): the Heading and the one Pending Turn of a Bike.

Headings are 2-bit codes in clockwise order (game_pkg DIR_*), so a Turn is
a difference of +-1 (mod 4) and a 180 degree reversal a difference of 2.

Each running tick, the Player's input batch is applied first: an event on
the axis across the current Heading replaces the Pending Turn; an event on
the Heading's own axis (same Heading or reversal) is ignored and does not
cancel it. On a launch tick the Heading then takes the Pending Turn. The
Heading changes only at launch, so every later batch is judged against the
Heading the Bike will actually move in (review F3).
"""

from .params import CX_W, CY_W, DIR_DOWN, DIR_LEFT, DIR_RIGHT, DIR_UP

UP, RIGHT, DOWN, LEFT = DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT
HEADING_NAMES = ("UP", "RIGHT", "DOWN", "LEFT")
HEADING_LETTERS = "URDL"
DELTA = {UP: (0, -1), RIGHT: (1, 0), DOWN: (0, 1), LEFT: (-1, 0)}


def is_vertical(heading: int) -> bool:
    return heading in (UP, DOWN)


def is_turn(heading: int, request: int) -> bool:
    """A 90 degree change. Same Heading and 180 degree reversals are not Turns."""
    return (request - heading) % 4 in (1, 3)


def next_cell(cell: tuple, heading: int) -> tuple:
    """Unsigned, as in the HDL: cx 0 minus 1 is 127 (padding, which holds WALL)."""
    dx, dy = DELTA[heading]
    return (cell[0] + dx) & ((1 << CX_W) - 1), (cell[1] + dy) & ((1 << CY_W) - 1)


class TurnUnit:
    def __init__(self, heading: int = RIGHT):
        self.load(heading)

    def load(self, heading: int) -> None:
        """round_init: the start Heading, no Pending Turn."""
        self.heading = self.pending = heading

    def clock(self, axes, apply: bool, launch: bool) -> None:
        """One tick edge. `axes` is the batch's (V, H) for this Player."""
        pending = self.pending
        if apply:
            v, h = axes
            crossing = h if is_vertical(self.heading) else v
            if crossing is not None:
                pending = crossing
        self.pending = pending
        if launch:
            self.heading = pending
