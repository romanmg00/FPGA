"""Turn latch (hardware block G1, one per Bike).

Headings are 2-bit codes in clockwise order (game_pkg DIR_*), so a Turn is
a difference of ±1 (mod 4) and a 180° reversal is a difference of 2.
"""

from .params import CX_W, CY_W

UP, RIGHT, DOWN, LEFT = 0, 1, 2, 3
HEADING_NAMES = ("UP", "RIGHT", "DOWN", "LEFT")
DELTA = {UP: (0, -1), RIGHT: (1, 0), DOWN: (0, 1), LEFT: (-1, 0)}
TIE_PRIORITY = (UP, RIGHT, DOWN, LEFT)   # for valid requests in one board sample


def is_turn(heading: int, request: int) -> bool:
    """A 90° change. Same Heading and 180° reversals are not Turns."""
    return (request - heading) % 4 in (1, 3)


def latch_turn(pending: int, heading: int, request: int) -> int:
    """Keep the last valid Turn requested since the previous Step.

    Validity is judged against the Heading the Bike has now, so pressing
    up then left while heading right keeps up (left is a reversal), and an
    invalid request never cancels a valid Pending Turn.
    """
    return request if is_turn(heading, request) else pending


def latch_requests(pending: int, heading: int, requests) -> int:
    """Apply one tick's requests in arrival order.

    Each item is a Heading, or a set of Headings pressed in the same board
    sample. Within a set, the valid request first in UP > RIGHT > DOWN > LEFT
    wins, so the set is applied lowest priority first.
    """
    for r in requests:
        if isinstance(r, (set, frozenset)):
            for t in reversed(TIE_PRIORITY):
                if t in r:
                    pending = latch_turn(pending, heading, t)
        else:
            pending = latch_turn(pending, heading, r)
    return pending


def next_cell(cell: tuple, heading: int) -> tuple:
    """Unsigned, as in the HDL: cx 0 minus 1 is 127 (padding, which holds WALL)."""
    dx, dy = DELTA[heading]
    return (cell[0] + dx) & ((1 << CX_W) - 1), (cell[1] + dy) & ((1 << CY_W) - 1)
