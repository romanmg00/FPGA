---
title: CS-256 Match Lifecycle and Scoreboard Plan
status: draft
created_at: "2026-11-17"
issue: https://github.com/romanmg00/FPGA/issues/33
---

# CS-256 Match Lifecycle and Scoreboard Plan

Plan for stages 3 and 4 of [issue #33](https://github.com/romanmg00/FPGA/issues/33): the Match
lifecycle without Rewards (G3/G5, README Paso 7c) and the Physical Scoreboard in `game_top`
(Paso 7d). Stages 1–2 (`sevenseg`, `multidigit`, `seg7_view`, `seg7_driver`) are on `main`
(PR #34). Branch `feat/match-scoreboard`, from `main` at `cd430d0`. This is a plan, not evidence:
nothing here is implemented yet.

## 1. Authority and inputs

- [Agreed Specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md):
  *Match, Points Goal and scoring*, *Start, Crash display, Pause and reset*, *Physical
  Scoreboard*. [ADR 0008](../adr/0008-scoreboard-goal-page-before-a-match.md) (Goal view),
  [ADR 0011](../adr/0011-a-crash-stops-both-bikes.md) (proposed: a Crash stops both Bikes; the
  survivor still gets +3), [ADR 0006](../adr/0006-single-wizard-counter-game-clock-and-handout-as-guidance.md)
  (no new clocks), [ADR 0010](../adr/0010-bikes-sliding-between-cells.md) (`STEP_TICKS` = 8),
  [ADR 0009](../adr/0009-handout-names-and-where-proyecto-final-departs.md) (departures table).
- [Contract](../../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md) §1,
  §2, §3 *Arena y memoria*, §4 (*Estados de la partida*, `seg7_view`, `seg7_driver`), §5.
- Behaviour references, never copied: `proyecto_final/prototypes/core_blocks/game/game_core.sv`
  (match control), `core_blocks/score/score_unit.sv`, `prototipos/tron_fpga/model/game_top.py`
  and `score_unit.py`.

## 2. Decisions taken with Alan (16–17 November 2026)

| # | Point | Decision |
|---|---|---|
| 1 | Where the Match lifecycle lives | New Alan modules in `game_top` **above** `position_logic`. Roman's `round_fsm` stays in use and unchanged; his files change as little as possible, and those changes are proposed to him in a GitHub issue (like #38) for him to make |
| 2 | Per-Bike Crash signals | `position_logic` outputs the `crash1`/`crash2` it already computes |
| 3 | Points without Rewards | No reward inputs. The Goal rules go on the deferred list (they cannot be reached without Rewards) |
| 4 | Pause (SW0) | Implemented, in a few lines |
| 5 | Crossing to `clk_pix` | The issue #30 pattern, one way (section 6) |
| 6 | Ports and pins | `sw[15:0]`, `seg[6:0]`, `dp`, `an[7:0]` |
| – | Style | Course style. Moore FSM written like `round_fsm` and lecture 12 (*More complex FSMs*): state register, `always_comb` `case` for the next state, `assign` per output. States are **literal 3-bit codes with a comment** (the lecture's "encode the states" form), no `enum`, no `localparam` table |

## 3. Why no Goal can be reached in this build

Without Rewards a Player scores only the +3 Survival Bonus, earned when the **other** Player
crashes alone. The other Player has 3 Lives and the Match ends when they reach 0, so a Player
gets at most 3 bonuses: 9 Points, below the lowest Goal (10). Every Match therefore ends by
Lives: one Player at 0 Lives loses; both at 0 in the same Step means higher Points wins and
equal Points is a Draw (for example a Head-on Crash at 1 Life each).

When both lose their last Life in the same Step, their Points are always equal without
Rewards: each Player lost 2 Lives before that Step, in Crashes alone (`a` for P1, `c` for P2)
or together (`b`), so `a + b = c + b = 2`, and each scored 3 per Crash of the other alone
(`3c` and `3a`). That Step is therefore always a Draw in this build; `score_unit` still compares
the Points, and `score_unit_tb` sets unequal Points with `force` to check that branch.

## 4. Architecture

```text
                    clk_juego (~60 Hz)                                      clk_pix (83.46 MHz)
 BTNC --sync--> match_fsm --start_go--> position_logic.btn[4]
                   |  |  \--restart---> position_logic.rst (with rst_juego)
                   |  |  /--crash_done-- position_logic          (Roman's round_fsm still inside)
                   |  \---c = crash1|crash2 <-- position_logic
 SW0 --sync--> pause --> match_fsm, position_logic
                   |
                   +--new_match--> score_unit --points, lives--+
                   |                    \--match_over--> match_fsm, position_logic
                   +--new_match, waiting--> seg7_view --view--+
 SW15,SW14 --sync--> goal_sel --------------------------------+--> seg7_link ===> seg7_driver --> seg, an, dp
```

`position_logic`, `round_fsm`, `bike_move`, `arena_link`, `arena_ctrl`, `drawcon` keep their
roles. `match_fsm` never duplicates `round_fsm`: it decides **when** a Start reaches
`position_logic`, adds the Match around the Rounds, and follows `round_fsm`'s Crash timer
through `crash_done`, so there is one 2-second timer.

### 4.1 `match_fsm.sv` (G3, Alan, new)

Moore FSM on `clk_juego`. Inputs: `s` (synchronized BTNC level), `c` (`crash1 || crash2`),
`t` (`crash_done` from `position_logic`), `m` (`match_over` from `score_unit`), `p` (synchronized
SW0). A press is `s && !s_q`, with `s_q` the level one tick earlier, so a held button never
starts anything ("fresh Start"). `s_q` tracks `s` on every tick, paused or not, and **resets to
1**; BTNC's `sync_2ff` in `game_top` is **never reset** (like the crossing toggles), so `s`
follows the pin through CPU_RESETN. A button held through a reset is therefore treated as held:
it must be released and pressed again (the same rule as `round_fsm`'s `s_release`).

| Code | State | Meaning | Next state (only while `p` = 0) |
|---|---|---|---|
| `3'd0` | `G_IDLE` | Waiting for the first Match (power-up, CPU_RESETN) | press → `3'd5` |
| `3'd1` | `G_PLAY` | Round running | c → `3'd2` |
| `3'd2` | `G_CRASH` | Crash display, 2 s (`round_fsm`'s timer) | t → m ? `3'd4` : `3'd3` |
| `3'd3` | `G_READY` | Waiting for Start of the next Round | press → `3'd7` |
| `3'd4` | `G_MATCH` | Match over, final Points and Lives kept | press → `3'd5` |
| `3'd5` | `G_NEW` | New Match, one tick | → `3'd6` |
| `3'd6` | `G_GO` | `round_fsm` leaves `s_release`, one tick | → `3'd7` |
| `3'd7` | `G_START` | Start pulse to `round_fsm`, one tick | → `3'd1` |

Codes 0–4 are the contract §4 `G_*` values. Pause freezes the FSM: the state register loads
`nst` only while `p` = 0 (`if (rst) st <= 3'd0; else if (!p) st <= nst;`), and the three action
outputs are 0 while `p` = 1, so a state held by Pause does nothing. Outputs, one `assign` each:

| Output | High in | Goes to |
|---|---|---|
| `waiting` | `G_IDLE`, `G_MATCH` | `seg7_view` (Goal view joins, ADR 0008) |
| `new_match` | `G_NEW` and not `p` | `score_unit` (Points 0, Lives 3, result none), `seg7_view` (Points view) |
| `restart` | `G_NEW` and not `p` | `position_logic.rst` = `rst_juego \|\| restart`: `round_fsm` to `s_release`, Bikes to their starts, step counters cleared |
| `start_go` | `G_START` and not `p` | `position_logic.btn[4]`: `round_fsm` `s_wait` → `s_run` |

Why three one-tick states: after `restart`, `round_fsm` is in `s_release`, which needs one tick
with Start low (`G_GO`) before `s_wait` takes the pulse (`G_START`). From `G_READY`, `round_fsm`
is already in `s_wait` (it passed `s_release` with `start_go` low), so the pulse goes directly.
While paused nothing reaches `round_fsm`: `start_go` is 0, no Step means no Crash, and
`crash_done` holds with the Crash timer. The only change it can make is `s_release` → `s_wait`
(Start is low), which changes no game state.

Alignment with `round_fsm` (checked in `match_tb`, section 7):

| `match_fsm` | `round_fsm` during that tick | `load` | `run` |
|---|---|---|---|
| `G_IDLE` | `s_release` on the first tick after reset, then `s_wait` | 1 | 0 |
| `G_READY` | `s_release` on its first tick, then `s_wait` | 1 | 0 |
| `G_NEW` | `s_wait` (from `G_IDLE`) or `s_crash` (from `G_MATCH`); `restart` resets it at the end of the tick | 1 or 0 | 0 |
| `G_GO` | `s_release` (Start low, so it moves to `s_wait`); `s_wait` if Pause held `G_GO` | 1 | 0 |
| `G_START` | `s_wait` (Start high, so it moves to `s_run`) | 1 | 0 |
| `G_PLAY` | `s_run` | 0 | 1 |
| `G_CRASH`, `G_MATCH` | `s_crash` | 0 | 0 |

A press in `G_READY` is seen at the earliest on its first tick, so `G_START` comes one tick
later, when `round_fsm` is already in `s_wait`.

In `G_MATCH`, `round_fsm` stays in `s_crash` (its `t` is gated by `match_over`, section 5), so
`load` stays 0: the Arena is not prepared and the Bikes stay where they crashed ("Do not prepare
another Round"). The new Match's `restart` makes `load` rise, and `arena_link` sends the Prepare
one tick later, as for any Round.

### 4.2 `score_unit.sv` (G5, Alan, new)

On `clk_juego`. Inputs `rst`, `new_match`, `crash1`, `crash2`. Outputs `points_p1/p2` (6 bits:
45 = 39 + 3 + 3 fits, for G4), `lives_p1/p2` (2 bits), `result` (2 bits: 0 none, 1 P1 wins,
2 P2 wins, 3 Draw) and `match_over = (result != 0)`.

- `rst` or `new_match`: Points 0, Lives 3, result 0 (the Scoreboard shows `00` and `03` before
  the first Match, as the model).
- On a Crash Step (`crash1 || crash2`) while result is 0, in one edge: each crashed Bike loses a
  Life; if exactly one crashed, the other gets +3 (ADR 0011: it did not move, it still gets it);
  then victory on the new values: both at 0 Lives → higher Points, equal → Draw; one at 0 → the
  other wins.
- After a result, nothing changes until `new_match` (final values kept).
- Written with an `always_comb` for the next values and one `always_ff`; no functions.

### 4.3 `seg7_link.sv` (Alan, new): the crossing

```text
clk_juego:  values_juego <= {points_p1, points_p2, lives_p1, lives_p2, view, goal_sel};  tick_toggle <= ~tick_toggle;   (every tick)
clk_pix:    tick_toggle_pix = sync_2ff(tick_toggle);  tick_toggle_last <= tick_toggle_pix;
            new_tick = (tick_toggle_pix != tick_toggle_last);  if (new_tick) values_pix <= values_juego;
```

20 bits, one way, every tick. It is the answer half of `arena_ctrl` → `arena_link` (held data, a
toggle through `sync_2ff`, copy when the synchronized toggle changes). No acknowledgement is
needed: `values_juego` changes only at `clk_juego` edges, 1,390,932 `clk_pix` cycles apart, and the copy
is made 3 cycles after the toggle. `tick_toggle`, the synchronizer and `tick_toggle_last` are never reset
(configuration value 0), as in PR #40; `values_juego` follows its sources, which are reset. `goal_sel`
travels in the bundle, so the Goal view's number and the view choice come from the same
`clk_juego` switches. Alternatives rejected: no crossing (an unconstrained CDC, against contract
§1); `seg7_driver` in `clk_juego` (a 60 Hz scan flickers); one `sync_2ff` per bit (values can
arrive mixed). No FSM and no `enum`: two registers and a compare.

### 4.4 `game_top` (Alan)

- Ports: `sw[15:0]`, `seg[6:0]` (`seg[0]` = a = CA … `seg[6]` = g = CG), `dp` (1, off),
  `an[7:0]` (AN[0] rightmost). `game_top.xdc` enables SW12–SW15, CA–CG, DP, AN[0]–AN[7] from the
  master file, renamed.
- BTNC's synchronizer (`btn[4]`) gets `.rst(1'b0)`, so `match_fsm` sees a button held through
  CPU_RESETN (4.1); the direction buttons keep `rst_juego`.
- Synchronizers: `sw[11:0]` stay in `clk_pix` for `drawcon`; new `sync_2ff` on `clk_juego` for
  `sw[0]` (Pause), `sw[14]`, `sw[15]` (goal). The two goal bits are synchronized separately; a
  change of both switches between two ticks can show an intermediate value for one tick, which
  only restarts the Goal view (accepted, as in the model).
- Instances: `match_fsm`, `score_unit`, `seg7_view` (`VIEW_TICKS` 180), `seg7_link`,
  `seg7_driver` (`COUNT_BITS` 17). `position_logic`: `.rst(rst_juego || restart)`,
  `.btn({start_go, btn_sync[3:0]})`, `.pause(pause)`, `.match_over(match_over)`,
  `.crash1`, `.crash2`, `.crash_done`.
- `game_top_timing.xdc`: false paths from `sw[*]` to the new synchronizers; for `seg7_link`:
  ```tcl
  set_max_delay -datapath_only 11.982 -from [get_cells u_seg7_link/tick_toggle_reg] -to [get_cells u_seg7_link/u_sync_toggle/meta_reg]
  set_max_delay -datapath_only 11.982 -from [get_cells {u_seg7_link/values_juego_reg[*]}] -to [get_cells {u_seg7_link/values_pix_reg[*]}]
  ```
  `build_game_top.tcl` stops if either side finds no cells. SW12 and SW13 drive nothing; if
  `check_timing` counts them as inputs without delay, they get an explicit false path.

## 5. Changes requested in Roman's code ([issue #44](https://github.com/romanmg00/FPGA/issues/44), Spanish, like #38)

Roman makes these in his own PR. They are additive, and his benches keep passing with the new
inputs tied to 0.

| File | Change | Lines |
|---|---|---|
| `step_counter.sv` | New input `pause`: while 1 the count holds and `step` is 0 (the spec: Pause holds the game timers) | ~3 |
| `position_logic.sv` | New inputs `pause`, `match_over`; new outputs `crash1`, `crash2`, `crash_done` (signals that exist inside); `.pause(pause)` on `u_step_counter` and `u_crash_timer`; `.run(run && !pause)` on both `bike_move` (no Turns while paused); `round_fsm`'s `.t(crash_done && !match_over)` (after a Match-ending Crash it stays in `s_crash`) | ~10 |
| `step_counter_tb.sv` | `.pause(1'b0)`, plus a hold case | small |
| `position_logic_tb.sv` | `.pause(1'b0), .match_over(1'b0)` in both DUTs | 2 |
| `round_fsm.sv`, `bike_move.sv`, `bike_glide.sv`, `drawcon.sv` | No change | – |

What `game_top` does with them (no change in Roman's code): `btn[4]` receives `match_fsm`'s
one-tick `start_go`, and `rst` also receives `restart`. The contract's `position_logic` ports and
the G3/G5 row change accordingly; the issue proposes the text.

Order: stage 3 does not depend on these changes. Stage 4 integration needs them on `main`. If
Roman prefers, Alan can prepare them in a separate PR for his review.

## 6. Pause details

While SW0 (synchronized on `clk_juego`) is 1: no Step (`step_counter` holds and gives no `step`,
so no Crash is reported), no Turn accepted, the Crash timer holds (the 2 s resume where they
stopped), Start is ignored (a press made while paused does not count after SW0 goes down,
because `s_q` keeps tracking), and `match_fsm` holds its state with its action outputs at 0
(4.1). `seg7_view` has no pause input, so the Scoreboard keeps cycling;
video and the Arena service keep running. `bike_glide` is drawing only: a slide already started
finishes, then the Bike stands still. SW0 down resumes on the next tick.

## 7. Verification

All benches self-check, print `PASS <bench>`, and run in `build_game_top.tcl`.

| Bench | Stage | What it checks |
|---|---|---|
| `match_fsm_tb` | 3 | One expected state trace per transition (driving `s`, `c`, `t`, `m`, `p`); outputs per state; a held Start never starts, also when held through `rst`; a press during `G_CRASH` (both kinds) is ignored; Pause raised in **each of the eight states** holds the state with `new_match`, `restart` and `start_go` at 0, and a press made during Pause does not count afterwards; no timeout in `G_PLAY`; reset from every state returns to `G_IDLE` |
| `score_unit_tb` | 3 | Reset and `new_match` values; each Crash case (P1, P2, both) for Lives and the +3 bonus; values carried across Rounds; Match end by Lives: P1 out, P2 out, both out with higher P1, higher P2, equal (Draw); result retained and no change after it; `new_match` clears it; the maximum 9 |
| `seg7_link_tb` | 4 | Two unrelated clocks with independent phases (and the real ratio): every bundle value arrives whole (whole 20-bit compare) and in order; the output never changes between two toggle events; system resets applied with the toggle at 0 and at 1 fake no copy and drop no value |
| `match_tb` | 4 | `match_fsm` + `score_unit` + Roman's changed `position_logic`, one tick per edge, Arena codes driven by the bench (empty, plus `codes_valid` low on chosen ticks): full Matches in microseconds; the alignment table of 4.1 on every tick; no `step` while `codes_valid` = 0; P1 out (P2 wins 9–0), Draw by Head-on at 1 Life each (`turn_req2` driven); Pause in each lifecycle state, at the last tick of a Step period and of the Crash display (they end exactly that many ticks later); a reset (`rst`) in each lifecycle state; Bikes do not move in `G_MATCH`; one press starts a new Match |
| `game_top_tb` | 4 | Existing 7 scenarios updated (`press_start` waits up to 10 ticks for `run`; 16 switches, SW0 down). Monitors in every scenario: every Step has `codes_valid` = 1; exactly one Prepare (`req_prepare` request) after each reset, after each non-final Crash display and for each new Match started from `G_MATCH`; none at Match-over, none for the first Match after a reset (the reset's Prepare already cleared the Arena). New `match` scenario: a full Match by P1 crashing into its own Trail three times, the digits read from `seg`/`an` (`P200P100` at power-up, Lives after each Crash, `GOAL  nn` while waiting and after a `{SW15,SW14}` change, Points first in a new Match), the Arena kept at Match-over and prepared by the new Match. New `pause` scenario: SW0 during play and during the Crash display, Scoreboard view still changing; BTNC held through a CPU_RESETN does not start a Match until released and pressed again |
| `step_counter_tb`, `position_logic_tb` | Roman | Their own cases with the new inputs |

Build: `build_game_top.tcl full` in Alan's container: all benches, routed timing met, the new
crossing only as recognized patterns in `report_cdc` (CDC-3 for the toggle, CDC-15 for the copy;
the known bike-position CDC-1 rows of issue #30 unchanged). Injected-bug runs, each must be caught:

- `match_fsm`: G_CRASH ignores `m`; press not edge-detected; `s_q` reset to 0; Pause not
  holding the state; `start_go` not gated by Pause; `G_GO` skipped; `waiting` high in `G_READY`.
- `score_unit`: bonus to the crashed Bike; bonus when both crash; Lives not decremented for P2;
  Draw given to P1; values change after the result.
- `seg7_link`: copy every cycle instead of on the toggle; copy on the synchronized level instead
  of its change; `values_juego` loaded only when the toggle is 0; two bundle fields swapped.
- `game_top`: `seg` reversed; `an` order reversed; goal bits swapped.

### Rule coverage

| Rule (spec section) | Checked by |
|---|---|
| 3 Lives and 0 Points per Match | `score_unit_tb`, `game_top_tb match` |
| Points and Lives carry between Rounds | `score_unit_tb`, `match_tb`, `game_top_tb match` |
| Losing the final Life loses the Match | `score_unit_tb`, `match_tb`, `game_top_tb match` |
| Both lose the final Life in one Step: higher Points, else Draw | `score_unit_tb` (Draw reached by Crashes; higher Points with `force`, unreachable without Rewards, section 3), `match_tb` (Draw) |
| Evaluation order in a Step: Crashes, bonus, then victory | `score_unit_tb` (the survivor's +3 counts in the final Step) |
| Survival Bonus +3 to the only survivor, none when both crash; ADR 0011 | `score_unit_tb`, `match_tb`, `game_top_tb` (`wall_crash`, `match`) |
| No timeout ends a Round | `match_fsm_tb` |
| Power-up waits for Start; one Start begins the Match, no second press | `match_fsm_tb`, `match_tb`, `game_top_tb` |
| Start from BTNC; a button held through CPU_RESETN or a Crash display needs a fresh press | `match_fsm_tb`, `game_top_tb pause` |
| Non-final Crash: ~2 s frozen, Start and Turns ignored, next Round prepared, fresh Start | `match_fsm_tb`, `match_tb`, `game_top_tb head_on` |
| Match-ending Crash: result at once, 2 s display, no new Round prepared, Start eligible after | `score_unit_tb`, `match_fsm_tb`, `match_tb`, `game_top_tb match` |
| Final waiting: values kept; one fresh Start starts a new Match | `match_fsm_tb`, `match_tb`, `game_top_tb match` |
| Pause holds game state and timers, ignores steering; resume at once; Scoreboard keeps cycling | `match_fsm_tb`, `match_tb`, `game_top_tb pause`, `step_counter_tb` |
| CPU_RESETN clears the game and waits for Start | `match_fsm_tb`, `game_top_tb` reset scenarios (Points and Lives too) |
| Scoreboard: 8 digits, P2 left, views together, no dark periods, new Match on Points, cycles in every state | `seg7_*_tb`, `multidigit_tb` (PR #34), `game_top_tb match`/`pause` |
| ADR 0008 Goal view while waiting, switch jump | `seg7_view_tb` (PR #34), `game_top_tb match` |

### Deferred, with reasons

| Rule | Reason | Where it goes |
|---|---|---|
| Reach or exceed the Points Goal wins; both reach it → higher Points or Draw | Unreachable without Rewards (section 3); Alan chose to defer (point 3) | G4 |
| Goal captured at Start and held for the Match; switch changes apply to the next Match | Only the Goal check would use it; without it the register is dead logic. The Goal view (ADR 0008) already shows the switches the next Start would take | G4 |
| Goal reached without a Crash → final waiting state | Needs the Goal check; `position_logic` would also need to stop the Round (for example `match_over` gating the Step) | G4 |
| Full final-Step total without wrapping (45) | Widths are already 6 bits; the value cannot occur without Rewards | G4 bench |
| Rewards, +1/+1/+3, three Rewards prepared at Start | G4 | G4 |
| Seed influenced by Start timing | The first Match from `G_IDLE` does not prepare the Arena again (it was prepared when reset ended); G4 may need a Prepare at that Start | G4 |
| Crashed Bikes blink at their last valid Cells during the 2 s Crash display (non-final and Match-ending) | Explicitly deferred: the blink is Roman's (X1, issue #30, handoff). It needs per-Bike Crash flags held through `G_CRASH` (they can be registered from `crash1`/`crash2` at the Crash Step), crossed to `clk_pix` and used by `drawcon`. This plan provides the 2 s timing, the frozen game state and `crash1`/`crash2`; the Bikes are drawn still, not blinking | X1 |
| Start from Space/Enter on the UART controller ("either Player can start") | The UART path is not in `game_top` yet; only BTNC starts | UART integration |
| P2 steers with WASD over USB-UART; ordered keyboard/UART requests; 115200 8N1; Enter encoding | Input path work, not this issue (`turn_req2` is tied to 0 in `game_top`) | UART integration |
| Movement, Turns, Crash cases, Trails (spec *Movement, Turns and Crashes*) | Roman's G1/G2, already checked by `position_logic_tb`, `bike_move_tb` and `game_top_tb`; not changed here except the Pause gating | – |
| A winner or Draw shown to the Players | The spec defines no display for it; `result` is kept in `score_unit` for the HUD | HUD |

## 8. Documentation

- `proyecto_final/README.md`: Pasos 7c and 7d, file list (new modules, `round_fsm` now driven by
  `match_fsm`).
- ADR 0008 *Consequences*: the Scoreboard is in `game_top`.
- ADR 0009: PR #34's two homework-1 rows (`sevenseg` codes 10–15; `multidigit` scan clock), row 3
  (pins: `sw[15:0]`, `seg`, `dp`, `an`), row 8 (Match lifecycle above `position_logic`).
- Contract (Roman's, he is told in the PR): §2 `dp` row and switch use; §3 *Juego → video y
  display* (the Scoreboard crossing); §4 G3/G5, `seg7_driver`, `game_top` rows and *Estados de la
  partida* (states 5–7, `round_fsm` driven by `match_fsm`); `position_logic` ports from the issue.
- Architecture and Documentation Map: owners and status of the new modules.
- `docs/decisions/` is never edited.

## 9. Stages and stops

1. Plan reviewed (gpt-6.1-sol, high) until green; then the GitHub issue for Roman (section 5).
2. **Stage 3:** `match_fsm`, `score_unit` and their benches; `build_game_top.tcl sim` passes.
   Stop and report to Alan.
3. **Stage 4:** `seg7_link` and its bench, XDC pins (these do not wait for Roman); after Roman's
   changes are on `main`: `game_top` wiring, `match_tb`, `game_top_tb` scenarios, `full` build,
   `report_cdc`, injected bugs. Stop and report.
4. Board check with Alan (he releases the board): Points → Lives → `GOAL  nn` before the first
   Match; SW14/SW15 jump to Goal; a Crash takes a Life; the Match ends; Pause.
5. Docs, then the PR (base `main`, `Closes #33`, `@romanmg00`), not merged; a note on #33 in
   Spanish.

## 10. Risks

- **Coupling to `round_fsm`'s timing:** `match_fsm` assumes `s_release` lasts one tick with Start
  low and that `crash_done` ends `s_crash`. `match_tb` checks the alignment table on every tick,
  so a later change to `round_fsm` that breaks it fails a bench.
- **Roman's availability before the Pre-Demo (19 November):** stage 4 waits for his PR; the
  fallback is Alan's PR for his review.
- **Long simulations:** `game_top_tb match` simulates about 9 s (about 40 minutes); it runs in
  parallel with the others.
