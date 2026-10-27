"""Points, Lives and the Match result (hardware block G5).

There is no Points cap: the full final-Step total is kept, which needs
POINTS_W bits (see params.py).
"""

DRAW = "draw"


def match_result(points: list, lives: list, goal: int):
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
        both = all(reached)
        return _higher(points) if both else reached.index(True)
    if any(out):
        both = all(out)
        return _higher(points) if both else out.index(False)
    return None


def _higher(points: list):
    if points[0] == points[1]:
        return DRAW
    return 0 if points[0] > points[1] else 1
