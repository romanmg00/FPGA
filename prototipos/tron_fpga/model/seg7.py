"""Physical Scoreboard (I4, Alan): the page timer and seg7_driver.

Eight digits: P2 owns the left four (an[7:4]), P1 the right four (an[3:0]).
Both banks switch together between Points (`P2nnP1nn`) and Lives
(`L2nnL1nn`) every SCORE_VIEW_TICKS, without dark periods.

The page timer is in the game domain. It keeps running through Crash,
ready wait, Pause and Match-over, and restarts on Points when a new Match
starts. The Points, Lives and page bit cross to the fast domain, where
seg7_driver scans the digits. The scan rate is not modelled; `segments`
is the project glyph decoder (0-9, P and L), active low, so the course's
own decoder stays untouched.
"""

POINTS_VIEW, LIVES_VIEW = 0, 1

# Segment bits g f e d c b a (bit 0 = a); 1 = lit before inversion
GLYPHS = {
    "0": 0b0111111, "1": 0b0000110, "2": 0b1011011, "3": 0b1001111, "4": 0b1100110,
    "5": 0b1101101, "6": 0b1111101, "7": 0b0000111, "8": 0b1111111, "9": 0b1101111,
    "P": 0b1110011, "L": 0b0111000,
}


class PageTimer:
    def __init__(self, view_ticks: int):
        self.view_ticks = view_ticks
        self.restart()

    def restart(self) -> None:
        self.view = POINTS_VIEW
        self.timer = 0

    def clock(self) -> None:
        if self.timer == self.view_ticks - 1:
            self.timer = 0
            self.view ^= 1
        else:
            self.timer += 1


def digits(view: int, points, lives) -> str:
    """The eight characters, left (dig7) to right (dig0)."""
    label, values = ("P", points) if view == POINTS_VIEW else ("L", lives)
    return f"{label}2{values[1] % 100:02d}{label}1{values[0] % 100:02d}"


def segments(char: str) -> int:
    """seg[6:0] for one digit, active low."""
    return ~GLYPHS[char] & 0x7F
