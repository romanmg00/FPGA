"""Run transport counterexamples against the existing Python rules model.

This checks the research rationale, not HDL equivalence or a selected shared model.
Run from any directory: python3 proyecto_final/prototypes/uart_input/analyze.py
"""
import json
from pathlib import Path
import sys

repo = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(repo / "prototipos" / "tron_fpga"))
from model.arena_map import WALL
from model.game_top import CRASH, PLAY, READY, BoardInputs, Game
from model.input_batch import InputBatch
from model.params import PHASE_NAMES, RuleParams
from model.turn_unit import RIGHT, UP, TurnUnit


def until_phase(game, phase):
    for _ in range(200):
        if game.phase == phase:
            return
        game.tick()
    raise AssertionError(f"phase {phase} not reached")


def crash_game():
    game = Game(RuleParams(crash_ticks=2, fixed_seed=True))
    game.tick(BoardInputs.keys(start=True))
    until_phase(game, PLAY)
    x, y = game.step.head[0]
    game.grid.write(x + 1, y, WALL)
    until_phase(game, CRASH)
    return game


def pending_after(data):
    capture = InputBatch()
    for byte in data:
        capture.uart_byte(byte)
    turn = TurnUnit(RIGHT)
    turn.clock(capture.publish().axes[1], apply=True, launch=False)
    return turn.pending


ordered = pending_after(b"wa")
collapsed = pending_after(b"a")
assert ordered == UP and collapsed == RIGHT
timely, delayed = crash_game(), crash_game()
timely.tick(BoardInputs.keys(start=True))  # arrives while Crash: ignored
until_phase(timely, READY)
until_phase(delayed, READY)
delayed.tick(BoardInputs.keys(start=True))  # old queued Start, first seen in Ready
until_phase(delayed, PLAY)
# Drain the input/capture pipeline to prove the earlier Start stays rejected.
for _ in range(4):
    timely.tick()
assert timely.phase == READY

print(json.dumps({
    "model": "prototipos/tron_fpga/model (local implementation, not selected shared model)",
    "ordered_right_up_left_pending": "UP",
    "latest_only_right_up_left_pending": "RIGHT (valid UP lost)",
    "timely_crash_start_final_phase": PHASE_NAMES[timely.phase],
    "delayed_crash_start_final_phase": PHASE_NAMES[delayed.phase],
    "conclusion": "FIFO order is necessary; FIFO alone does not ensure fresh Start eligibility.",
    "wire_commands_per_second": 115200 / 10,
    "consumer_commands_per_second": 60,
    "ideal_64_entry_fill_ms": 1000 * 64 / (115200 / 10 - 60),
    "64_command_service_seconds": 64 / 60,
}, indent=2))
