# Turn handling and Step resolution feasibility evidence

29 October 2026 host date (container logs use 28 October). Owner: **Roman, G1/G2**.
Builder checks only; these are not Alan's official cross-owner tests (§7).

## 1. Built, sources, interfaces and deviations

Read AGENTS.md and the docs authority path, the course classproject handout,
contract §§1,4,5,6, ADR 0002 (accepted), ADR 0003 (proposed working defaults),
ADR 0005 (proposed), Official FPGA Coding Practices, Hardware Map and Step
Transaction and Displayed Heading Research. Locked Turn/Crash rules govern.

`turn_unit.sv` owns one Bike's 2-bit Heading and Pending Turn on game-domain
`clk`. Two instances are required. **All ports are provisional**, pending in
contract §4. `rst` synchronously loads RIGHT; `load` synchronously loads
`load_heading` into both registers; priority is rst > load > normal operation.
The batch is `v_valid,v_down,h_valid,h_left`: vertical UP/DOWN and horizontal
RIGHT/LEFT respectively. Invalid axis direction bits are ignored. `apply`
controls input consumption; `launch` takes the updated Pending Turn into Heading
on that edge, even when apply is false. Pending is retained after launch.
This is `TurnUnit.load`/`clock` behavior, with a defined synchronous reset added.
The caller gates apply/launch for phase/Pause and resolves input ordering/ties.
No raw asynchronous input or CDC circuit belongs inside this block.

`next_cell.sv` computes a target from a packed Cell `{cy[5:0],cx[6:0]}` and
2-bit package Heading, modulo 128/64. `step_resolve.sv` accepts each Player's
13-bit head and already computed target, plus each 4-bit READ2 target code.
It returns new heads, Crashed flags, Head-on and 2-bit collected slot per Player.
**All ports are provisional. Slot 3 means none; 0/1/2 name Reward slots.**
This encoding adapts Python's None without a separate valid bit. Same target or
swap crashes both regardless of codes. Only EMPTY and Reward codes 8–10 permit
survival; all other 4-bit codes block, matching `arena_map.is_blocking/is_reward`.
A crash retains the old head and suppresses collection. Targets are intentionally
separate from the resolver so captured READ2 addresses are used unchanged.

These are pure functions in the game domain under ADR 0003 item 1's working
default READ2 → resolve → COMMIT. No crossing, scoring, writes or display state
is implemented here. In particular the COMMIT writer must implement proposed
Crash code 6 writes; Python omits those writes, which does not change these
outcome vectors. `step_resolve_reg.sv` adds input/output registers in one fast
domain to estimate fallback feasibility; at edge k it captures inputs and at
k+1 captures their result. It includes neither next_cell nor service scheduling.
It is an experiment, not selection of the atomic-fast-Step fallback.

## 2. Source state and tools

Exact SHA-256 values for all six .sv files, generator, vectors, shared package,
runners and four referenced model files: [evidence/sha256sum.txt](evidence/sha256sum.txt).
Final sources/vectors were compared byte-for-byte with the actual run snapshots.
Vivado/XSim **2025.2**, SW build **6299465**, IP build 6300035; no generated IP.
Part `xc7a100tcsg324-1`. No git mutation performed. Shared files unchanged.

## 3. Reproduction commands and observed results

Run from repository root unless specified. Runners require sandbox escalation
and use `sudo -n /usr/local/sbin/cs256-vivado`. Artifacts below are host paths
under `/home/alan/.local/share/cs256-vivado/builds/` (denoted BASE).

