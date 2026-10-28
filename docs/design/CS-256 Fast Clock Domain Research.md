---
schema_version: 1
id: cs256-fast-clock-domain-research-20261028
title: CS-256 Fast Clock Domain Research
type: note
subject: CS-256
status: proposed
created_at: "2026-10-28"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[0002-follow-ta-divided-game-clock]]"
  - "[[0003-step-transaction-mailbox-and-render-codes]]"
  - "[[CS-256 UART Input Prototype Findings]]"
  - "https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources"
  - "https://docs.amd.com/v/u/en-US/ug472_7Series_Clocking"
  - "https://docs.amd.com/v/u/en-US/ds181_Artix_7_Data_Sheet"
  - "https://docs.amd.com/r/en-US/pg065-clk-wiz/Resets"
review_status: unreviewed
tags:
  - tron
  - fpga
  - research
  - clocking
  - cdc
---

# CS-256 Fast Clock Domain Research

Research checked **28 October 2026**, on `docs/systemverilog-readiness`. This is research for ADR 0003 item 3, **not a team decision**. Only this note was written; no HDL, contract or ADR was changed. **Locked requirement**, **source fact**, **engineering recommendation**, and **unverified assumption** distinguish authority from advice and evidence.

## Working default

**Engineering recommendation — high confidence in the clock choice:** use the pixel Wizard's `clk_pix`, requested **83.46 MHz**, for **both Arena BRAM ports, `arena_ctrl` (clear, READ2, COMMIT and Reward search), and the fast side of X1**. Reuse it for UART RX, button synchronization/debounce and fast display scanning. Keep movement, collision resolution, Round/Match, Points/Lives and game timers on the real divided `clk_juego`, as accepted in ADR 0002. Initially let memory service advance every pixel clock while busy; use ordinary synchronous enables for idle state and qualified writes.

This removes a service/video clock boundary without sacrificing needed compute throughput. It agrees with Roman's proposed item 3 and review §5.2. **Timing confidence is provisional:** there is no implemented Arena/Reward/drawcon path to certify yet. Start with this default and test it early; do not freeze the crossing protocol or assume frame coherence from the clock choice.

