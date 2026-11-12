# Qualified game-fast crossing: provisional evidence, 29 October 2026

Built by the orchestrator (Claude Opus 5.5) as the experiment proposed in
[CS-256 Game-Fast Crossing Research](../../../../docs/design/CS-256%20Game-Fast%20Crossing%20Research.md),
section 4 and gates 1, 2 and 4 of its section 5. It is input to the open
[ADR 0003](../../../../docs/adr/0003-step-transaction-mailbox-and-render-codes.md)
item 2. It is judged against
[ADR 0007](../../../../docs/adr/0007-configurable-step-interval.md) (accepted
29 October): the Step interval is configurable and evaluated at **8 to 10 game
ticks**, and six ticks is no longer mandatory.

Everything here is **provisional** under
[ADR 0005](../../../../docs/adr/0005-build-with-provisional-interfaces.md).
Passing these benches and builds is **evidence**, not team agreement, and the
benches are the builder's own checks, not the official benches of contract §7.
The defaults stay as ADR 0007 leaves them: the mailbox crossing at 6 ticks.
Nothing here changes an ADR, the contract or a decision file.

**Status.** Two fast-to-game crossings were built, simulated and routed.
Neither has run on the board.

| Variant | Parameters | Step | Vivado CDC, fast to game | Input reaches the game |
|---|---|---|---|---|
| Mailbox (current default) | `QUALIFIED = 0` | READ2 + COMMIT = 2 + 2 ticks; fits 6 | **21 Critical Unknown** (the quiet-window capture registers) | t + 2 |
| **Captured** (candidate for ADR 0007) | `QUALIFIED = 1, RSP_REG = 1` | 4 + 4 = **8 ticks**, no spare at 8, 2 spare at 10 | **0 Critical, no waiver**: every endpoint a recognized pattern (CDC-15, CDC-6, CDC-3) | t + 4 |
| Qualified | `QUALIFIED = 1, RSP_REG = 0` | 3 + 3 = 6 ticks, no spare | 5 Critical (CDC-1), covered by one scoped waiver | t + 4 |

All three match the model on all 12 M2 scenarios at 6 (mailbox, qualified), 8
and 10 ticks per Step. The captured variant is the clean candidate ADR 0007
asks for. The qualified variant is the "faster setting" evidence: six ticks
are reachable, but only with a waiver.

The probe files the research left in this folder (`clock_probe.tcl`,
`run_clock_probe.sh`, `cdc.rpt`, `clocks.rpt`, `interaction.rpt`,
`probe_*-properties.txt`) belong to the research note's clock-source study,
not to this experiment.

## 1. What was built

`QUALIFIED`, `RSP_REG` and `STEP_TICKS` are parameters of `game_core`,
`tron_system`, `tron_top` and the benches; `fast_core` takes `QUALIFIED`.

| Path | Mechanism | When the game uses it |
|---|---|---|
| Commands, game to fast | Unchanged: `cmd_*` change on a `clk_juego` edge and are latched after the 2-FF `tick_tgl` synchronizer | — |
| Responses, fast to game | Two-phase req/ack. `cmd_seq[0]` is the request toggle. `fast_core` publishes `rsp_code_*` as soon as the command finishes and echoes the toggle on `rsp_seq[0]`. It changes the codes only for the next command, which the game issues only after using them. `game_core` synchronizes only the toggle (`g_qualified.rsp_meta`/`rsp_sync`, `ASYNC_REG`). **Qualified:** `idle = rsp_sync == cmd_seq[0]` qualifies direct use of the held codes. **Captured:** a new synchronized toggle (`rsp_sync != rsp_tgl_q`) is the only enable of `code_q`, the game uses `code_q`, and `idle = rsp_tgl_q == cmd_seq[0]` | Qualified: READ2 at k resolves at **k + 3**, COMMIT done at **k + 6**. Captured: **k + 4** and **k + 8** |
| Input batches, fast to game | `batch_fifo.sv`: an 8-entry Gray-pointer FIFO, written on `batch_wr` (the cycle after `tick_seen`); the write pointer crosses through a 2-FF `ASYNC_REG` synchronizer. With `RD_REG = 1`, the default, each popped word goes into a game-side read register whose only enable is the synchronized not-empty | Batch closed at edge n is used at **n + 4** (mailbox: n + 2) |

