"""Run with python3 from prototipos/tron_fpga; writes only beside this script."""
from pathlib import Path
import random
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path.cwd()))
from types import SimpleNamespace
from model.params import RuleParams, GOALS, POINTS_W, LIVES_W
from model.score_unit import ScoreUnit, match_result, DRAW

rng = random.Random(0x2562026)
outfile = Path(__file__).with_name('model_vectors.txt')
encode = {None: 0, 0: 1, 1: 2, DRAW: 3}
rows = []
counts = [0] * 4
for match in range(2000):
    sel = match % 4
    goal = GOALS[sel]
    score = ScoreUnit(RuleParams())
    # new, strobe, switches, crash1, crash2, valid1, slot1, valid2, slot2,
    # points1, points2, lives1, lives2, goal, result
    rows.append([1, 0, sel, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, goal, 0])
    for step in range(1000):
        crash = [rng.random() < .1 for _ in range(2)]
        collected = [rng.randrange(3) if not crash[i] and rng.random() < .6 else None for i in range(2)]
        # One physical slot cannot be collected by both Bikes in one Step.
        if collected[0] is not None and collected[0] == collected[1]:
            collected[1] = None
        strobe = int(rng.random() < .85)
        if strobe:
            score.clock_outcome(SimpleNamespace(crashed=crash, collected=collected), goal)
        assert score.result == match_result(score.points, score.lives, goal)
        assert POINTS_W == 6 and LIVES_W == 2
        rows.append([0, strobe, rng.randrange(4), *map(int, crash),
                     int(collected[0] is not None), collected[0] or 0,
                     int(collected[1] is not None), collected[1] or 0,
                     *score.points, *score.lives, goal, encode[score.result]])
        if score.result is not None:
            counts[encode[score.result]] += 1
            break
    else:
        raise AssertionError('Match did not finish')
outfile.write_text(''.join(' '.join(map(str, row)) + '\n' for row in rows))
print(f'{len(rows)} vectors, 2000 Matches, seed 0x2562026, terminal counts {counts}')
