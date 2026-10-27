"""M2 scenario set: replay each scenario file and compare with its expected Step log.

A difference means the model's behavior changed. If the change is intended,
rebuild with `python -m scenarios.build`, review the log diff and commit
both. Each scenario is also checked for the case it was written to cover,
so a rebuild cannot silently lose it.
"""

import importlib.util
import unittest
from pathlib import Path

from model import Game
from model.scenario import parse, run
from model.steplog import parse_line

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ROOT / "scenarios"
DIFF = ROOT.parents[1] / "tools" / "steplog_diff.py"


def load(name):
    text = (SCENARIOS / f"{name}.txt").read_text(encoding="utf-8")
    expected = (SCENARIOS / f"{name}.log").read_text(encoding="utf-8").splitlines()
    return run(parse(text)), expected


def crashes(lines):
    return [parse_line(l) for l in lines if parse_line(l)["crash"] != "00"]


class ScenarioReplayTests(unittest.TestCase):
    def test_every_scenario_reproduces_its_expected_log(self):
        names = sorted(p.stem for p in SCENARIOS.glob("*.txt"))
        self.assertEqual(len(names), 12)
        for name in names:
            with self.subTest(name):
                log, expected = load(name)
                self.assertEqual(log, expected)

    def test_scenarios_cover_their_cases(self):
        log, _ = load("01-walls")
        cells = [(c["p1"], c["p2"], c["crash"]) for c in crashes(log)]
        self.assertEqual([c[2] for c in cells], ["10", "10", "01", "10"])
        self.assertEqual([c[0 if c[2] == "10" else 1].rsplit(",", 1)[0] for c in cells],
                         ["20,5", "20,48", "78,26", "1,26"])         # top, bottom, right, left
        self.assertEqual(parse_line(log[-1])["result"], "P2")

        for name, crash in (("02-own-trail", "10"), ("03-other-trail", "10"),
                            ("04-head-on-same-cell", "11"), ("05-head-on-swap", "11")):
            log, _ = load(name)
            self.assertEqual(crashes(log)[0]["crash"], crash, name)
        same = crashes(load("04-head-on-same-cell")[0])[0]
        self.assertEqual((same["p1"], same["p2"]), ("38,27,R", "40,27,L"))   # both target 39,27

        log, _ = load("07-two-inputs")
        heads = [parse_line(l)["p1"] for l in log[1:5]]
        self.assertEqual(heads, ["20,28,D", "20,29,D", "21,29,R", "21,28,U"])

        log, _ = load("10-both-last-life")
        self.assertEqual((parse_line(log[-1])["lives"], parse_line(log[-1])["result"]),
                         ("0,0", "draw"))
        log, _ = load("11-new-match")
        fresh = [parse_line(l) for l in log if parse_line(l)["goal"] == "30"]
        self.assertEqual((fresh[0]["round"], fresh[0]["points"], fresh[0]["lives"]),
                         ("1", "0,0", "3,3"))

    def test_reward_scenarios_cover_their_cases(self):
        sc = parse((SCENARIOS / "08-reward-respawn.txt").read_text(encoding="utf-8"))
        game = Game(sc.rules())
        run(sc, game)
        respawns = game.ctrl.placements[3:]                         # after PREPARE's three
        self.assertTrue(respawns)
        self.assertTrue(any({2, 3, 4, 5} & set(p.rejected) for _, p in respawns),
                        "no respawn rejected a Trail or head Cell")
        log, _ = load("09-goal")
        ends = [parse_line(l) for l in log if parse_line(l)["result"] != "-"]
        first = ends[0]
        points = [int(p) for p in first["points"].split(",")]
        self.assertGreaterEqual(min(points), int(first["goal"]))   # simultaneous finish
        last = ends[-1]
        self.assertEqual(last["goal"], "20")
        self.assertGreater(max(int(p) for p in last["points"].split(",")), 20)


class StepLogDiffTests(unittest.TestCase):
    def test_diff_reports_the_first_differing_field(self):
        spec = importlib.util.spec_from_file_location("steplog_diff", DIFF)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        log, _ = load("05-head-on-swap")
        self.assertIsNone(mod.compare(log, list(log)))
        bad = list(log)
        bad[7] = bad[7].replace("lives=3,3", "lives=3,2")
        self.assertEqual(mod.compare(log, bad), (8, {"lives": ("3,3", "3,2")}))
        self.assertEqual(mod.compare(log, log[:-1])[1], {"<lines>": (len(log), len(log) - 1)})
        self.assertIsNone(mod.compare(log, [l.replace("tick=", "tick=9") for l in log],
                                      ignore=("tick",)))


if __name__ == "__main__":
    unittest.main()