Two changes apply to **every** variant. The mailbox replay and builds were
rerun to show they change nothing there:

- **Deferred launch.** A Step launch that finds the last COMMIT unfinished now
  waits with `step_cnt` held and sets the sticky `overrun`. Before, it
  launched over the open Step. ADR 0007 requires this: "Defer the launch and
  expose the deadline miss."
- **`phase` on a Step outcome is written, not held.** It becomes
  `crash ? G_CRASH : goal ? G_MATCH : G_PLAY`, because a READ2 is only open in
  `G_PLAY`. `resolve` also carries `DIRECT_ENABLE`. Both keep the response
  codes out of enable logic in the qualified variant.

**Model.** `Game(crossing=...)` in `prototipos/tron_fpga/model/game_top.py`
takes `"mailbox"`, `"qualified"` or `"captured"`. `CROSSING_STAGES` gives
their response and batch stages: (1, 1), (2, 3) and (3, 3).
`run(sc, crossing=..., step_ticks=...)` overrides the Step interval.
`make_events.py` writes `<name>.<crossing>-s<N>.log` for the variants in its
`VARIANTS` list. `run_game.sh` picks the reference log from `-g QUALIFIED`,
`RSP_REG` and `STEP_TICKS`. Mailbox mode at 6 ticks is unchanged: the
regenerated `.model.log` files are byte-identical.

| File | What it is |
|---|---|
| `batch_fifo.sv` | The input-batch FIFO above; `RD_REG = 0` gives the direct read of the first build (section 4) |
| `batch_fifo_tb.sv` | Protocol bench of the FIFO, independent of the game |
| `handshake_tb.sv` | Protocol bench of the response channel: `game_core` against a behavioural fast side; `RSP_REG` and `STEP` select the variant |
| `run_crossing.sh` | Both FIFO modes, and the handshake bench as qualified (6 ticks) and captured (8 ticks) |
| `evidence/` | Bench summaries, the builds' reports, the waiver, source hashes |

## 2. Source state and tools

Vivado/XSim 2025.2 in the `cs256-vivado-ubuntu24` container, part
`xc7a100tcsg324-1`. `evidence/sha256sum.txt` lists every changed or new
source; `../game/evidence/sha256sum.txt` lists the whole build.

`run_xsim.sh` now passes `--override_timeprecision`. Before, XSim rounded
every delay to 1 ns, and the benches here need sub-nanosecond offsets around
the clock edges. The 13 block benches, Roman's `vga_out_tb` and every
`tron_system_tb` configuration pass with it.

## 3. Commands and results

From the repository root, with sandbox escalation:

```bash
(cd prototipos/tron_fpga && python3 ../../proyecto_final/prototypes/core_blocks/game/make_events.py)
proyecto_final/prototypes/core_blocks/crossing/run_crossing.sh
proyecto_final/prototypes/core_blocks/game/run_game.sh [-g QUALIFIED=1 [-g RSP_REG=1]] [-g STEP_TICKS=8|10] [-g N=.. -g PHASE=.. -g WINDOW=..]
proyecto_final/prototypes/core_blocks/game/run_system.sh [the same -g options]
proyecto_final/prototypes/core_blocks/game/run_tron.sh [mailbox|qualified|captured] [STEP_TICKS]
```

### Gate 1: protocol benches (`run_crossing.sh`): PASS

