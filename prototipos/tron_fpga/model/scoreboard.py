"""Physical Scoreboard view (hardware block I4, seg7_driver).

Eight digits: P2 owns the left four (an[7:4]), P1 the right four (an[3:0]).
Both banks switch together between Points (`P2nnP1nn`) and Lives
(`L2nnL1nn`) every SCORE_VIEW_TICKS, without dark periods. The view timer
keeps running through Crash, ready wait, Pause and Match-over; a new Match
starts on Points. The fast digit scan is not modelled.
"""

POINTS_VIEW, LIVES_VIEW = 0, 1


class Scoreboard:
    def __init__(self, view_ticks: int):
        self.view_ticks = view_ticks
        self.restart()

    def restart(self) -> None:
        self.view = POINTS_VIEW
        self.timer = 0

    def tick(self) -> None:
        self.timer += 1
        if self.timer >= self.view_ticks:
            self.timer = 0
            self.view ^= 1

    def digits(self, points: list, lives: list) -> str:
        """The eight characters, left (dig7) to right (dig0)."""
        label, values = ("P", points) if self.view == POINTS_VIEW else ("L", lives)
        return f"{label}2{values[1]:02d}{label}1{values[0]:02d}"
