# Arena A1/A2 feasibility evidence — 29 October 2026

## 1. Built and authority

Owner: **Alan**, A1/A2 (contract §4/§7). This is an isolated provisional
experiment, not a selected shared interface or the official Roman-written
§7 bench. Read the root AGENTS.md, docs README/architecture map/glossary,
locked agreed specification, course project and sprite handouts, contract
§1/§4/§5/§6, ADR 0002 (accepted), ADR 0003/0005 (proposed), Fast Clock Domain
Research and Official FPGA Coding Practices (especially Arena memory/reset).
Model references: `arena_map.py`, `arena_ctrl.py`, `mailbox.py`, `params.py`
under `prototipos/tron_fpga/model/`.

- `arena_map.sv`: exactly the §4 ports `clk`, `a_addr[12:0]`, `a_we`,
  `a_wdata[3:0]`, `a_rdata[3:0]`, `b_addr[12:0]`, `b_rdata[3:0]`.
  8192 × 4 inferred block RAM; A reads/writes, B reads only. Both clocks are
  the same `clk` net, intended to be buffered `clk_pix` at 83.46 MHz under
  ADR 0003 item 3. Both outputs update after the sampling rising edge:
  **one synchronous read stage**, no extra BRAM output register.
- A **READ_FIRST** write returns the previous word. B reading the same
  address at that edge also returns the previous word. Subsequent reads see
  the new word. No bypass logic or collision suppression. Synthesis actually
  configures A READ_FIRST, B WRITE_FIRST: B never writes, so its own write
  mode has no effect on these read-only B semantics. Both ports must share
  the same clock-buffer driver; this is not a dual-clock claim.
- `arena_ctrl.sv` instantiates the map and is A's sole writer. All controller
  ports/timing are **provisional**. No CDC exists inside this block.
  `cmd_op`: 1 CLEAR, 2 READ2, 3 COMMIT, 0 invalid/no-op.
  Accept at a rising edge iff `cmd_valid && !busy && !rst`. All old/target
  addresses and survive flags are latched. `old_p1/p2`, `target_p1/p2` are
  13-bit `{cy,cx}`; `survive_p1/p2` are separate bits. `code_p1/p2` are
  registered four-bit READ2 responses. `busy` rejects requests during service;
  `done` pulses for one cycle and response codes hold until another READ2.
  A producer must retire valid after acceptance; held valid can be accepted
  again when idle. Earliest next acceptance is the edge after completion.
- CLEAR writes every address once, EMPTY only at cx=1..78, cy=5..48, WALL
  elsewhere: **3432 EMPTY, 4760 WALL**. This follows model `clear_word`.
  Contract §6 instead says EMPTY except walls. A literal interpretation with
  the §1 wall ring leaves HUD (320 words) and padding (4192 words) EMPTY;
  this experiment writes WALL at those **4512 additional addresses**.
- READ2 reads both requested cells on A without writes, then publishes both
  registered codes. The caller resolves movement/collision in the game
  domain before issuing COMMIT; the controller does not enforce pairing.
- COMMIT writes each surviving Bike's old head to its Trail and target to
  its Head. Each crashed Bike writes code 6 at its last valid old head,
  without touching its target (ADR 0003 item 4). Processing P1 before P2
  implements already-resolved results, not collision priority. Caller must
  supply legal resolved destinations; arbitrary conflicting write arguments
  are not validated. This is not reward placement or full PREPARE.
- Synchronous active-high `rst` aborts work, suppresses writes and clears
  controller state/results, **not memory**. Reset during a transaction can
  leave a partial image: hide rendering/game validity and issue CLEAR before
  reuse. No Pause input: accepted work completes; upstream admission and
  publication policy must handle Pause. This does not settle contract §6's
  system-level reset/Pause guarantees.

## 2. Source state and tools

Vivado/XSim **2025.2**, SW build **6299465**, target `xc7a100tcsg324-1`.
No generated IP: inferred RAMB36E1. Final-source hashes below; Git left
read-only. Synthesis used the same final DUT sources. Simulation clocks are
12 ns under XSim's default units to match the untimed shared package;
cycle counts are converted below using the requested 83.46 MHz. Synthesis
uses the requested 11.982 ns constraint.