`handshake_tb` runs `game_core` (`QUALIFIED = 1`) against a behavioural fast
side. While a command is in service, that side writes random junk to
`rsp_code_*` every 7 ns. It publishes after a random delay: inside the tick;
0.05–50 ns before the next game edge; 0.05–50 ns after it; or 1–2.5 ticks
later. When it publishes less than 1 ns before an edge, half the time it shows
the toggle only after that edge. That is the digital stand-in for a first
synchronizer stage that resolves late. Turns are random and, in phase B, so is
Pause. The bench checks:

- C1: every resolved Step used its own READ2's final codes, stable for more
  than two game periods.
- C2: a command is issued only when the previous one was answered.
- C3: each READ2 resolves exactly once.
- C4: the latency is exactly e1 + 2 + `RSP_REG` edges, where e1 is the first
  edge after the toggle became visible, unless Pause intervened.
- C5: launch cadence (`STEP` exactly in phase A, at least `STEP` in phase B).

| Result | Qualified, 6 ticks | Captured, 8 ticks |
|---|---|---|
| Steps resolved (600 in phase A) | 3006 | 3005 |
| Commands; junk writes on the response bus, none ever used | 6195; 3 379 544 | 6191; 3 378 729 |
| Publications 0.05–50 ns before / after a game edge; over a tick late | 758 / 486 / 228 | 758 / 486 / 228 |
| Late synchronizer resolutions injected | 7 | 7 |
| READ2 latency | k + 3: 2634; k + 4: 291; k + 5: 36; k + 7: 1. **Phase A: all k + 3** | k + 4: 2630; k + 5: 286; k + 6: 39. **Phase A: all k + 4** |
| Deferred launches (all in phase B) | 702 edges | 703 edges |

In both runs no command overlapped another.

`batch_fifo_tb` writes 9-bit random words from a 100 MHz clock into a reader
clocked at 1 / 10 006.6 ns. The fractional period makes their phases drift. It
checks:

- F1: exactly the accepted words, in order, once each.
- F2: zero output when not valid.
- F3: exact latency.
- F4: one Gray bit per pointer update.
- F5: a 12-word burst into 8 entries sets overflow and drops exactly 4.

| Mode | Accepted = read | Steady state (write a few cycles after read edge n) | Writes within 1 ns of a read edge |
|---|---|---|---|
| `RD_REG = 1` | 6008 = 6008, 4 dropped in the burst | all 2000 at n + 4 | 2 |
| `RD_REG = 0` | 6008 = 6008, 4 dropped in the burst | all 2000 at n + 3 | 2 |

Artifacts: `evidence/protocol-benches.txt`.

### Gate 2: composed schedule (`run_game.sh`): 8 × 12/12 MATCH

The full HDL game matches the model's Step log for the same crossing and
interval, in every field, `tick` included. The bench fails on any deferred
launch (`overrun`), late publish or FIFO overflow, and none occurred. So every
schedule held its cadence for every Step, including the two with no spare
tick (qualified at 6, captured at 8).

| Crossing | 6 ticks | 8 ticks | 10 ticks |
|---|---|---|---|
| Mailbox | 12/12, 3261 lines (`.model.log`) | 12/12, 1582 | 12/12, 1448 |
| Qualified | 12/12, 2089 | 12/12, 1547 | 12/12, 1363 |
| Captured | — (needs 8) | **12/12, 1597** | **12/12, 1337** |

The qualified variant at 6 ticks was also replayed at three more clock
settings: N = 12000, 16384, 20011 fast cycles per tick, with PHASE = 5, 1777,
4999 ns. All match. Artifacts: `evidence/game_tb-runs.txt`.

`tron_system_tb` (43 pin-level checks) passes for the mailbox and qualified
variants at 6 ticks and the captured variant at 8 and 10
(`evidence/tron_system_tb-runs.txt`). Three of its waits assumed 6 ticks and
now follow `STEP_TICKS`. `pause(1)` now waits for a frame start before sprite
checks: drawcon latches the Bike positions once per frame, about 35 game
ticks at the bench's scaling, and at 8 ticks the last Step before Pause landed
after that latch.

