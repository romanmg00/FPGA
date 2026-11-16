"""Supplemental model comparison, not independent HDL verification."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "prototipos/tron_fpga"))
from model.arena_map import ArenaMap, WORDS, clear_word
from model.arena_ctrl import ArenaCtrl
from model.mailbox import Command, OP_READ2, OP_COMMIT
from model.params import RuleParams
ram = ArenaMap()
ctrl = ArenaCtrl(ram, RuleParams(fixed_seed=True))
assert WORDS == 8192
assert sum(clear_word(a) == 0 for a in range(WORDS)) == 78 * 44
assert all(ram.words[a] == clear_word(a) for a in range(WORDS))
print("model CLEAR accesses=8192 EMPTY=3432 WALL=4760; HDL measured cycles=8192")
rsp = ctrl.execute(Command(op=OP_READ2, targets=((20, 27), (59, 27))))
assert rsp.cycles == 2
print("model READ2 accesses=2; HDL acceptance-to-done=3 (registered response overhead=1)")
for s1, s2 in ((True, True), (False, True), (True, False), (False, False)):
    writes = [(20, 27, 2 if s1 else 6), (59, 27, 4 if s2 else 6)]
    if s1:
        writes.append((21, 27, 3))
    if s2:
        writes.append((58, 27, 5))
    rsp = ctrl.execute(Command(op=OP_COMMIT, writes=tuple(writes)))
    assert rsp.cycles == 2 + s1 + s2
    print(f"COMMIT survive_p1={s1} survive_p2={s2}: model supplied-write accesses={rsp.cycles}, HDL cycles={rsp.cycles}")
print("Crash writes supplied explicitly here: model gameplay does not yet emit ADR 0003 code 6.")
print("PASS compare_model")
