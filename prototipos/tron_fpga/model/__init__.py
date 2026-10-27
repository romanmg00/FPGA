"""Headless Game Model: the agreed Tron rules in hardware-block structure.

No graphics imports here. See CS-256 Tron Development Plan, Phases > Game Model.
"""

from .game import CRASH, IDLE, MATCH_OVER, PLAY, READY, Game, TickInputs
from .params import GEOMETRY, ArenaGeometry, RuleParams
from .scoring import DRAW

__all__ = [
    "Game", "TickInputs", "ArenaGeometry", "GEOMETRY", "RuleParams",
    "IDLE", "PLAY", "CRASH", "READY", "MATCH_OVER", "DRAW",
]
