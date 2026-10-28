---
schema_version: 1
id: cs256-tron-game-model-hardware-map-20261027
title: CS-256 Tron Game Model Hardware Map
type: note
subject: CS-256
status: draft
created_at: "2026-10-27T12:00:00"
updated_at: "2026-10-27T12:00:00"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[0002-follow-ta-divided-game-clock]]"
  - "[[CS-256 Official FPGA Coding Practices]]"
  - "[[CS-256 Tron Opus 5.5 Architecture and Integration Review]]"
review_status: unreviewed
tags:
  - fpga
  - tron
  - game-model
---

# CS-256 Tron Game Model Hardware Map

The Python model in `prototipos/tron_fpga/model/` now has one module per planned HDL block. Each module models candidate registers and interfaces; the two simulated clock domains meet at an explicit mailbox. Hardware ports and timing still require definition and verification. This note maps each module to its HDL block and gives the tick-level timing. It also lists the interface choices the model had to make where the agreement leaves the design open.

**Status.** The rules are the [[CS-256 Tron Agreed Specification 2026-10-20]]. The slow/fast boundary (X1), the input batch and the Step transaction follow the recommended architecture in [[CS-256 Tron Opus 5.5 Architecture and Integration Review#5. Recommended architecture]]. That architecture is a **proposal**: Roman and Alan have not adopted it, and the review's own [[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits|adoption limits]] apply. Passing Python tests show that this model is self-consistent and follows the agreed rules. They are not HDL, timing, CDC or board evidence. Once the team decides, record the choices in a new ADR (0003 onward) and in the interface contract.

[ADR 0004](../adr/0004-shared-headless-model-base.md) selects this headless model as the shared base. That decision does not accept the proposed service, input or render interfaces below.

## Module map

| Model file | Planned HDL block | Domain | Owner | Registers it owns |
|---|---|---|---|---|
| `params.py` | `game_pkg.sv` | — | both | Constants; names match the contract's `game_pkg`, checked by a test |
| `turn_unit.py` | `turn_unit` ×2 (G1) | game | Roman | `heading`, `pending` |
| `step_unit.py` | `step_unit` and combinational `step_resolve` (G1/G2) | game | Roman | `head[2]`, `targets[2]`, `state` (IDLE, READ, COMMIT), shown Headings |
| `game_top.py` (match part) | `match_ctrl` (G3) | game | Alan | `phase`, `prep_match`, `step_cnt`, `phase_ticks`, `goal`, round and Step counters, free-running `tick_cnt` |
| `score_unit.py` | `score_unit` (G5) | game | Alan | `points[2]` (6 bits), `lives[2]` (2 bits), `result` |
| `seg7.py` | page timer (game) and `seg7_driver` with the P/L glyph decoder (fast) | both | Alan | `page`, `page_cnt` |
| `mailbox.py` | `cmd_mailbox` (X1) | both | Alan; Roman writes the official testbench | Slow: `cmd` (op, arguments, `seq`), `rsp_cap`. Fast: `fast_seq`, `rsp_bus` |
| `arena_ctrl.py` | `arena_ctrl` (A2) | fast | Alan | Port A, `slots[3]`, LFSR |
| `reward_place.py`, `lfsr.py` | placement search inside `arena_ctrl` (G4) | fast | Alan | LFSR state |
| `arena_map.py` | `arena_map`, 8192 × 4-bit BRAM (A1) | fast | Alan | Memory |
| `input_batch.py` | `btn_debounce`, `uart_rx` decoder, `input_batch` (I1–I3) | fast | Alan | Axis latches `{V, H}` per Player, Start flag |
| `game_top.py` (wiring) | `game_top` | both | Alan | 2-FF switch synchronizers, capture of the input batch |
| `juego/render.py` (viewer) | `drawcon`, sprite ROMs | fast | Roman | Reads the render snapshot and Arena port B |

`game_top.Game.tick()` is one tick of the ~60 Hz game clock. First the fast domain takes the inputs that arrived during the tick. Then every game-domain register updates from values that were stable before the edge. Finally the fast domain does its work after the tick strobe (`tick_seen`): it runs a new command, publishes the response and the input batch, and latches the render snapshot.

## Tick timing

Times are game-clock edges. An input given with tick *t* means it arrived during that tick.

| Event | Edge | Why |
|---|---|---|
| Button, UART byte or switch change during tick *t* | applied at *t* + 2 | Published at *t*'s strobe and captured at *t* + 1. SW0 and `{SW15, SW14}` pass a 2-FF synchronizer, so Pause and inputs pressed in the same tick stay aligned |
| Start accepted at edge *s* | PREPARE issued at *s*, done seen at *s* + 2 | Clear, both heads, reseed for a new Match, three Rewards. The Round is released (new Match) or waits in G_READY (next Round) only after that |
| Release at edge *r* | first launch at *r* + `STEP_TICKS` | `step_cnt` counts 0 to 5 |
| Launch at edge *k* | READ2 issued at *k* | Headings take the Pending Turns at launch, so later batches are judged against the new Heading (review F3) |
| Outcome | *k* + 2 (`STEP_LATENCY`) | Codes captured at *k* + 1. New heads, Crash flags, Points, Lives, result and phase all register on the same edge; COMMIT is issued |
| COMMIT done | seen at *k* + 4 | The next launch needs it, so `MIN_STEP_TICKS` = 4. The agreed 6 leaves two ticks of slack |
| Crash display | from the outcome edge, `CRASH_TICKS` edges | Then PREPARE for the next Round, or G_MATCH if the Match is decided |

With the agreed values, a Turn has to arrive at least two ticks before the launch edge, or it applies at the next Step. The per-Step state log is unaffected, but the first HDL build must reproduce these edges exactly for the logs to match.

## Choices the model makes (proposals)

| Item | Model behavior | Source |
|---|---|---|
| Step transaction | READ2, then `step_resolve` in the game domain, then COMMIT with the writes and collected slots | Review D2-A |
| Crossing | Stable-payload mailbox, one command outstanding, `seq` per command. **Every** fast-to-slow bus, including the input batch, goes through one capture register. That gives 2-tick input latency, where the review applied the batch one tick earlier | Review D3-A, adjusted |
| Inputs | Per-tick axis latches; P1 from button samples with UP > DOWN and RIGHT > LEFT inside one sample; P2 from UART bytes `w a s d` in either case. An event is latched only if the render snapshot the fast domain holds when it arrives shows the right phase, unpaused: direction events in G_PLAY, Start in G_IDLE, G_READY or G_MATCH. The game checks the phase again when it applies the batch | Review D4-A, plus arrival gating (this model) |
| UART Start | `0x20` and `0x0D`; `0x0A` and all other bytes ignored | Review E2 |
| Preparation state | `G_PREP = 5`, added to the contract's proposed states, with a `prep_match` bit choosing G_PLAY or G_READY | This model |
| Start | Accepted only in G_IDLE, G_READY or G_MATCH, not paused, with the mailbox idle; otherwise dropped. The arrival gate drops a Start pressed during the Crash display, even on its last tick, and Turns pressed in the ready wait. Without it, the 2-tick pipeline would carry them into the next phase | Review D5(i) |
| Pause | Holds launches, outcomes and game timers. An issued COMMIT still completes; a Step waiting for its codes resolves after resuming. The Scoreboard page timer keeps running | Review D5(ii) |
| Reset | Both domains reset together and the controller clears to Walls; no Bikes or Rewards until Start. The HDL also needs a stretched reset or an epoch tag, which the model does not show | Review D5(iii), F7 |
| Scoreboard while idle | Points 00 and Lives 03 | Review D5(iv) |
| Reward generator | 32-bit LFSR advanced only per draw; 64 draws, then a wrapping scan; replacements in ascending slot order inside COMMIT. Seed: reset value `LFSR_SEED`; at each new Match, either reload it (fixed-seed parameter) or XOR in the game-domain tick counter captured at Start | Review E1, with the game-tick counter in place of a pixel-clock counter so that the model can reproduce it |
| Crash code 6 | Not written; a crashed Bike's head Cell keeps its head code | This model, against review E6 |
| Displayed Heading | The Heading of the last committed Step, not the launched one, so a sprite turns when it moves | Review §5.7 |
| Start Cells | A parameter (`starts`), the agreed Cells by default. Scenario 4 moves P2 to (58,27) for a same-Cell Head-on | Testbench parameter |
| Seed capture | PREPARE carries `tick_cnt` as it was before the Start edge, as a capture register would | This model |
| Playtest speed | A changed `step_ticks` takes effect at the next launch (`step_period` register); the first build keeps 6 | Viewer tuning only |

## What the model does not show

- Per-cycle behavior: BRAM and ROM latency, synchronizer metastability, debounce counters, UART bit timing, the 7-segment scan rate and drawcon's pipeline. `arena_ctrl` only counts the cycles a command would take, and flags any command longer than `SERVICE_WINDOW`.
- The vertical-blanking commit of the render snapshot. The PC draws one frame per tick, so the snapshot latched after each edge is the one drawn.
- Render coherence when Arena writes land mid-frame, which the review's adoption limits leave open.

## Verification

- `tests/test_model.py` contains block tests for `step_resolve`, `turn_unit`, `input_batch`, the mailbox, `arena_ctrl` and the Scoreboard, plus system tests of the rules through `Game.tick`.
- `scenarios/` holds the 12 M2 scenarios of [[CS-256 Tron Development Plan#Step-log comparison]] as tick-indexed board inputs, each with the model's expected Step log. `model/scenario.py` describes the formats, and `model/steplog.py` the log fields. `tools/steplog_diff.py` reports the first differing line and field. An HDL testbench replays the same file and writes the same log with `$fwrite`.
- `tests/test_scenarios.py` replays every scenario against its log and checks that each scenario still covers its case.

## Decisions needed before HDL

1. Adopt or change D2, D3 and D4 (the Step transaction, the crossing and the input batch), including where the 2-tick input latency comes from.
2. Add `G_PREP` to the contract's states, or fold preparation into the other states.
3. Accept or change the LFSR, seed capture and placement schedule (E1). The model and the HDL must use the same ones.
4. Choose whether a Crash writes code 6 (E6), and how Start behaves while the mailbox is busy.

Record the outcomes in ADR 0003 and the contract, then update `params.py` and the scenarios to match.
