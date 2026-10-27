"""score_unit (G5, Alan): Points, Lives and the Match result.

At a Step's outcome edge it adds each collected Reward's value and the
Survival Bonus, takes a Life from each crashed Bike, then evaluates victory
on the new totals, all in the same edge as the new heads. There is no
Points cap: the full final-Step total is kept, which needs POINTS_W bits.
"""

from .params import LIVES_W, POINTS_W

DRAW = "draw"


def match_result(points, lives, goal: int):
    """Evaluate victory after a Step's Crashes, Rewards and Survival Bonus.

    Returns None while the Match goes on, else 0 (P1 wins), 1 (P2 wins) or
    DRAW. Reaching or exceeding the Points Goal comes first; otherwise
    losing the final Life loses. When both reach the goal, or both lose
    their final Life, in the same Step, higher final Points wins and equal
    Points is a Draw.
    """
    reached = [p >= goal for p in points]
    out = [n == 0 for n in lives]
    if any(reached):
        return _higher(points) if all(reached) else reached.index(True)
    if any(out):
        return _higher(points) if all(out) else out.index(False)
    return None


def _higher(points):
    if points[0] == points[1]:
        return DRAW
    return 0 if points[0] > points[1] else 1


class ScoreUnit:
    def __init__(self, rules):
        self.rules = rules
        self.new_match()

    def new_match(self) -> None:
        self.points = [0, 0]
        self.lives = [self.rules.lives] * 2
        self.result = None

    def clock_outcome(self, out, goal: int) -> None:
        values, bonus = self.rules.reward_values, self.rules.survival_bonus
        points, lives = list(self.points), list(self.lives)
        for i in (0, 1):
            if out.collected[i] is not None:
                points[i] += values[out.collected[i]]
            if out.crashed[i]:
                lives[i] -= 1
            elif out.crashed[1 - i]:
                points[i] += bonus
        assert all(0 <= p < 1 << POINTS_W for p in points) and all(0 <= n < 1 << LIVES_W for n in lives)
        self.points, self.lives = points, lives
        self.result = match_result(points, lives, goal)