**How the timing shift plays out.** Each variant's logs differ from the
mailbox logs by more than `tick`. Start, PREPARE and the first Step finish
later, so inputs that the scenarios address to absolute ticks arrive in other
phases. In 02, for example, a Turn at tick 6 arrives while the Round is still
preparing and is dropped. The head-on and reversal scenarios (04, 05, 06) keep
the same outcomes. To compare variants on gameplay, rewrite the scenarios
relative to the release of play.

### Gate 4: routed builds (`run_tron.sh`): BUILD_COMPLETE

| | Mailbox, 6 | Qualified, 6, first build (`RD_REG = 0`) | Qualified, 6 | **Captured, 8** |
|---|---|---|---|---|
| Host folder (`/home/alan/.local/share/cs256-vivado/builds/`) | `tron-20261029-233130-2009133` | `tron-qualified-20261029-185917-1261465` | `tron-qualified-20261029-233200-2009520` | `tron-captured-s8-20261029-232239-1926071` |
| WNS / WHS / WPWS (ns) | +0.296 / +0.059 / +0.027 | +0.167 / +0.059 / +0.027 | +0.133 / +0.055 / +0.027 | **+0.315 / +0.085 / +0.027** |
| `clk_pix` → `clk_juego` slack, endpoints | +10.64 ns, 21 | — | +4.53 ns, 102 | +9.39 ns, 22 |
| LUTs / registers / LUTRAM | 1052 / 973 / 0 | 1019 / 982 / 8 | 1071 / 992 / 8 | 1038 / 1001 / 8 |
| CDC Critical, fast to game | **21** (CDC-1 1 row, CDC-4 5 rows) | **121** (CDC-1) | **5** (CDC-1); 0 after the waiver | **0** |
| CDC-15 / CDC-6 / CDC-3 (whole design) | 150 / 0 / 13 | 364 / 2 / 14 | 242 / 2 / 14 | 167 / 2 / 14 |
| Methodology | SYNTH-6, TIMING-9 | SYNTH-6, TIMING-9 | SYNTH-6, TIMING-9 (written before the waiver) | **SYNTH-6 only** |
| Bus skew, Gray pointers (11.982 ns bound) | — | — | met, slack 11.26 and 11.00 ns | met, slack 11.36 and 11.01 ns |
| Bitstream SHA-256 | `3eaa45a2…d032171b` (`../game/evidence/bitstream.sha256`) | — | `617736d0…fa70a98b` (`evidence/qualified-bitstream.sha256`) | `b62d008b…6ec6836` (`evidence/captured-s8-bitstream.sha256`) |

Captured, 8 ticks: the 22 fast-to-game endpoints are 8 `code_q` and 9 FIFO
read-register bits (CDC-15), the Gray write pointer (CDC-6), and the
response-toggle synchronizer (CDC-3). It has no waiver file.

In every build:

- `check_timing`: 0 unclocked, 0 unconstrained internal endpoints, 0 loops,
  and 10 inputs without delay (the asynchronous pins, false-pathed only to
  their `ASYNC_REG` first stages).
- No timing exceptions are ignored.
- DRC shows no violations.
- The worst setup path is the VGA pad path (`hcnt` → drawcon → `vga_*`), not
  the crossing.

**Waiver (qualified variant only).** It is scoped and count-checked.
`run_tron.tcl` enumerates the 8 `rsp_code` source flops and the 5 destination
D pins, and fails if the counts differ. It writes `crossing-waivers.xdc` and
keeps both the unwaived reports (`evidence/qualified-report_cdc*.rpt`) and the
waived ones (`qualified-report_cdc_waived*.rpt`). The 5 endpoints are
`phase[2:0]` and `score_unit.result[1:0]`. A response code selects their next
value, but each is written by several game-side conditions, so synthesis
cannot put the synchronized `resolve` alone on its enable. The protocol
bench's C1 is the evidence that those values are taken only under the
synchronized qualification. The captured variant removes the need for it.

