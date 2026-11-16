# Board inputs and physical Scoreboard: provisional feasibility evidence

29 October 2026. Owner: **Alan**. Device: `xc7a100tcsg324-1` (Nexys A7-100T).
These are builder-owned feasibility checks, **not Roman's official §7 benches**, selected interfaces, or routed/board sign-off. Only this `io/` folder was written; Git and shared files were read-only.

## 1. Built interfaces, defaults and deviations

- `sync_2ff.sv`: provisional scalar `clk, rst, async_in -> sync_out`, two destination flip-flops with `ASYNC_REG=TRUE`, `SHREG_EXTRACT=NO`. Digital latency/reset tested; not metastability simulation.
- `btn_debounce.sv`: contract §4 ports **exactly** `clk, rst, btn[4:0], btn_pulse[4:0]`. Five independent synchronizers and stable-opposite-level counters. Directions retain §5 order UP/DOWN/LEFT/RIGHT/CENTER; no arbitration is performed here. One pulse on qualified press, none on release. Both edges require qualification. Reset clears state; a held button requalifies and emits once after reset.
- Provisional debounce parameters `CLK_HZ=83460000`, `DEBOUNCE_MS=10`: `(CLK_HZ/1000)*DEBOUNCE_MS = 834600` consecutive samples, 20-bit counter per button. Ten milliseconds is an engineering starting point to reject short contact excursions while adding modest latency, not a measured bound for this board's switches. Synchronizer adds about two fast cycles; taps shorter than qualification may be dropped intentionally. Parameters require positive debounce and clock with at least 1 computed cycle; integer division truncates sub-kHz frequency remainder.
- `seg7_driver.sv`: §4 describes behavior, **no fixed ports**. Proposed ports: `clk_pix, rst, points_p1[5:0], points_p2[5:0], lives_p1[1:0], lives_p2[1:0], page_lives -> seg[6:0], an[7:0]`. Points 0–63 includes the legal final-Step example 45; no goal clamp. Lives 0–3. These widths need owner agreement before integration. Page 0 is Points; 1 is Lives. Decimal leading zeros are retained. Left-to-right `P2nnP1nn` / `L2nnL1nn`, so P2 owns an[7:4]. The spaces in the written layout are visual separators, not extra digits.
- Board mapping: `seg[0]=a` through `seg[6]=g`, both segments and anodes active low. P and L glyphs follow `model/seg7.py`; conventional digit patterns are independently decoded by the bench. Digilent manual §9 says directional/center buttons are high when pressed, CPU_RESETN low when pressed; §9.1 establishes inverted anodes and cathodes. Source: [official manual, pp. 22–24](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf). No pin constraints or decimal-point output were added.
- Provisional scan parameters `CLK_HZ=83460000`, `DIGIT_HZ=1000` mean **each digit is revisited about 1 kHz**: `SLOT_CYCLES=10432`, about 124.994 us per slot, 0.999952 ms per frame (1000.048 Hz). Slot rate is about 8 kHz, not 1 kHz. All eight are scanned continuously, one enabled at any instant, with no deliberate blank slot. Inputs are captured together at the 7->0 frame boundary to prevent mixed-page banks; reset displays Points/zeros until the first complete boundary. Scan parameters require a positive rate and at least one clock per slot.
- `seg7_page.sv`: all ports provisional: `clk_juego, rst, new_match, pause -> page_lives`. `VIEW_TICKS=game_pkg::SCORE_VIEW_TICKS` (180), synchronous reset/new-Match selects Points and restarts the full interval. `RUN_DURING_PAUSE=1` follows `model/seg7.py` and the locked Physical Scoreboard rule. Setting it to 0 freezes the counter and page during Pause; both policies are tested. No phase input means Crash, ready wait and Match-over also continue cycling.
- Uses contract §1 synchronous active-high reset, no array ports, one signal per Player, `.sv` only. Assumes rst is already synchronized in each destination domain; external CPU_RESETN inversion/distribution belongs to game_top. Testbenches use XSim's common default time unit (observed ns, 1 ps resolution) because shared game_pkg has no explicit timescale. No shared package change was needed.
- Authority/defaults read: AGENTS and docs authority path, contract §§1/4/5/6, accepted ADR 0002, proposed ADRs 0003/0005, course handout, Coding Practices input/reset guidance, UART Input Path Research §6, agreed Scoreboard/Pause rules, `model/seg7.py` and `model/input_batch.py`. Fast debounce/scan use `clk_pix` (ADR 0003 item 3); page timer uses divided ~60 Hz `clk_juego` (ADR 0002). No change to UART receive or Python model.

