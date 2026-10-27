"""Points and Lives (hardware block G5)."""


def add_points(points: int, value: int, cap: int) -> int:
    """Points stop at the cap (🔵 99), matching the 2-digit Scoreboard."""
    return min(points + value, cap)