**Implementation strategy.** All builds now use `Performance_Explore`. With
the default strategy, the VGA pad path flipped between pass and fail across
otherwise identical runs: mailbox −0.361 ns and qualified −0.094 ns, against
+0.202 and +0.167 ns earlier. This is the combinational `vga_out` output
budget (`../video/FINDINGS.md`), not the crossing.

## 4. What the evidence shows, and what it does not

- **ADR 0007's 8-tick setting has a sign-off-clean crossing.** The captured
  variant fills 8 ticks exactly with READ2 + COMMIT (4 + 4), and leaves 2
  spare at 10. It routes with no unknown CDC and no waiver. Every game
  register a fast-domain word reaches is a capture register enabled only by a
  synchronizer output. This is the "explicit capture and processing stages"
  that ADR 0007 prefers over optimizing every edge for six ticks.
- **Six ticks is reachable, at a price.** The qualified variant holds 6 ticks
  with no spare. In the composed game and in 600 phase-A Steps no launch
  waited. It needs the 5-endpoint waiver. ADR 0007 asks for "appropriate
  scheduling margin" before choosing a faster setting, and 6 ticks has none.
- **Missed deadlines are safe.** When a service misses its edge, the next
  launch waits one tick and `overrun` records it. The command channel never
  overlaps, and no unqualified code is used: C1–C3 held across 700 deferred
  edges.
- **Direct use of a crossed word is not enough for Vivado.** The first build
  read the FIFO combinationally. Its Start and Turn bits reach the
  `prepare`/`launch` enable logic all over `game_core`, which made 121
  endpoints CDC-1 (`evidence/iteration1-*`). A game-side read register, the
  usual FIFO pattern, cleared all of them for one tick of latency. Used
  directly, the response codes were recognized as CDC-15 at 81 endpoints and
  CDC-1 at 6 (`phase`, `result`, `crashed_p2`). After the `phase` rewrite and
  `DIRECT_ENABLE`, `phase` and `result` (5 endpoints) remained. Capturing the
  codes first removes them all.
- **Latency cost.** An input reaches the game 2 ticks later than with the
  mailbox (+33 ms), in both new variants. A Step outcome comes 1 tick later in
  the qualified variant and 2 in the captured one. At 8 ticks per Step
  (7.5 Cells/s), a Turn must be in a batch about 4 ticks before a launch to
  count. ADR 0007 leaves this to playtesting.
- **Cost in logic:** small. The captured variant at 8 ticks uses 1038 LUTs
  and 1001 registers (1.64 % and 0.79 % of the device).
- **Not shown:**
  - MTBF in years (no 7-series data, as the research found).
  - Behaviour on the board, and how 7.5 or 6 Cells/s feels.
  - A one-sided reset (both domains still reset together through
    `reset_stretch`).
  - Pause and reset at every transaction phase in the composed system; the
    handshake bench covers Pause only on the response channel.
  - Whether the TAs accept the qualified variant's waiver.

## 5. Open questions for Roman and Alan

- **Adopt the captured crossing at 8 ticks** as the ADR 0003 item 2 proposal
  under ADR 0007? That means editing ADR 0003 item 2 and the contract's
  crossing section. It also means making `Game(crossing="captured",
  step_ticks=8)` the new Step-log reference and the `tron_top` defaults
  `QUALIFIED = 1, RSP_REG = 1, STEP_TICKS = 8`. Keep the mailbox build for the
  19 November pre-demo if the switch is not reviewed by then.
- 8 or 10 ticks? Both are verified here; a board playtest should choose.
- Is +2 ticks of input latency acceptable in that playtest?
- Should the M2 scenarios be rewritten relative to the release of play, so the
  same inputs mean the same gameplay under every crossing and interval?