### Crossings intentionally unselected

**Points, Lives and page: clk_juego -> clk_pix** must become one coherent snapshot **before** entering seg7_driver. Its frame registers only stage already-fast-domain data; they are not a CDC solution. One candidate is a bundled-data request/ack toggle snapshot: source holds all fields stable until destination acknowledgement; destination synchronizes the toggle then captures the stable bus, and publishes the complete snapshot. Reset epochs/readiness, source hold interval, physical bus constraints and overwrite/backpressure must be selected and verified with the composed schedule. Independent 2-FF synchronization of the payload bits is insufficient. ADR 0003 item 2 stays fully open; no crossing protocol has been implemented or approved here.

**Button events: clk_pix -> clk_juego** also remain unselected. A one-fast-cycle btn_pulse cannot be wired directly to the 60-Hz game clock. Candidate queued/batched transport must preserve sampled order and simultaneous masks, and apply the agreed priority/eligibility rules downstream. sync_2ff only synchronizes asynchronous external levels into clk_pix; it is not an event queue.

## 2. Source state and tool version

Vivado/XSim **2025.2**, XSim SW build **6299465**, IP build **6300035**. No generated IP is used by these modules. Source identification is by hashes (no Git mutations). SHA-256 paths below are relative to repository root:

```text
2bca91e505dcdddee166084c9c4ec726b3b19bb9e82591162ec5944b80dccffd  proyecto_final/prototypes/core_blocks/io/btn_debounce.sv
4d9abe52f170ec8bbb62e29c935a8d333a6ac0995c40ae0b772b9bada6b05b28  proyecto_final/prototypes/core_blocks/io/btn_debounce_tb.sv
2fe9251ad87817f019b9ac191dba3e2ed21de49de5d2bb7746362be652553b7c  proyecto_final/prototypes/core_blocks/io/seg7_driver.sv
8e93275efab194af44c27974516130ebf4ee144c6f38a9a4f152306035480509  proyecto_final/prototypes/core_blocks/io/seg7_driver_tb.sv
f9e185d29da21bfb7f14a20d5110ce5e5db01e906186d5d529ac5c508988653d  proyecto_final/prototypes/core_blocks/io/seg7_page.sv
4f0c518256c586b5750535580ee7a98468a4510fec23e4901d84d83a7f93895b  proyecto_final/prototypes/core_blocks/io/seg7_page_tb.sv
04cf5574fe15668663db68fc503b258dd3282d4d044b810118b0bed01bfa5e03  proyecto_final/prototypes/core_blocks/io/sync_2ff.sv
3cfc2a7365757e1021a74bf7177b7f15e52bbffeed75b812b16757b43ae316c7  proyecto_final/prototypes/core_blocks/io/sync_2ff_tb.sv
417637145b2417751b652174a9aaf937d5bbee1ac54f3aa15358a75ff99f0963  proyecto_final/prototypes/core_blocks/io/run_checks.sh
ae83f3c55a9219fa84c1967238514aa98d741cd6e088992439164c621f1375e8  proyecto_final/prototypes/core_blocks/game_pkg.sv
627611d98a9a60dccaa777c818410b1514b00d48e3338d419f1440ae93bfeeba  proyecto_final/prototypes/core_blocks/run_xsim.sh
62f4f4a160b9d8aa2bd7dd7683024d72b9e2d20bb2fb481683ce3bef45115ba0  proyecto_final/prototypes/core_blocks/run_synth.sh
```

## 3. Commands and observed results

From repository root, one-command reproduction (requires sandbox escalation because shared runners invoke `sudo -n /usr/local/sbin/cs256-vivado`):

```bash
bash proyecto_final/prototypes/core_blocks/io/run_checks.sh
```

The final successful constituent commands below use paths relative to `proyecto_final/` (run `cd proyecto_final` first). Log files are retained in `io/evidence/`:

