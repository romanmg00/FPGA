# Step datapath across two clocks — provisional evidence, 29 October 2026

## 1. Built, authority, interfaces and deviations

This experiment composes Roman's G1/G2 (`turn_unit` twice, `next_cell` twice,
`step_resolve`) with Alan's G5 (`score_unit`) and fast A1/A2 (`arena_ctrl`,
including `arena_map`). Read the root instructions, core workflow, tron-hdl
skill, documentation authority path, contract conventions/interfaces/integration,
ADR 0002 (accepted), ADR 0003 and 0005 (proposed), Hardware Map and Coding
Practices. Contract ownership is unchanged. These are builder checks, **not**
the official other-owner §7 benches. No shared interface is selected here.

`step_core.sv` is synthesizable game-domain logic: IDLE → READ → COMMIT → IDLE.
All its ports are provisional. `clk` means `clk_juego`; cells are `{cy,cx}`;
axes bits `[3:0]` mean `v_valid,v_down,h_valid,h_left`. A launch takes the
Pending Turn after this edge's input batch, stores the resulting targets and
attempted Headings, toggles `cmd_tag` and issues READ2 (`cmd_op=2`). A response
bus is captured on every game edge; the FSM consumes the previous capture.
READ resolves only when the captured tag answers the outstanding command and
Pause is false. That edge registers heads/display Headings/crash flags, applies
scoring, and toggles the tag to issue COMMIT (`cmd_op=3`). COMMIT payload keeps
old heads, targets and survival flags. Its response retires the Step, including
while paused. A launch may share retirement. One command outstanding, no FIFO.
`ready` is an admission condition: caller must not launch when false. Reset
synchronously clears the core; load resets round heads/Headings, without score
reset. `new_match` independently resets score and captures the goal selector.

`datapath_tb.sv` supplies separate continuous clocks: fast period 10 simulation
ns; game period N×10 ns, phase offset PHASE ns. N=10000 leaves enough time for
8192-cycle CLEAR plus initial-head and oracle writes within one game interval.
The free-running game tick counter resets on reset; log ticks come from that
counter, never from the expected row's tick. Every trace row drives the next
edge; setup/preparation does not stop either clock.

**SIMULATION ONLY, NOT CDC-SAFE HARDWARE:** the procedural bridge waits FORWARD
fast positive edges, issues the local controller request once, waits for done,
then waits BACKWARD fast positive edges and publishes its response tag. Coherent
buses are taken on trust. There are no synchronizers, metastability model,
acknowledgement protocol, physical constraints or validated reset epochs.
Delays are counts of fast edges, not a proposed crossing implementation.

The controller exposes no arbitrary Reward writer. The bench oracle uses its
normal COMMIT sequencing/addresses/write strobes, with both crashed addresses
set to the selected Cell and **forces only `arena.a_wdata`** to the Reward code
for those two writes. It then releases that data override. This simulation-only
adapter preserves the unchanged A1/A2 sources and sole controller write schedule;
it does not prove a synthesizable Reward-placement interface. PREPARE is CLEAR,
then a COMMIT with each old=target=start and both surviving, then three oracle
placements. Replacement writes run after the real Step COMMIT, before publishing
its response. The oracle uses traced placements rather than generating an LFSR,
seed, retry policy or scan algorithm. Crash code 6 follows ADR 0003 and the HDL
controller; Python leaves the old Head code. Both block subsequent movement, so
this intentional memory-image difference does not change the Step logs here.

### Model trace format

Run `make_trace.py` using python3 **from `prototipos/tron_fpga/`**, headlessly.
It subclasses Game only to observe the pre-edge batch/eligibility and post-edge
command/placements, using `scenario.parse/run` unchanged. It writes one `.trace`
row per tick and the complete `.model.log`. Logs were independently regenerated
with `python3 -m model.scenario` for each scenario and compared byte-for-byte.

Each row has 21 decimal integers, in order:

```text
reset load new_match paused apply launch axes_p1 axes_p2
start_cell_p1 start_cell_p2 start_heading_p1 start_heading_p2 goal_sel
placement_slot0 placement_slot1 placement_slot2 log_kind tick round step phase
```