**Locked requirements:** 1280 × 800 RGB444 at the requested pixel rate; one Cell per six approximately 60-Hz game ticks; Arena **8192 × 4**, addressed by `{cy,cx}`; one fast Arena write owner; coherent requests/results/snapshots; clocks, video and Scoreboard continue during Pause. Exact service clock and physical crossing protocol are not locked. Sources: [[CS-256 Tron Agreed Specification 2026-10-20#Movement, Turns and Crashes]], [[CS-256 Tron Agreed Specification 2026-10-20#Clocks, Arena encoding and service boundary]], specification lines 54, 79, 99, 109–123; [[0002-follow-ta-divided-game-clock#Consequences]].

The authority path remains [[CS-256 Tron Architecture and Documentation Map#Authority and status]] and [[CS-256 Tron Glossary]]. ADR 0001 is superseded. ADR 0003 remains proposed; adopting item 3 need not settle item 2. [[CS-256 Tron SystemVerilog Readiness Decisions#Confirmed answers]] accepts the shared model base, not the proposed hardware interfaces.

## Alternatives and domain boundaries

Counts below refer to **logical domain boundaries**, not individual synchronizer instances. The default has two application domains plus the game-divider source clock. External pins still cross into synchronous logic.

| Choice | What crosses | Why / why not now |
|---|---|---|
| **Default: service and video on `clk_pix`** | One slow/fast boundary: game commands/arguments and completion acknowledgement, returned Cell codes/status, input events, and coherent game/render state. Reset/readiness also needs domain treatment. Arena A/B and fast service/render control remain synchronous. | Fewest application boundaries; fastest path to a testable prototype. No extra CDC between memory service and drawcon. |
| **A on 100 MHz or another Wizard clock; B on `clk_pix`** | Game↔service and game↔video boundaries remain. BRAM is an additional service↔video shared-memory boundary; frame/bank ownership, write completion or publication controls must cross if used. Direct service↔game input transport is possible if capture stays with service. | Technically supported true dual-port arrangement. 100 MHz gives only about 20% more cycles/s and a **tighter 10 ns** service timing requirement. More collision, reset and publication work for no present need. |
| **Service on a lower Wizard clock, B on `clk_pix`** | Same extra shared-memory/control boundary as above. Keep UART/buttons on the selected capture clock; do not split them casually. | Useful fallback for a measured service timing bottleneck. Even 25–50 MHz has ample estimated compute throughput. Requires actual dual-clock validation. |
| **Service on `clk_pix` with a periodic CE** | Same boundaries as default; CE is data, not a new clock. Video/port B must continue at pixel rate. | Fine for idle/power control or a deliberate multicycle microarchitecture. Periodic CE alone does **not** relax timing: paths are still checked at the pixel period unless legitimate multicycle constraints and hold treatment are proved. No need to throttle the first build. |
| **Entire game on `clk_pix` with 60-Hz CE** | Could remove X1 in a different architecture. | Excluded by the current strict-architecture instruction and ADR 0002. Do not revive ADR 0001. |
| **Arena work on the ~60-Hz game clock** | Fewer domains at the memory owner, but still video crossing. | One write/tick takes about **136.5 seconds** just to clear 8192 words. Fails the practical service requirement. |

**Contract constraint:** §1 currently says the 100 MHz board `clk` feeds the Wizards only. Raw-board-clock service therefore requires an explicit contract revision; it is not a drop-in option. A suitable Wizard output preserves that convention. Accepted ADR 0002 allows a suitable fast memory clock, but does not establish permission for every alteration of the handout. See [contract §§1, 4, 6](../../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md) and [course Drawing Logic Module steps 8, 10–12](../../../cs256-fall-2026/classproject/README.md#drawing-logic-module).

**Source fact:** true dual-port BRAM has separate clocks/enables and synchronous reads. Common-clock read/write collisions can return old data on B when writing A in READ_FIRST; independent-clock collisions can yield unknown B data even with READ_FIRST. Dual-clock BRAM is not an atomic frame store. [UG473 v1.14, 2019-07-03, pp.16–21, Tables 1-4/1-5](https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources).

For the default, use the **same buffered clock net**, not two nominally equal outputs. For different outputs, inspect `report_clock_interaction`; a common oscillator alone does not prove safe timed communication. Retain the clock/exception discipline in [[CS-256 Official FPGA Coding Practices#Establish the actual relationship first]] and [[CS-256 UART Input Prototype Findings#CDC review and constraints]]. No blanket clock-group exception should hide a required bounded payload path.

## Compute budget versus crossing budget

**Engineering calculations**, using I2's achieved **83,455,882.35294117 Hz**, approximately **11.9823 ns/cycle**. This is a generated-IP calculation from nominal 100 MHz, not a board measurement. The six-tick Step budget is about **100 ms**; one tick is about **16.667 ms**. Source: [[CS-256 UART Input Prototype Findings#Vivado/XSim and routed implementation]].

| Operation / estimate | Fast cycles | At achieved `clk_pix` | At 100 MHz |
|---|---:|---:|---:|
| Clear, one write per word | 8192 | 98.160 µs | 81.920 µs |
| Viewer budget's one worst-case placement | 10240 | 122.700 µs | 102.400 µs |
| Model search plus final placement allowance | 10305 | 123.478 µs | 103.050 µs |
| COMMIT, four movement writes plus two worst-case placements | 20614 | 247.005 µs | 206.140 µs |
| PREPARE, clear + two heads + three worst-case placements | 39109 | 468.619 µs | 391.090 µs |
| Model `SERVICE_WINDOW` | 262144 | 3.141 ms | 2.621 ms |

**Implementation evidence:** `juego/budget.py:77–86` computes clear and placement time; its placement estimate omits the 64 candidate reads. `model/reward_place.py:38–54` counts `64 × (32 shifts + 1 read) + 8192 = 10304` cycles for search; `model/arena_ctrl.py:85–91` adds one placement cycle. `arena_ctrl.py:44–82` counts READ2 as two reads, COMMIT as movement writes plus replacements, PREPARE as clear plus two heads plus three placements. Constants are in `model/params.py:78–80`; all paths are under `prototipos/tron_fpga/`. The viewer's comment referring to `model/rewards.py` is stale; current code is `reward_place.py`.

**Unverified assumption:** these counts are transaction estimates, not scheduled RTL cycles. Synchronous RAM waits, pipeline fill/drain, arbitration, candidate revalidation and write publication add work. Do not implement an 8192-iteration combinational search: use a bounded FSM, a candidate address/EMPTY check, serial or staged PRNG, and a sequential scan. A conservative extra cycle per read still leaves large compute margin. READ2 needs latency-aware address/result association, not Python's immediate reads.

There is roughly **35× margin even against one tick** for the estimated worst PREPARE, and **~400× against a Step** for COMMIT. Switching to 100 MHz saves tens of microseconds, not slow-clock ticks. The real cadence risk is X1: command acceptance, response capture, consumer edge, acknowledgement and rearming. [[CS-256 Tron Game Model Hardware Map#Tick timing]] assumes two ticks per command and four per READ2/COMMIT pair; its apparent two-tick slack is **unproved**. I2's measured ~66.65 ms to a registered FIFO output demonstrates how transport can dominate; the synchronous consumer uses that output on its next edge. That FIFO is not a proposed replacement for the still-open mailbox.

**Engineering recommendation:** preserve the full slow-game/fast-service split and evaluate the chosen protocol's complete six-tick schedule separately. Clock selection neither approves a single-capture mailbox nor selects FIFO, handshake or toggle semantics. Keep sequence/payload coherence, reset/Pause, backpressure and rearm requirements open under [[0003-step-transaction-mailbox-and-render-codes#Consequences]].

## Timing and render latency

**Source fact:** [DS181 v1.27.1, 2024-07-03, Table 30, pp.31–32](https://docs.amd.com/v/u/en-US/ds181_Artix_7_Data_Sheet), -1 / 1.0 V column, gives **388.20 MHz** for `FMAX_BRAM_WF_NC`, and **339.67 MHz** for the listed SDP READ_FIRST delayed-write case. These primitive limits are comfortably above 83.46 MHz; they do **not** certify the surrounding controller, BRAM routing or render logic.

**Measured precedent, limited scope:** I2 used Vivado 2025.2 build 6299465 on `xc7a100tcsg324-1`, with pixel Wizard **83.455882 MHz**, game source **5 MHz**, and divider toggle every 41667 cycles (**59.999520 Hz**). Routed setup **WNS +7.344 ns**, hold **WHS +0.119 ns**, pulse width **WPWS +3.000 ns**, zero failing endpoints. It retained five explained CDC warnings, with no critical findings. This was UART/FIFO/LED logic with distributed storage, **not Arena BRAM, Reward logic or Tron drawcon**. Source: [[CS-256 UART Input Prototype Findings#Vivado/XSim and routed implementation]] and its retained reports.

**Engineering recommendation:** keep service critical paths short: register RAM addresses, consume valid read results in a later FSM state, and separate search, validation and write. The likely risks are a large next-state/data mux, an unrolled LFSR/search, and the BRAM/ROM-output-to-RGB layer-selection cone. Actual `proyecto_final/drawcon.sv:1` is still quadrant-colour logic; it supplies no timing evidence for the intended renderer.

Changing service port A's clock does **not** reduce drawcon's port-B read latency or speed up the pixel compositor. Record each generated port's read latency and write mode. Begin with the simplest synchronous read; enable a BRAM output register if reports justify it, updating the early-read lead and service wait states. Keep the handout's combinational drawcon/output-aligned coordinates and fetch Arena/sprite data early by the **total** path latency; no arbitrary new drawcon pipeline or delayed-sync architecture is implied. See [[CS-256 Official FPGA Coding Practices#Selected early-read pipeline]] and contract §4.

**Render coherence remains open:** same-clock collision behavior is only a word-level property. A frame can still contain old Trails, new head codes and an old Bike snapshot. With independent A/B clocks, a coincident write/read also risks undefined read data. Practical experiments may mask video during preparation and compare bounded blanking writes or a buffered display image, but selecting that policy belongs with render research. The full blank-line budget is **47040 pixel cycles ≈563.651 µs**; PREPARE's ideal estimate fits narrowly, without proving overhead or PRNG scheduling fits. Do not promise blanking-only clear plus all placement work on this arithmetic. Separate search from visible writes where useful; choose and test publication timing with the team. Sources: `juego/budget.py:14–17`; [[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]]; [[0003-step-transaction-mailbox-and-render-codes#Left open]].

## Inputs and reset

**Working default for inputs:** synchronize UART RX and each button into `clk_pix`; receive/decode UART there, debounce with a counter or synchronous sampling enable there, then transport press events coherently to the game domain. A debounce enable is not a new clock. Choose a millisecond interval and derive its count from the achieved frequency; no interval is accepted by this note. Keep capture/transport running during Pause; eligibility and stale-event policy remain separate work. A one-pixel-cycle pulse wired into ~60-Hz logic is insufficient.

**I2 evidence:** `proyecto_final/prototypes/uart_input/uart_input_board.sv:25–48` supplies the receiver path from `clk_pix`. Routed RX used **724 clocks/bit**, effective **115270.556 baud**, +0.061246%. Portable simulation used nominal 83.333333 MHz, distinct from the generated hardware frequency. Its reset button is synchronized on the 5-MHz divider source; it did **not** implement gameplay P1 debounce. Do not infer a verified debounce design from it. Sources: [[CS-256 UART Input Prototype Findings#Portable HDL observations]], [[CS-256 UART Input Prototype Findings#Vivado/XSim and routed implementation]].

**Reset source facts:** [UG472 v1.14, 2018-07-30, Table 3-5 pp.78–79 and LOCKED discussion p.83](https://docs.amd.com/v/u/en-US/ug472_7Series_Clocking) says clock outputs should not be used before lock and describes reset after lock loss. [PG065 Clocking Wizard v6.0, 2022-04-20, Resets](https://docs.amd.com/r/en-US/pg065-clk-wiz/Resets) distinguishes the primitive's asynchronous active-high reset and requires reset after lost clock returns; [Optional Ports](https://docs.amd.com/r/en-US/pg065-clk-wiz/Optional-Ports) permits exposing primitive ports. These do not change the project's synchronous active-high **module** `rst` convention.

**Course constraint / unresolved recovery:** Creating the Clock step 3 explicitly disables Wizard `reset` and `locked`. Review §5.2 and I2 retain that setting and use a held startup/reset interval; I2 explicitly does not establish lock-aware recovery. Therefore the immediate course-aligned baseline is a coordinated startup/reset hold, separate synchronous release per domain, and no traffic until initialization and both transport sides are ready. This assumes the source clocks stabilize within the chosen hold; it cannot detect arbitrary later lock loss. The ~60-Hz side needs enough actual clock edges; a short button pulse is not a complete reset specification. Keep the divider clock running so release can happen.

**Engineering recommendation for robust recovery:** expose/reset/monitor the Wizard locks and coordinate recovery if the team/TA confirms those optional ports are compatible with the strict instruction. Do not silently claim this deviation is approved. Synchronize status before use; do not combinationally gate clocks with `locked`. Do not hold the divider itself stopped waiting for a reset release that requires game edges. Reset mailbox state and readiness together, inhibit Arena writes and input acceptance, complete clear/preparation, then release traffic. A dual-clock memory adds another independently released service domain; the default avoids it. Exact reset controller/protocol stays open alongside X1.

## Evidence that changes the default and cost of change

These are **engineering gates**, not new course requirements.

| Observation | Action and expected cost |
|---|---|
| Representative routed design has WNS ≥0, WHS ≥0, no pulse-width failures, constrained internal endpoints and reviewed CDC | Keep `clk_pix`. Aim for **≥1 ns setup slack** in the isolated slice as a provisional integration cushion, not a guaranteed full-design margin. |
| Negative routed WNS at the actual ~11.982 ns period, traced to service logic | First stage the FSM/PRNG or register a BRAM output and rerun. Usually local RTL/wait-state/test changes; no extra domain. Zero slack is the hard pass threshold; small positive slack merits integration scrutiny. |
| Persistent service-path timing failure after reasonable staging | Try lower Wizard service frequency with A on service clock and B on `clk_pix`. Moderate cost: split `arena_map.clk` into A/B clock ports, add/reset/constraint the domain, redesign collision/publication controls, rerun CDC and tests. The game command meanings can stay stable. |
| Measured compute queue/service backlog exceeds its allotted window despite a safe X1 protocol | Measure cycles/arbitration before raising frequency. A 100-MHz Wizard output is an option only if timing closes and its modest gain fixes the measured deficit. Same moderate dual-clock integration cost. |
| Failure is in drawcon or slow-side handshake/rearming | Fix that path/protocol; changing A to 100 MHz does not cure it. Renderer latency changes require early-read alignment tests; protocol changes require a new composed cadence proof. |
| Mid-frame artifacts or mixed Arena/snapshot versions | Choose coherent publication/banking/scheduling. Clock choice can remain unchanged. This may cost more than the clock wiring itself. |
| Lock/startup faults on board | Revisit the reset/locked policy with the course constraint explicitly recorded; add coordinated recovery. Recheck reset during in-flight service and traffic. |

Keep `arena_ctrl` expressed in cycles with a clock-frequency parameter only where wall time matters. Keep its service API independent of video timing; let a separate publication boundary own frame eligibility. This makes a later clock split possible without moving game-state ownership or rewriting rules.

## Consequences for contract and model

**If the team adopts this recommendation:** reconcile contract §1 to name `clk_pix` for fast memory service and input capture; §4 keeps the existing single-clock `arena_map` interface, specifies A/B read latency and write mode, and §6 describes reset/readiness, collision and publication obligations. Record the achieved Wizard frequency separately from the requested 83.46 MHz. Resolve ADR 0003 item 3 independently; keep item 2's physical protocol open. No contract or ADR is edited here.

The shared Python model needs no rules or geometry change for this clock selection. Update cycle estimates after RTL measurements; make the service frequency explicit in budget conversion and reconcile the 64-read estimate difference. `arena_ctrl.execute()` remains atomic Python, not a simulated BRAM FSM. If added read waits, arbitration or publication latency change visible/tick timing, revise model timing assumptions and scenario expectations with evidence rather than preserving unproved two-tick timing. Keep the six-tick cadence as the requirement. See [[CS-256 Tron Game Model Hardware Map#What the model does not show]] and [[CS-256 Tron SystemVerilog Readiness Research#3. Clock relationship, X1 and the six-tick budget]].

## Smallest early remote experiment

**Proposed experiment, not performed here:** on the remote Vivado workstation, make an isolated `.sv` timing slice outside production sources. Match its Vivado/IP versions; use `xc7a100tcsg324-1`. No full game, browser, HUD or final mailbox is needed to answer the first clock question.

1. Generate the pixel Wizard from nominal 100 MHz requesting 83.46 MHz. Reuse the verified two-Wizard/divider topology and constraint approach for a later composed test, without copying its protocol as an accepted design. Record achieved clocks and reset configuration.
2. Instantiate **8192 × 4 true dual-port Arena**, A read/write and B read-only on the same `clk_pix`; a sequential clear/READ2/write/search FSM with real PRNG candidate generation; and a raster-driven B fetch feeding a representative Arena-code/sprite-colour compositor. Use small real synchronous sprite ROMs. Observe data in registered checksums or outputs so synthesis cannot remove the memory/search/render cones. A BRAM-only benchmark would miss the important paths.
3. Exercise full clear; two addressed reads before any Step writes; maximum movement writes; all candidates rejected followed by a full scan; no-free-Cell completion; and simultaneous same-address A write/B read. Compare actual edge latency and collision behavior with the selected primitive configuration using XSim/UNISIM. Preserve collision checks. Counters record start/done/max service cycles.
4. Synthesize, place and route. Save `report_utilization` (confirm BRAM mapping), IP latency/mode settings, `report_clocks`, `report_clock_interaction`, `check_timing`, `report_timing_summary -delay_type min_max`, detailed worst service and render paths, `report_cdc -details` and DRC. Reject missing clocks, unconstrained internal endpoints, failing setup/hold/pulse width or unexplained critical CDC. Preserve source hashes and tool/IP versions with reports. A bitstream or synthesis estimate alone is insufficient.
5. If service timing passes, retain the clock and proceed to the separate real-ratio **six-tick READ2→resolve→COMMIT→rearm/publication** experiment with the chosen X1 protocol. Sweep phase, reset/Pause and worst placement; include actual game ratio in selected runs. Accelerate only broad regressions, with service-window assertions. If a service path fails, compare a staged same-clock version first; then a lower-frequency A / pixel B variant with explicit collision avoidance and CDC controls.

**Local limits:** `iverilog`, `verilator` and `vivado` were not found on this checkout's PATH. I2's earlier Icarus was unpacked under `/tmp`; that historical result is not a present installation. No local synthesis, simulation or board test was run for this note. Calculations above were independently recomputed with Python without importing or modifying the model. Toolchain instructions are [[README#Toolchain]] in `docs/README.md`; the course checkout remains read-only.

**Team confirmation genuinely needed:** adopt the practical clock default; settle render publication and X1/reset readiness through their separate research/experiments; clarify optional `locked/reset` use if robust lock-loss recovery is required. There is no reason to hold up the first same-clock timing slice while those interfaces remain open.