```bash
prototypes/core_blocks/run_xsim.sh sync_2ff_tb prototypes/core_blocks/io/sync_2ff.sv prototypes/core_blocks/io/sync_2ff_tb.sv
```

Result: **PASS sync_2ff_tb**. Retained log: `evidence/sync_2ff_tb.txt`. Host artifacts: `/home/alan/.local/share/cs256-vivado/builds/core-sync_2ff_tb-20261029-000705-609729`.

```bash
prototypes/core_blocks/run_xsim.sh btn_debounce_tb prototypes/core_blocks/io/sync_2ff.sv prototypes/core_blocks/io/btn_debounce.sv prototypes/core_blocks/io/btn_debounce_tb.sv
```

Result: **PASS btn_debounce_tb**. Retained log: `evidence/btn_debounce_tb.txt`. Host artifacts: `/home/alan/.local/share/cs256-vivado/builds/core-btn_debounce_tb-20261029-000714-610069`.

```bash
prototypes/core_blocks/run_xsim.sh seg7_page_tb prototypes/core_blocks/io/seg7_page.sv prototypes/core_blocks/io/seg7_page_tb.sv
```

Result: **PASS seg7_page_tb**. Retained log: `evidence/seg7_page_tb.txt`. Host artifacts: `/home/alan/.local/share/cs256-vivado/builds/core-seg7_page_tb-20261029-000722-610574`.

```bash
prototypes/core_blocks/run_xsim.sh seg7_driver_tb prototypes/core_blocks/io/seg7_driver.sv prototypes/core_blocks/io/seg7_driver_tb.sv
```

Result: **PASS seg7_driver_tb**. Retained log: `evidence/seg7_driver_tb.txt`. Host artifacts: `/home/alan/.local/share/cs256-vivado/builds/core-seg7_driver_tb-20261029-000748-611568`.

```bash
prototypes/core_blocks/run_synth.sh -c clk 11.982 btn_debounce prototypes/core_blocks/io/sync_2ff.sv prototypes/core_blocks/io/btn_debounce.sv
```

Result: **synthesized btn_debounce**. Retained log: `evidence/btn_debounce_synth.txt`. Host artifacts: `/home/alan/.local/share/cs256-vivado/builds/core-synth-btn_debounce-20261029-000757-611909`.

```bash
prototypes/core_blocks/run_synth.sh -c clk_pix 11.982 seg7_driver prototypes/core_blocks/io/seg7_driver.sv
```

Result: **synthesized seg7_driver**. Retained log: `evidence/seg7_driver_synth.txt`. Host artifacts: `/home/alan/.local/share/cs256-vivado/builds/core-synth-seg7_driver-20261029-000758-612140`.

Simulation coverage:

- **PASS sync_2ff_tb:** two destination-edge level latency for rising/falling asynchronous changes, reset while transition is in flight. No analog/metastability claim.
- **PASS btn_debounce_tb:** bouncy press gives one pulse; long hold does not repeat; release bounce gives none; all five simultaneous buttons each produce one pulse; center re-press; reset during a held press. Pulse widths checked every cycle. Simulation uses `CLK_HZ=1000, DEBOUNCE_MS=10` -> 10 qualifying cycles, versus physical default 834600 (83460x fewer samples); synchronizer depth is unchanged. The test clock runs in simulator units; parameter scaling accelerates qualification rather than simulating ten physical milliseconds.
- **PASS seg7_page_tb:** 3-tick accelerated interval, new Match priority during Pause, both Pause policies, resume, reset, plus two complete default 180-tick intervals during Pause.
- **PASS seg7_driver_tb:** physical an/seg decoded back to eight characters, independent one-active-anode, scan order and two-cycle slot width assertions. Points 0, 9, 10, 45 on both Players; Lives 0, 1, 2, 3; both P/L pages and bank order. Large values are exercised on Points, since 9/10/45 are outside the Lives domain. Simulation uses CLK_HZ=16000, DIGIT_HZ=1000 -> 2 clocks/slot rather than physical default 10432 (5216x fewer).

Out-of-context synthesis, default parameters, period **11.982 ns**, no placement/routing:

