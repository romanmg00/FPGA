"""Turn latch (hardware block G1, one per Bike).

Headings are 2-bit codes in clockwise order, so a Turn is a difference of
±1 (mod 4) and a 180° reversal is a difference of 2.
"""

UP, RIGHT, DOWN, LEFT = 0, 1, 2, 3
HEADING_NAMES = ("UP", "RIGHT", "DOWN", "LEFT")
DELTA = {UP: (0, -1), RIGHT: (1, 0), DOWN: (0, 1), LEFT: (-1, 0)}


def is_turn(heading: int, request: int) -> bool:
    """A 90° change. Same Heading and 180° reversals are not Turns."""
    return (request - heading) % 4 in (1, 3)


def latch_turn(pending: int, heading: int, request: int) -> int:
    """Keep the last valid Turn requested since the previous Step.

    Validity is judged against the Heading the Bike has now, so pressing
    up then left while heading right keeps up (left is a reversal).
    """
    return request if is_turn(heading, request) else pending


def next_cell(cell: tuple, heading: int) -> tuple:
    dx, dy = DELTA[heading]
    return cell[0] + dx, cell[1] + dy
