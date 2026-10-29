# G5 Points, Lives and Match result: provisional feasibility evidence

## 1. Built and governing interfaces

Owner: **Alan (G5)**; official independent bench owner remains Roman (§7).
These are builder checks, not the official contract benches or team acceptance.
All writes for this experiment are under `score/`; shared files and Git were
not edited. Target: Nexys A7-100T, `xc7a100tcsg324-1`.

`score_unit.sv` implements the locked Agreed Specification's scoring and victory
order and contract §0/§4 steps 4–5. Its constants import `game_pkg::*` (§5), and
its arithmetic follows `model/score_unit.py` and `model/params.py` in
`prototipos/tron_fpga/`. It builds against ADR 0002's approximately 60 Hz game
clock and ADR 0003's **proposed** game-domain outcome edge after READ2 resolution,
with Points, Lives and result registered on that same edge. It has no Arena
service or mailbox dependency. ADR 0003's crossing remains fully open; ADR 0005
is a proposed experiment workflow, not approval of these interfaces.

**Every port, width, encoding and timing below is provisional:**

| Port | Meaning |
|---|---|
| `clk`, `rst` | Game clock; synchronous active-high reset |
| `new_match` | Load 0 Points, 3 Lives, capture goal; priority over outcome |
| `goal_sel[1:0]` | Already-synchronized `{SW15, SW14}`; 00/01/10/11 → 10/20/30/40 |
| `step_outcome` | One game-domain update strobe per resolved Step |
| `crashed_p1`, `crashed_p2` | That Step's simultaneous Crashes |
| `collected_valid_p1`, `collected_valid_p2` | That Step collected a Reward |
| `collected_slot_p1[1:0]`, `collected_slot_p2[1:0]` | Slot 0/1/2 → +1/+1/+3 |
| `points_p1[5:0]`, `points_p2[5:0]` | Retained full totals; no clamp |
| `lives_p1[1:0]`, `lives_p2[1:0]` | Retained Lives |
| `points_goal[5:0]` | Latched Match goal |
| `result[1:0]` | 0 none, 1 P1, 2 P2, 3 Draw |

Local semantics beyond the pending contract: reset exposes 0 Points/0 Lives,
goal 10, result none; new Match starts play values. Caller must suppress outcome
strobes before the first Match, during Pause/preparation/Crash waits, and must
never replay an outcome. No separate Round reset exists: Round waits preserve
Points/Lives/goal. Terminal result and totals hold until new Match/reset, even
if another outcome strobe arrives. This terminal guard is a defensive addition
to the model method, whose caller already stops outcomes when a Match ends.
No internal CDC: upstream synchronizes switches and delivers coherent outcome
fields; downstream supplies display/render CDC. These remain integration work.

6-bit Points are sufficient because legal play has totals below goal before
the final Step: max = 39 + 3 Reward + 3 Survival Bonus = **45**. Five bits would
wrap; six hold 0–63. Lives 0–3 require two bits. Widths are local because the
shared package does not yet define POINTS_W/LIVES_W; no package edit was made.

Invalid slot 3 is ignored, an explicitly provisional defensive behavior.
Crash plus collection is impossible from a legal resolver, but, if supplied,
HDL adds the Reward like the Python score method. Invalid inputs are not
validated here, and arbitrary repeated illegal inputs have no width guarantee.

## 2. Source state and tools

Repository read-only HEAD: `03a4b019b5f50fdb2b58b42231a86e69b65e544d`.
These new files were uncommitted at verification. SHA-256 for **every `.sv` and
script**, vectors, shared package/runners and the two model dependencies is in
[evidence/source-sha256.txt](evidence/source-sha256.txt). This pins source state
rather than assuming HEAD contains the experiment. No IP was generated.

Vivado/XSim **2025.2**, SW Build 6299465; container tool path
`/tools/2025.2/Vivado`. Tool banners are retained in the text logs. Host run
names use 29 October; container logs show 28 October UTC (different timezones).

## 3. Reproduction commands and measured results

From repository root, generate vectors (Python standard library only):

```bash
(cd prototipos/tron_fpga && python3 -B ../../proyecto_final/prototypes/core_blocks/score/generate_vectors.py)
```

Expected: `37658 vectors, 2000 Matches, seed 0x2562026, terminal counts [0, 1096, 896, 8]`.
The script sets `sys.dont_write_bytecode` and writes vectors beside itself.
Rows contain new-Match, strobe, switch selector, Crashes, collection-valid/slot
pairs, expected Points/Lives/goal/result. It invokes `ScoreUnit.clock_outcome`
and verifies `match_result` agreement. Switches vary mid-Match; idle cycles
exercise the strobe. Legal random outcomes exclude collection by crashed Bikes
and exclude both Players taking the same Reward slot. Random Crash events stand
for successive Rounds; the score block has no Round FSM or timers.

Run the shared runners with sandbox escalation (they invoke
`sudo -n /usr/local/sbin/cs256-vivado`):

