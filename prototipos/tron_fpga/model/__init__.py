"""Headless Game Model: the Tron rules in hardware-block structure.

No graphics imports here. See CS-256 Tron Development Plan, Phases > Game Model.
"""

from .game import CRASH, MATCH_OVER, READY, RUNNING, FrameInputs, Game
from .params import ArenaGeometry, HudReserve, RuleParams

__all__ = [
    "Game", "FrameInputs", "ArenaGeometry", "HudReserve", "RuleParams",
    "READY", "RUNNING", "CRASH", "MATCH_OVER",
]
