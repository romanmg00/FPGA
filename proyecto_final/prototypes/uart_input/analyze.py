"""Run transport counterexamples against the existing Python rules model.

This checks the research rationale, not HDL equivalence or a selected shared model.
Run from any directory: python3 proyecto_final/prototypes/uart_input/analyze.py
"""
import json
from pathlib import Path
import sys

repo = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(repo / "prototipos" / "tron_fpga"))
from model.arena import WALL
from model.game import CRASH, PLAY, READY, Game, TickInputs
from model.params import RuleParams
from model.steering import LEFT, RIGHT, UP, latch_requests


def crash_game():
    game = Game(RuleParams(step_ticks=1, crash_ticks=2, fixed_seed=True))
    game.tick(TickInputs(start=True))
    x, y = game.bikes[0].head
    game.grid.write(x + 1, y, WALL)
    game.tick(TickInputs())
    assert game.phase == CRASH
    return game


ordered = latch_requests(RIGHT, RIGHT, [UP, LEFT])
collapsed = latch_requests(RIGHT, RIGHT, [LEFT])
assert ordered == UP and collapsed == RIGHT
timely, delayed = crash_game(), crash_game()
timely.tick(TickInputs(start=True))  # arrives while Crash: ignored
timely.tick(TickInputs())
delayed.tick(TickInputs())
delayed.tick(TickInputs())
assert timely.phase == delayed.phase == READY
timely.tick(TickInputs())
delayed.tick(TickInputs(start=True))  # old queued Start, first seen in Ready
assert timely.phase == READY and delayed.phase == PLAY

print(json.dumps({
    "model": "prototipos/tron_fpga/model (local implementation, not selected shared model)",
    "ordered_right_up_left_pending": "UP",
    "latest_only_right_up_left_pending": "RIGHT (valid UP lost)",
    "timely_crash_start_final_phase": timely.phase,
    "delayed_crash_start_final_phase": delayed.phase,
    "conclusion": "FIFO order is necessary; FIFO alone does not ensure fresh Start eligibility.",
    "wire_commands_per_second": 115200 / 10,
    "consumer_commands_per_second": 60,
    "ideal_64_entry_fill_ms": 1000 * 64 / (115200 / 10 - 60),
    "64_command_service_seconds": 64 / 60,
}, indent=2))