```bash
proyecto_final/prototypes/core_blocks/run_xsim.sh score_directed_tb prototypes/core_blocks/score/score_unit.sv prototypes/core_blocks/score/score_directed_tb.sv
proyecto_final/prototypes/core_blocks/run_xsim.sh score_model_tb prototypes/core_blocks/score/score_unit.sv prototypes/core_blocks/score/score_model_tb.sv
proyecto_final/prototypes/core_blocks/run_synth.sh -c clk 11.982 score_unit prototypes/core_blocks/score/score_unit.sv
```

| Run | Result | Host artifact directory beneath `/home/alan/.local/share/cs256-vivado/builds/` |
|---|---|---|
| Directed | **PASS score_directed_tb**, 40 checks | `core-score_directed_tb-20261029-000610-607935` |
| Model | **PASS score_model_tb**, 37,658 rows, **zero mismatches** | `core-score_model_tb-20261029-000609-607765` |
| OOC synthesis | Success, zero latches | `core-synth-score_unit-20261029-000549-606140` |

Retained logs: [directed](evidence/directed-sim.log),
[model](evidence/model-sim.log), [utilization](evidence/synth-utilization.txt),
[timing](evidence/synth-timing.txt), [warnings](evidence/synth-summary.log),
[latches](evidence/synth-latches.txt), [RAM](evidence/synth-ram.txt).

At `-c clk 11.982`: **47 Slice LUTs, 22 Slice Registers, 0 F7 Muxes,
0 Block RAM tiles, 0 DSPs, 0 inferred latches, 0 distributed RAM**.
**WNS +6.863 ns, WHS +0.266 ns, WPWS +5.491 ns**, TNS/THS/TPWS 0;
zero failing setup/hold/pulse-width endpoints. These are post-synthesis OOC
estimates, not routed sign-off. Inputs/outputs have no external timing delays;
`HD.CLK_SRC` is absent, so clock skew/delay cannot be estimated. The warning is
retained, along with benign no-latches/no-RAM-query warnings. XSim reports the
container's `LIBRARY_PATH` environment warning; both runs finish successfully.

Initial commands used the same runner arguments but benches declared a
`timescale` while package/DUT did not. Both failed elaboration with XSIM
43-4099. Resolved locally by removing bench-only timescale declarations, with
no shared edit; XSim reports 1 ps resolution and displayed ns times. Failed
artifacts: `core-score_directed_tb-20261029-000550-606500` and
`core-score_model_tb-20261029-000549-606288`, with elaboration logs retained as
`evidence/initial-*-xelab.out`. No model/specification mismatch occurred.

The first vector-generation invocation also failed because the script path is
outside Python's import root even when launched from the prototype directory.
The script now explicitly adds its required working directory to `sys.path`;
the command above completed and regenerated identical vectors. These were
setup failures, not scoring mismatches.

## 4. What this evidence establishes

Independent directed checks cover no-Crash/no-Bonus; Bonus only to the sole
survivor, with a simultaneous Reward; Head-on with no Bonus; exact/exceeded
goal; both reaching goal with P1 higher, P2 higher, and equal totals; either
Player losing the final Life; both losing the final Life with unequal/equal
Points; goal reached when the other loses the final Life; all goal encodings
and mid-Match switch immunity; Points/Lives retained through Round waits;
maximum legal 45; terminal retention; and reset/new-Match/outcome priorities.
One labelled adversarial Crash-plus-collection case separately checks the
model's goal-before-Life precedence. A legal crashed Bike cannot collect a
Reward to newly reach the goal, so that case is not movement feasibility proof.

Random replay confirms this block agrees with the selected Python score model
for 2,000 generated Matches. That comparison is supplemental, not independent
proof of rules. Arithmetic is small and has positive synthesized internal
setup margin even at the fast-clock experiment's period; ADR 0002 still places
this block in the slow domain.

## 5. Limitations, risks and open questions

- Not routed, no actual clock divider/Wizard, physical timing, board test,
  CDC, reset-in-flight, renderer, mailbox, collision resolver, or integrated
  Match/Round/Pause controller evidence. No claim of whole-game sign-off.
- No complete M2 movement Step-log replay: this isolated block takes already
  resolved outcomes and has neither heads nor the Arena. The dedicated
  score-model vectors are its comparison artifact; integrated M2 logs remain
  work for composed G1/G2/G3/G5 verification.
- Roman must independently write the official bench after the interface is
  reconciled. Builder tests do not satisfy contract §7 completion.
- Roman/Alan: settle these ports, widths, result encoding, reset outputs,
  terminal hold and priority in the contract before dependent production code
  adopts them; ensure strobe gating and exactly-once consumption at integration.
- Roman/Alan: select upstream switch synchronization and downstream display
  crossing; the open mailbox/render boundary is not addressed here.
- Suggested future shared-package addition after agreement: POINTS_W=6,
  LIVES_W=2 and result constants. No shared file change is required to rerun
  this evidence. No rule change or working-default replacement is requested.


## Change, 29 October 2026 (orchestrator)

Reset now loads Lives 3 instead of 0, so the idle Scoreboard and HUD show
Lives 03 like the model's idle view (Hardware Map, "Scoreboard while idle").
No Step result changes: a new Match loads 3 Lives anyway. Both score benches
were rerun with `core_blocks/run_all.sh` after the change.
