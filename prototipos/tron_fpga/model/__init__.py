"""Headless Game Model: the agreed Tron rules in the planned HDL block structure.

One module per planned HDL block (see docs/design/CS-256 Tron Game Model
Hardware Map.md). No graphics imports here.
"""

from .game_top import CRASH, IDLE, MATCH_OVER, PLAY, PREP, READY, BoardInputs, Game
from .params import GEOMETRY, PHASE_NAMES, ArenaGeometry, RuleParams
from .score_unit import DRAW

__all__ = [
    "Game", "BoardInputs", "ArenaGeometry", "GEOMETRY", "RuleParams", "PHASE_NAMES",
    "IDLE", "PREP", "PLAY", "CRASH", "READY", "MATCH_OVER", "DRAW",
]