| Top | LUT | FF | F7 mux | BRAM / distributed RAM | DSP | Latches | WNS ns | WHS ns |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| btn_debounce | 50 | 120 | 0 | 0 / 0 | 0 | 0 | +7.753 | +0.164 |
| seg7_driver | 42 | 30 | 2 | 0 / 0 | 0 | 0 | +7.758 | +0.338 |

TNS and THS are 0 in both; WPWS +5.491 ns in both. Full utilization, timing, latch and RAM text reports were copied into evidence with the top prefix. The RAM enumeration files are empty because no RAM matched. No clockless sequential endpoints (`no_clock=0`). **IO timing is not constrained**: no_input_delay 6 / no_output_delay 5 for debounce, 18 / 15 for display. In particular the display's final combinational decimal/glyph path to seg/an is not covered by WNS. No HD.CLK_SRC was supplied, so Vivado warns that clock delay/skew cannot be estimated in OOC mode. No-latches/no-RAM-match warnings correspond to the expected zero counts. XSim warns about launcher LIBRARY_PATH; all final elaborations/simulations succeed.

Development failures and corrections (earlier sources, not final failures): the first `bash .../io/run_checks.sh` used one too many parent directories and failed before invoking Vivado; its local cwd was corrected. Subsequent invocations stopped on XSim mixed-timescale errors (first module, then shared package, then local-timeunit/module mismatch); all explicit time units were removed to retain the shared package untouched. The next full invocation passed three benches and stopped on a bench-only width bug: `~an` was promoted in an unsized expression, causing a false one-hot failure at 6 ns. An explicitly 8-bit active mask corrected the assertion. The display bench and both synthesis commands above were then run individually. `run_checks.sh` now contains all six successful command forms, but the complete script was not re-run after the final bench-only correction. The final source hashes and per-command logs identify the validated state. Exact earlier host paths/error excerpts are retained in `evidence/development_failures.txt`. `bash -n io/run_checks.sh` also passed (using its repository-relative full path).

## 4. What the evidence shows and does not show

Shows feasible small resource counts for these two synthesized fast-domain blocks; no inferred latches/RAM/DSP; positive estimated internal register-path setup/hold margins; tested digital filtering, qualified one-pulse presses, periodic pages and physical display encoding. It does not establish routed timing, pin timing, CDC safety/MTBF, button bounce statistics, electrical brightness/ghosting, a functioning board, or official acceptance. No Icarus run (not installed), full integration, UART test, game Step-log replay, or CDC report was performed. No logic here changes the Step transaction, clocks or agreed game rules.

## 5. Findings, risks and open questions for Roman and Alan

1. **Pause wording:** contract §4 says Pause freezes game timers while display continues. The selected model and locked Physical Scoreboard text explicitly alternate pages during Pause. Default RUN_DURING_PAUSE=1 follows that stronger specific rule. Please clarify §4 that the page timer is excluded from frozen gameplay timers; alternate policy is available for evaluation, not adopted gameplay.
2. **CDC selection is still required** for the entire Points/Lives/page snapshot and for button events. Agree reset/readiness, latency and publication together with ADR 0003 item 2. Do not treat scan-frame capture or 2-FF payload bits as coherent CDC evidence.
3. **Approve provisional interfaces before dependent integration:** 6-bit Points/2-bit Lives, page select and new_match meanings, and 1 kHz per-digit refresh terminology. Contract gives btn_debounce ports but no debounce duration; 10 ms needs real-button playtesting. `clk` on btn_debounce means fast clk_pix under the working default, not the raw 100 MHz board clock.
4. **Board test:** simultaneous digit/segment combinational switching has no break-before-make interval; possible transient ghosting is unmeasured. Check brightness, polarity and ghosting on the actual board; any blanking extension must preserve the continuous Scoreboard requirement. Digit frame capture adds up to about 1 ms after receipt of an already-coherent snapshot.
5. Parameters assume positive legal configurations; invalid rates/zero periods are not guarded. Reset held press produces a newly qualified press afterward; downstream Start eligibility and stale-event handling remain integration obligations. No arbitrary timing exceptions were added.
6. No shared runner/package changes are requested. Suggested contract clarifications above are for the orchestrator/team; no contract or locked decision files were edited.