```text
e43658083ef4955a65e1aeeca626e7c50bdb3073ffaa2ab99f06d637b27f814f  proyecto_final/prototypes/core_blocks/arena/arena_ctrl.sv
85ec5ad980715fd8a4c5955959965ef0bbba372877166543c154aef067f48e9a  proyecto_final/prototypes/core_blocks/arena/arena_ctrl_tb.sv
6ed41e4b1ca831099ed47d188432ce21d52f030da9d74780fa7235942c26f373  proyecto_final/prototypes/core_blocks/arena/arena_map.sv
7c026c053a70c61417322f838eb6814677d4eabe10a3a33602ea4836f94d8f36  proyecto_final/prototypes/core_blocks/arena/arena_map_tb.sv
d31532e90d5b78b6c606bd862ca10865680aaa92ebacba45f5984d8d103ab602  proyecto_final/prototypes/core_blocks/arena/compare_model.py
838ab73bdb56e487f34a2b1c2c1d5dd978a2447e27ef9e4b08e51d16a9449920  proyecto_final/prototypes/core_blocks/arena/run_ram_report.sh
22a694ce751cb292d93bbcb269e7f6361479688f380e0d48ad56ec1b483630fc  proyecto_final/prototypes/core_blocks/arena/report_ram.tcl
ae83f3c55a9219fa84c1967238514aa98d741cd6e088992439164c621f1375e8  proyecto_final/prototypes/core_blocks/game_pkg.sv
627611d98a9a60dccaa777c818410b1514b00d48e3338d419f1440ae93bfeeba  proyecto_final/prototypes/core_blocks/run_xsim.sh
62f4f4a160b9d8aa2bd7dd7683024d72b9e2d20bb2fb481683ce3bef45115ba0  proyecto_final/prototypes/core_blocks/run_synth.sh
```

## 3. Reproduction and results

Run from repository root, outside the agent sandbox (runners use the fixed
`sudo -n /usr/local/sbin/cs256-vivado` container launcher):

```bash
proyecto_final/prototypes/core_blocks/run_xsim.sh arena_map_tb prototypes/core_blocks/arena/arena_map.sv prototypes/core_blocks/arena/arena_map_tb.sv
proyecto_final/prototypes/core_blocks/run_xsim.sh arena_ctrl_tb prototypes/core_blocks/arena/arena_map.sv prototypes/core_blocks/arena/arena_ctrl.sv prototypes/core_blocks/arena/arena_ctrl_tb.sv
proyecto_final/prototypes/core_blocks/run_synth.sh -c clk 11.982 arena_map prototypes/core_blocks/arena/arena_map.sv
proyecto_final/prototypes/core_blocks/run_synth.sh -c clk 11.982 arena_ctrl prototypes/core_blocks/arena/arena_map.sv prototypes/core_blocks/arena/arena_ctrl.sv
python3 proyecto_final/prototypes/core_blocks/arena/compare_model.py
```

**Shared runner report defect:** Vivado 2025.2 does not match its filter
`PRIMITIVE_GROUP == BLOCKRAM || PRIMITIVE_GROUP == DMEM`; original `ram.txt`
is empty despite actual BRAM inference. Do not interpret this as zero RAM.
The arena-local supplement reruns exactly that build's Tcl, then queries
`REF_NAME =~ RAMB*`, asserts one RAMB36E1, and rewrites its generated
`ram.txt` with actual primitive properties. No shared source was edited:

```bash
bash proyecto_final/prototypes/core_blocks/arena/run_ram_report.sh /builds/core-synth-arena_map-20261029-000514-603343
bash proyecto_final/prototypes/core_blocks/arena/run_ram_report.sh /builds/core-synth-arena_ctrl-20261029-000514-603543
```

For a fresh run replace the two `/builds/...` arguments with the directory
basenames printed by the two synthesis commands. Copied checked `ram.txt`,
utilization, latches, timing summaries and runner outputs are in `evidence/`.

| Check | Result |
|---|---|
| `arena_map_tb` | **PASS**, 32768 two-port checks; 16384 same-address collisions, full-address patterns containing all 16 codes, complete subsequent readback |
| `arena_ctrl_tb` | **PASS**, full 8192-word scan after CLEAR and each survive/crash combination; independent command-derived golden image; known-write READ2, equal/boundary targets, crash over actual preexisting heads, argument capture, busy-request rejection, done pulse, reset during CLEAR and recovery |
| Continuous B during controller service | **PASS**, 82006 checked reads, 16403 writes, 16398 same-address collisions; every second CLEAR write forced to collide, concurrent reads never stall writes |
| `compare_model.py` | **PASS**; CLEAR image/count matches, READ2 model=2 accesses, COMMIT supplied-write counts=4/3/3/2; not independent rule proof |
| RAM supplement, both tops | **PASS arena_ram_report**, one RAMB36E1 each; A READ_FIRST, B WRITE_FIRST; DOA_REG/DOB_REG=0; read/write widths=4 |

| OOC top | LUT | FF | F7 mux | RAMB36E1 | Latches | WNS ns | WHS ns | WPWS ns |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| arena_map | 0 | 0 | 0 | 1 | 0 | inf | inf | 9.038 |
| arena_ctrl including map | 63 | 78 | 13 | 1 | 0 | 7.450 | 0.260 | 5.491 |

DSP=0 in both. No finite setup/hold paths exist in the standalone RAM OOC
report with unconstrained I/O, hence **inf is not a timing pass claim**.
The controller has positive internal register-path setup/hold estimates;
I/O paths remain unconstrained. Vivado warns HD.CLK_SRC is unset, so clock
skew/delay estimation is limited. These are synthesis estimates, not routed
sign-off. The supplement reproduces the same utilization/timing summary.
The XSim LIBRARY_PATH environment warning did not prevent either PASS.