Cells encode `128*cy+cx`. Placement -2 means no event, -1 means absent, >=0
means write that Cell as code 8+slot. All three PREPARE placements and each
post-COMMIT replacement are captured from `ctrl.placements`, including repeats
at the same Cell. `log_kind`: 0 none, 1 prepared Round, 2 Step. Headings 0..3
are U/R/D/L; goal_sel 0..3 means 10/20/30/40. Reset is applied on a separate
clock edge before that row's tick 1. The other metadata belongs to unselected
match control. HDL computes heads, displayed Headings, crashes, Points, Lives,
goal and result. No expected target code, collision outcome or score enters HDL.
Slot metadata comes from the oracle, as permitted; phase/round/Step count come
from the trace. This is a datapath comparison, not independent match-control
verification. A late outcome uses current trace phase/ordinal metadata, so those
fields and the oracle schedule may diverge after the first timing difference.

## 2. Source state and tools

Vivado/XSim 2025.2, target xc7a100tcsg324-1; inferred memories, no generated IP
in this experiment. `evidence/sha256sum.txt` records final local sources,
traces, model logs, dependencies and runners. Per-run source hashes record the
actual container snapshots; early sweep benches precede final assertions and
RTT instrumentation, with unchanged DUT. Git was read-only. All created files
are in `datapath/`; sibling HDL and shared files were unchanged.

## 3. Commands, results and host artifacts

From repository root (shell runner requires sandbox escalation for the fixed
`sudo -n /usr/local/sbin/cs256-vivado` launcher):

```bash
(cd prototipos/tron_fpga && python3 ../../proyecto_final/prototypes/core_blocks/datapath/make_trace.py)
bash proyecto_final/prototypes/core_blocks/datapath/run.sh
bash proyecto_final/prototypes/core_blocks/datapath/run.sh synth
bash proyecto_final/prototypes/core_blocks/run_all.sh
# For each delay/phase row recorded in evidence/runs.txt:
bash proyecto_final/prototypes/core_blocks/datapath/run.sh -g FORWARD=4997 -g BACKWARD=4998 -g PHASE=0
# Build directory is the Artifacts (host) line printed by run.sh:
python3 proyecto_final/prototypes/core_blocks/datapath/compare.py /home/alan/.local/share/cs256-vivado/builds/BUILD LABEL
# compare.py invokes the required command, with no --ignore:
python3 tools/steplog_diff.py MODEL.log HDL.log
```

`run.sh` expands the sibling sources by path; it delegates to the unchanged
shared runners. `manifest.txt` lists all 12 scenario basenames. Each run writes
one HDL Step log per scenario with `$fwrite` in `model/steplog.py` format.
`evidence/*/diff.txt` retains the exact comparisons, including first-difference
fields on stress failures; HDL logs are retained beside them.

Independent suite (`evidence/independent.txt`): PASS game_pkg_tb, arena_map_tb,
arena_ctrl_tb, turn_unit_tb, step_resolve_tb, score_directed_tb, score_model_tb,
sync_2ff_tb, btn_debounce_tb, seg7_page_tb, seg7_driver_tb, game_clk_div_tb.
The additional **vga_out_check_tb FAIL** is the pre-existing, expected coordinate
alignment defect documented in video/FINDINGS.md; the shared runner explicitly
exempts it. The 12 requested previously passing benches still pass. No datapath
source is used by that failing check. The final integration bench also asserts
Head-on crashes both and a crashed head retains its old Cell, independently of
expected model outcomes.

Core synthesis: **151 LUT, 134 FF, 0 F7 mux, 0 BRAM, 0 DSP, 0 latches**.
At `-c clk 11.982`: **WNS +3.644 ns, WHS +0.256 ns, WPWS +5.491 ns**, zero
failing internal setup/hold endpoints. Artifact:
`/home/alan/.local/share/cs256-vivado/builds/core-synth-step_core-20261029-002702-624792/`.
Short runner log and full timing/utilization/latch reports are retained in
`evidence/`. OOC I/O is unconstrained; no routed or board timing claim.