Generate vectors from `prototipos/tron_fpga/`:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 ../../proyecto_final/prototypes/core_blocks/step/generate_vectors.py
```

PASS generation: 3,055 turn rows, 12,295 resolver rows, fixed seed 256.
The generator imports the headless model, with the working directory on sys.path.
It asserts independently stated directed expectations before writing them.
Turn coverage: 4 Headings × 3 reachable Pending values × 16 raw axis patterns ×
apply × launch = 768 exhaustive transitions, with load/setup rows; explicit
Up-then-Left, ignored reversal preserving pending, launch eligibility and
reset/load priority sequences; plus 1,000 random control ticks.
Resolver: 39 directed cases, every 16×16 code pair and 12,000 random vectors.
Random cases bias same-target/swap and valid Reward codes; coordinates cover the
whole padded grid. Directed cases cover Wall, own/other Trail, both head codes,
other head target, both Head-on forms (including EMPTY codes), one/both crashes,
every survivor collection slot and crashing Reward entry, and cx=0 LEFT wrap.
Bench independently checks next_cell over all 8,192 Cells × 4 Headings.

```bash
proyecto_final/prototypes/core_blocks/run_xsim.sh turn_unit_tb prototypes/core_blocks/step/turn_unit.sv prototypes/core_blocks/step/turn_unit_tb.sv
proyecto_final/prototypes/core_blocks/run_xsim.sh step_resolve_tb prototypes/core_blocks/step/next_cell.sv prototypes/core_blocks/step/step_resolve.sv prototypes/core_blocks/step/step_resolve_tb.sv
proyecto_final/prototypes/core_blocks/run_synth.sh -c clk 11.982 turn_unit prototypes/core_blocks/step/turn_unit.sv
proyecto_final/prototypes/core_blocks/run_synth.sh -c clk 11.982 step_resolve_reg prototypes/core_blocks/step/step_resolve.sv prototypes/core_blocks/step/step_resolve_reg.sv
```

- `PASS turn_unit_tb vectors=3055 zero mismatches`.
  BASE/core-turn_unit_tb-20261029-000537-604955; retained `evidence/turn-sim.log`.
- `PASS step_resolve_tb vectors=12295 next_cell=32768 zero mismatches`.
  BASE/core-step_resolve_tb-20261029-000606-607525; retained `evidence/resolve-sim.log`.
- Initial resolver run also PASS (12,292 rows), before adding three independent
  same-empty/swap-empty/other-head directed checks. Artifact:
  BASE/core-step_resolve_tb-20261029-000537-605246; retained initial log.
- turn_unit synthesis: **7 LUTs, 4 registers, WNS +9.188 ns, WHS +0.464 ns**,
  critical setup path 3 logic levels, 2.754 ns data delay.
  BASE/core-synth-turn_unit-20261029-000536-604651.
- step_resolve_reg synthesis: **49 LUTs, 93 registers, WNS +7.566 ns,
  WHS +0.345 ns**, critical setup path 5 logic levels
  (2 CARRY4, 2 LUT4, 1 LUT6), 4.376 ns data delay.
  BASE/core-synth-step_resolve_reg-20261029-000536-604484.
- Both: 0 latches, 0 RAM (block/distributed), 0 DSP, 0 F7 mux;
  TNS/THS 0, WPWS +5.491 ns. Full text reports retained under `evidence/`.

Warnings: XSim 43-3431 reports C compiler environment variables; benches pass.
Synthesis Timing 38-242 reports missing OOC HD.CLK_SRC, so physical clock
skew is not established. No input/output delays are set by the runner:
turn has 10/4 missing input/output delays, wrapper 61/33; both have zero
unconstrained internal endpoints and zero missing clocks. No-latch/no-RAM
query warnings are expected. Pre-synthesis timing uses estimated routing.
Initial local file-generation invocation used the wrong cwd and wrote no files;
initial generator import failed before creating vectors. Corrected cwd/sys.path
and reran successfully; no HDL failure or model mismatch was observed.

## 4. What the evidence establishes

The provisional datapath reproduces the model on all checked vectors and the
independently stated rules, including simultaneous resolution and survival
collection. Small synthesized area and positive internal setup/hold estimates
support game-domain combinational resolution and the *logic portion* of a
registered fast-domain fallback. Neither Player receives priority.

This is not routed timing, CDC, board, official-test or integration sign-off.
No complete Step FSM, READ2/COMMIT write ordering, six-tick throughput or display
publication has been tested. No full M2 Step logs were replayed: those include
scoring, lifecycle, placement and bridge timing outside this block set. These
are pure outcome vectors, not substitutes for those integrated logs.

## 5. Limitations, risks and questions for Roman and Alan

- Select ports in the contract before shared integration: batch encoding,
  packed Cells, load/reset priority and slot-3 sentinel need acknowledgement.
- Upstream must supply coherent READ2 codes for the exact captured targets;
  suppress Reward writes during the reserved transaction, gate steering by
  eligible play, and preserve ordered/tied input semantics before axis reduction.
- Phase-swept service/CDC tests must measure six-tick cadence before deciding
  whether the fallback is needed. The wrapper excludes memory, target arithmetic,
  request/rearm and display scheduling; no complete atomic Step is demonstrated.
- COMMIT must write Crash code 6 under the proposed default and publish resulting
  head/attempted Heading together. Reset/Pause/stale-response behavior remains
  a controller/integration obligation.
- Illegal/X input behavior is not defined by the model; tests use known 2-state
  values. Undefined 4-bit codes 11–15 conservatively block as the model does.
- Icarus is unavailable; syntax targets Icarus compatibility but only XSim was run.
- **Shared-file changes requested: none.** Contract adoption is future team work;
  no selected shared interface or accepted decision is changed by this evidence.