| Command | RAM accesses | Measured acceptance-to-done cycles | Time at 83.46 MHz |
|---|---:|---:|---:|
| CLEAR | 8192 writes | 8192 | 98.155 us |
| READ2 | 2 reads | 3 | 35.945 ns |
| COMMIT both survive | 4 writes | 4 | 47.927 ns |
| COMMIT one crash | 3 writes | 3 | 35.945 ns |
| COMMIT both crash | 2 writes | 2 | 23.964 ns |

Acceptance is edge k; CLEAR first writes at k+1, last at k+8192, asserting
done after that edge. READ2 addresses are sampled at k+1 and k+2; response
p1 is captured at k+2, p2/done at k+3. RAM itself has one synchronous read
stage; the extra completion edge safely registers its second result.
COMMIT writes begin at k+1; final write and done share the final edge.
Model one-access-per-cycle estimates agree for writes. READ2 completion is
one fast cycle longer than the model's two accesses. Model PREPARE includes
heads and reward search; this CLEAR is only its 8192-word component.

A nominal 60 Hz tick is 1,391,000 fast cycles (the video frame is 1,391,040);
six ticks give **8,346,000** cycles. CLEAR uses 0.589% of one tick and 0.0982%
of the six-tick Step budget. A worst READ2+COMMIT fast service sequence takes
3+1+4=8 cycles including earliest idle acceptance of COMMIT. This says nothing
about game-domain resolution delay, CDC round trips, reward search or display
publication; those may dominate the composed schedule. Every measured
command is also below the model's provisional 262144-cycle SERVICE_WINDOW.

Host artifacts (prefix `/home/alan/.local/share/cs256-vivado/builds/`):

- Final map bench: `core-arena_map_tb-20261029-000535-604307/`.
- Final controller bench: `core-arena_ctrl_tb-20261029-000721-610405/`.
- Map synthesis + checked RAM report: `core-synth-arena_map-20261029-000514-603343/`.
- Controller synthesis + checked RAM report: `core-synth-arena_ctrl-20261029-000514-603543/`.
- Initial bench attempts: `core-arena_map_tb-20261029-000505-602665/`,
  `core-arena_ctrl_tb-20261029-000513-603184/` failed elaboration because
  bench-local timeunits conflicted with untimed shared modules/package.
  Fixed locally by consistently using XSim default units; retained
  `evidence/*_xsim_initial.txt`.
- Intermediate controller run: `core-arena_ctrl_tb-20261029-000537-604918/`
  failed because test address 1401 was in padding (expected EMPTY wrongly).
  Fixed playable vectors; retained `ctrl_xsim_vector_failure.txt`. The first
  corrected run `core-arena_ctrl_tb-20261029-000559-607062/` passed; the final
  run strengthens the separate golden-map and existing-head crash checks.

## 4. What the evidence establishes

The proposed fast memory choice has substantial isolated service margin.
8192 × 4 memory infers one RAMB36E1, not a register array. Simulation checks
synchronous old-data collision semantics and continuous rendering reads
without memory corruption, including complete readback. Controller commands
latch inputs, respect busy, perform the intended per-Player writes and return
READ2 codes with explicitly measured latency. No latches are inferred.

This does not prove a CDC, a complete Step cadence, frame-coherent rendering,
reset/Pause integration, routed timing, generated Clocking Wizard frequencies,
board operation or rule equivalence for the full M2 scenarios. No game engine,
resolver or mailbox is present to replay those scenarios here. No primitive
netlist/post-route simulation was run; inferred primitive modes corroborate
RTL simulation, rather than constitute a hardware collision measurement.

## 5. Findings, limitations and requests for Roman/Alan

1. Reconcile contract §6 CLEAR semantics: adopt explicit WALL for HUD and
   padding, or change this model-aligned experiment after agreement.
2. Record `clk_pix`, one-cycle synchronous memory reads, A READ_FIRST and
   same-clock B old-data collision behavior in the contract when selected.
   Renderer prefetch must account for this latency. Common clock alone does
   not provide frame coherence during multiword COMMIT/CLEAR.
3. Code-6 crash writes deliberately follow ADR 0003; current model gameplay
   does not emit them. Supplied-write model comparison explicitly includes
   them and does not pretend to test that missing gameplay behavior.
4. The game-to-service crossing stays fully open. Do not reuse this local
   valid/busy handshake across clocks or treat these fast-cycle counts as
   mailbox latency. No response acknowledgement or queue is implemented.
5. Reset abort needs a system-level validity/CLEAR sequence; Pause and video
   publication need a policy for in-flight transactions. The local behavior
   deliberately makes no atomicity promise across reset or visible frames.
6. Reward placement, seeding, start-head preparation and reward metadata are
   out of scope. Caller handles legality and read-before-write ordering.
7. **Shared-file request:** fix `run_synth.sh` RAM reporting to query actual
   `REF_NAME` RAM primitives (or the correct Vivado primitive group), and
   fail if expected memory inference disappears. The local supplement makes
   this evidence complete without touching the shared runner.

No shared HDL/package/runner, contract, locked decision record or Git state
was changed by this builder. All deliverables are confined to `arena/`.