Initial bench-only defects: phase formatter used MATCH instead of MATCH_OVER;
fixed it without ignoring phase. Its unsized timeout overflowed 32 bits and
ended replay prematurely; fixed to a 64-bit delay. An early driver scheduled
rows on falling edges after long PREPARE and used trace tick labels; replaced
that with continuously counted game edges and next-edge driving. Final full
comparisons use actual ticks. These were harness defects, not sibling bugs.

### Delay sweep (recorded by the orchestrator, 29 October 2026)

The builder stopped at its usage limit before writing this section. The
numbers below come from the retained run folders listed in `evidence/runs.txt`
(`sim.log` MEASURE/MAX_RTT_FAST lines, `xelab.out` generics) and from
`evidence/<label>/diff.txt`. Game period N = 10000 fast cycles; RTT is the
largest observed round trip in fast cycles, from game-side issue to the
response being visible, including bridge delay and Arena service.

| Run | FORWARD | BACKWARD | PHASE | Max RTT read / commit | Step logs vs model |
|---|---:|---:|---:|---|---|
| baseline | 0 | 0 | 2 | 5.0 / 14.0 | 12/12 match |
| sweep-a | 4997 | 4997 | 0 | 9997.5 / 10006.5 | 12/12 match |
| sweep-b | 4997 | 4998 | 0 | 9998.5 / 10007.5 | 12/12 match |
| sweep-c | 4998 | 4998 | 9 | 9999.5 / 10008.5 | 12/12 match |
| sweep-e | 4997 | 4998 | 9 | 9998.5 / 10007.5 | 12/12 match |
| sweep-d | 4998 | 4998 | 0 | 9999.5 / 10000.5 | every scenario: first Step 1 tick late (`tick: 13 != 14`) |

Every run had 3175 outcomes and `overruns=0`. **Limit:** the model's tick
timing holds while each command's response is visible before the next game
edge after its issue, that is, round trip below one game period (relative to
the phase). Past that, outcomes land one tick late. This is the model's
"two ticks per command" written in fast cycles: issue at edge k, captured
at k + 1, consumed at k + 2. Delays between one and two game periods, and
how the 6-tick cadence degrades past the model's 4-tick minimum Step, were
not swept.

**Consequence for a real crossing (inference, not measured).** The Arena
service is tiny: 5 cycles for READ2 and 14 for COMMIT round trip, out of
about 1.39 M `clk_pix` cycles per game tick. The budget that matters is
counted in **game edges**, not in fast cycles. A conventional 2-FF
synchronizer of a response tag clocked by `clk_juego` costs two game edges on
its own, so each command would take about three ticks and READ2 + COMMIT
about six: exactly the agreed Step with no slack. Candidate crossings should
be judged by how many `clk_juego` edges they spend. Examples are a response
captured from a bus that is stable for a whole game period, or synchronizing
on the fast side only. This needs a real crossing experiment with routed
CDC reports.

## 4. What the evidence shows

The tick-preserving baseline demonstrates composition of launch, both Arena
reads, combinational resolution, COMMIT and scoring for all M2 scenarios.
Model comparison is not independent proof; the independent directed block
checks above and the integration retained-head/Head-on assertions supply that
side. This does not select CDC, match control, input batching or Reward placement.

## 5. Limitations, risks and requests

- Roman/Alan: select and separately validate an actual crossing against this
  composed latency budget, reset/epoch behavior and coherent payload ownership.
  Never copy the simulation bridge into a synthesizable top.
- Select a generic placement/PREPARE interface: the present data-force oracle
  is solely a test adapter; Reward search cost and LFSR are not measured here.
- Phase, round number, Step ordinal and Reward oracle come from model traces.
  Stress beyond the first late outcome is open-loop replay; match control may
  enter phases or request a launch at times a slower closed-loop design would
  change. Do not infer gameplay correctness beyond that boundary.
- Out-of-context timing omits clock generation, physical crossing, external
  input/output delays and routing. No CDC, DRC, monitor or board sign-off.
- Existing VGA alignment remains the video owner's documented request; no
  change to production `vga_out.sv` or shared runner is proposed by this builder.
