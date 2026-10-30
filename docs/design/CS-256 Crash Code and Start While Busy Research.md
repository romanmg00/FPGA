---
schema_version: 1
id: cs256-crash-code-start-while-busy-research-20261028
title: CS-256 Crash Code and Start While Busy Research
type: note
subject: CS-256
status: draft
created_at: "2026-10-28"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[0003-step-transaction-mailbox-and-render-codes]]"
  - "[[CS-256 Tron Game Model Hardware Map]]"
  - "[[CS-256 Tron SystemVerilog Readiness Research]]"
  - "[[CS-256 Tron SystemVerilog Readiness Decisions]]"
review_status: unreviewed
tags:
  - tron
  - fpga
  - research
---

# CS-256 Crash Code and Start While Busy Research

Research checked **28 October 2026**, branch `docs/systemverilog-readiness`, HEAD `18f36532a28dcdfb9dbff70588b32e010e5b12bd`. **This is research, not a team decision.** Working defaults below are cheap, testable starting points for the shared Python model and first SystemVerilog build. Neither needs to freeze later service or rendering choices. No repository model, scenario, contract, ADR or locked record was edited. Experiments used `/tmp/cs256-crash-start-research/`; no HDL or board measurement was performed.

Authority follows [[CS-256 Tron Architecture and Documentation Map#Authority and status]] and the docs README. The locked specification is the gameplay constraint. Accepted ADRs 0002 and 0004 establish the divided game clock and shared model base; ADR 0003 item 4 remains proposed pending Alan's confirmation. The course handout's Drawing Logic Module requires combinational drawing and a divided game clock; it does not decide these two questions. The Spanish contract §§3–4 still leaves service/render ports pending. Vocabulary follows [[CS-256 Tron Glossary]]. Review recommendations E6/D5 are subject to [[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]].

## Working defaults

- **A — Engineering recommendation, medium confidence:** write code 6 at each crashed Bike's **last valid head Cell**, retaining Player identity, shown Heading and blink control in the render snapshot. This follows Roman's proposed ADR 0003 item 4, with a small write/test change and useful Arena diagnostics. Code 6 alone is not a complete renderer interface.
- **B — Engineering recommendation, medium confidence:** retain **one pending eligible Start** until the mailbox is idle, scoped to the current eligible wait and discarded on Pause/reset/phase invalidation. Preserve the first request's seed/goal capture values. This adds resilience to future service latency; it fixes no demonstrated loss in the current nominal two-tick model. Never retain a Crash-time Start.

The team needs to confirm these behaviors and their contract wording, rather than wait for a finished board to choose a prototype default. Hardware evidence must still establish service timing, coherent display publication and control eligibility; neither choice approves the proposed CDC implementation.

## A. Crash code in COMMIT

### Locked requirements and interpretation

**Locked-spec requirements:** a crashed Bike stays at its last valid head Cell; both targets are read before either move is written; the survivor completes its Step and may collect a Reward. Crashed Bikes blink for approximately two seconds, including a Match-ending Crash; the latter retains the result and enters final waiting without preparing another Round. Trails include occupied head Cells and clear between Rounds. See [[CS-256 Tron Agreed Specification 2026-10-20#Movement, Turns and Crashes]] and [[CS-256 Tron Agreed Specification 2026-10-20#Start, Crash display, Pause and reset]].

The specification's **Clocks, Arena encoding and service boundary** table defines `6 = Crash` and requires model/HDL codes to match. It does **not explicitly mandate a write**, a location for code 6, or a Player colour for it. Reading that table as requiring storage is a reasonable interpretation, not a separate locked imperative. Keeping 6 defined but unused can implement the visible rules; writing it gives the encoding an operational meaning. The selected interpretation belongs in the reconciled contract. Roman's proposed ADR 0003 chooses storage; the earlier [[CS-256 Tron SystemVerilog Readiness Research#8. Remaining lifecycle, display and asset ports]] preferred retained head codes for identity. Neither is accepted authority over the other.

### Current implementation and rendering consequences

Implementation evidence: `model/params.py:37` defines code 6 with the comment that the model does not write it. `model/step_unit.py:38–54` leaves crashed heads in place and emits no writes for them. A survivor emits old-head Trail and new-head head writes. `model/arena_ctrl.py:76–83` executes the supplied writes before replacing collected Rewards. Paths in this note are relative to `prototipos/tron_fpga/` unless stated otherwise.

With retained codes 3/5, an Arena-only reader knows Player ownership and head position, but cannot distinguish a crashed head from a live head. It needs the snapshot's Crash mask and phase/timer to show the effect. With code 6, an Arena-only reader can locate a Crash marker, but **cannot recover its Player, Heading, blink phase or 32 × 32 Bike appearance**. There is only one Crash code for both Players. Keep the existing snapshot `{heads, headings, crashed, phase, phase_ticks}` (or equivalent explicit blink bit) for sprites under either policy; see `model/game_top.py:250–263` and contract §4 `drawcon`.

**Working render default:** code 6 is occupied and represents a crashed head underlay; derive its Player tint by matching its Cell to the coherent snapshot's crashed heads. Use a neutral diagnostic colour if no head matches, and flag that mismatch in verification. Do not infer P1/P2 from the numeric code. Blink the Bike sprite only during G_CRASH; after a Match-ending effect, draw it solid in G_MATCH with the retained Arena. The snapshot remains necessary even if the underlay is neutral. Pixel/frame coherence is a separate open obligation: code 6 must be published with the matching head/Crash metadata, not used to excuse an Arena/snapshot mismatch.

The current PC viewer draws all Player head/Trail Cells through `player_of`; code 6 returns `None` (`model/arena_map.py:20–40`). `juego/render.py:69–119` clears a changed Cell's cached underlay and then draws only Player codes; full redraw likewise skips code 6. Its Bike sprites and blink already come from the snapshot (`juego/render.py:131–142`), and G_MATCH draws them solid. **A model-only code-6 patch therefore removes the coloured head underlay, while retaining the Bike sprite.** A production patch should implement the code-6 underlay in both incremental and full-redraw paths, with snapshot/version-aware invalidation, and verify blink-on/off frames. Updating `player_of(6)` to a fixed Player would be incorrect.

### Head-on, Rewards and clear

For same-target Head-on and swaps, write 6 at **both distinct old heads**, never at the shared target or by moving a Bike into the fatal Cell. There are two markers even when both tried to enter one Cell; swaps also leave both Bikes at their own last valid Cells. No Reward is collected on a shared-target Head-on. In a one-Bike Crash, preserve the survivor's Trail/head writes and collection before checking the final score. These rules follow the locked simultaneous-Step semantics and `step_resolve`.

**Code 6 already counts as occupied.** `is_blocking(6)` is true (`model/arena_map.py:26–32`); Reward search accepts **only EMPTY**, in both random and fallback paths (`model/reward_place.py:38–54`). Replacing a head code with 6 does not change empty/nonempty occupancy, valid replacement positions or the PRNG sequence. Any future delayed Reward writer must likewise revalidate EMPTY, rather than enumerate only Walls and Player codes. PREPARE's complete 8192-word clear removes Crash markers before writing the two start heads and three Rewards (`model/arena_ctrl.py:61–74`); CPU reset clears the Arena as well. A Match-ending Crash gets no PREPARE until the next accepted new-Match Start, so retain 6 throughout final waiting.

### Throwaway model experiment and exact impact

Copied the prototype, contract and Step-log diff helper into `/tmp/cs256-crash-start-research/`, preserving their relative paths. The sole behavioral patch imported `CRASH` into the copied `step_unit.py` and inserted `writes.append((*heads[i], CRASH))` in its crashed-Bike branch before `continue`. No timer, score, PRNG, renderer or scenario changed.

Using `SDL_AUDIODRIVER=dummy ~/.venvs/cs256-tron/bin/python -m unittest discover -s tests`:

- Unmodified repository: **79 tests passed**.
- Patched copy with original tests: **76 passed, 3 failed**, all expected representation assumptions in `tests/test_model.py`.
- `StepResolveTests.test_head_on_same_cell_crashes_both` (line 182): expected zero writes; now gets `(40,20,6)` and `(41,19,6)`.
- `StepResolveTests.test_crashed_bike_stays_and_survivor_writes_trail_then_head` (line 196): add `(40,20,6)` before the unchanged P2 Trail/head writes.
- `LongGameTests.test_random_play_keeps_the_arena_and_scores_consistent` (line 717): replace unconditional `HEAD[i]` with `CRASH if game.crashed[i] else HEAD[i]` outside PREP. The first failure was `6 != 5`.
- After changing **only those three expectations in the temporary copy**, **all 79 tests passed**, including all four scenario test methods. SDL stream-fd warnings appeared before successful runs; no interactive or pixel correctness claim follows.

Directly replayed all 12 `.txt` scenarios in that patched copy and compared every generated line with its original `.log`: **0/12 logs changed, 0/3,261 lines changed**. All 12 scenarios encounter a Crash; together their non-round log records contain **80 Crash outcomes**. Therefore unchanged logs are not evidence that the patch did nothing. The Step-log schema records heads, Headings, Crash flags, Points/Lives, Rewards and result, **not Arena words, write lists or fast-cycle counts** (`model/steplog.py:1–55`). Their values and ticks remain identical. No golden-log regeneration is needed for this patch alone; adding Arena/write diagnostics would be a separate schema change.

### Cost, alternatives and evidence to revisit

**Engineering estimate, not synthesized evidence:** add one Port-A write **per crashed Bike**, hence +1 for a single Crash or +2 for both. A one-Crash Step has three movement writes instead of two; a two-Crash Step has two instead of zero. The existing maximum remains four writes for two survivors. No new Arena bits, port, command or mailbox round trip is inherently needed. In the model's one-cycle/write accounting this is +1/+2 fast cycles (about 12/24 ns at the requested 83.46 MHz), not extra game ticks. Actual RTL/BRAM arbitration may differ and must be measured. For HDL use fixed flattened write fields/valids, consistent with the contract's no-array-port rule.

Arena dumps and an ILA probe of address/data/write-enable can then show **where a Crash was committed**, without also probing the Crash mask. They still need head/snapshot data for Player identity. Head-code retention is cheaper in the current viewer and keeps identity in RAM, but gives no persistent Crash evidence in RAM; prefer the small explicit marker change now because the snapshot already carries identity and Roman proposed it.

Change the default if the first renderer tests show code 6 causes avoidable identity/coherence complexity, or synthesis/service traces reveal a meaningful commit-scheduling penalty. Reverting is cheap: remove the Crash writes, restore the three expectations and retain snapshot-driven blink; no memory layout or Step-log change. Conversely, an explicit team interpretation requiring stored code 6 settles this engineering alternative. The smallest functional test is one Wall Crash plus a surviving Reward collection: assert the two old/new survivor writes, 6 at the crashed old head, unchanged fatal target, correct Points/Lives and nonempty occupancy. Add both Head-on variants, PREPARE cleanup, final waiting retention, and a code-6 Reward rejection/render test before integration.

## B. Start while the mailbox is busy

### Current drop rule and reachable window

Implementation evidence: Start arrival is enabled only from an unpaused render snapshot in G_IDLE/G_READY/G_MATCH (`model/game_top.py:121–131`). Application is two ticks later through `batch_bus` and `batch_cap`. `_game_edge` samples mailbox idle **before** capturing the response (`:136–154`), returns early on Pause (`:159–162`), and accepts Start only when `batch.start and ph in START_PHASES and idle` (`:195–204`). Input batches are consumed once and cleared (`model/input_batch.py:117–121`). **A Start presented for application while busy is discarded, not retried.**

Reachability from normal model operation:

- **G_IDLE:** no command after reset; the Python reset clear is immediate. A busy reset-clear interval in HDL would be a new hardware case, not current model behavior.
- **G_READY:** entered only after PREPARE's response is usable (`game_top.py:205–210`). No further command issues there before Start, so no normal busy window.
- **G_MATCH after a Crash:** entered only after both the Crash timer and `idle` condition (`:211–215`). No busy window, even with a shortened Crash timer.
- **G_MATCH after a goal without a Crash:** the outcome enters G_MATCH and issues COMMIT at the same edge (`:167–177`). This is the **only nominal eligible-phase overlap**. READ2 cannot overlap an eligible wait; PREPARE uses ineligible G_PREP. COMMIT during G_CRASH is busy but Start is forbidden.

Let **M** be the no-Crash winning outcome edge. COMMIT is issued at M and is usable by game logic at **M+2**, a nominal **two-tick / 33.3 ms command interval**. The only subsequent edge with old phase G_MATCH and old idle false is **M+1**. At M itself the old phase is G_PLAY. `mbox.idle()` becomes true just after M+1 captures the response, but this does not retroactively change M+1's decisions.

Crucially, the first arrival admitted after entry is assigned to tick **M+1** and reaches application at **M+3**. Thus the current arrival/application pipeline hides the busy interval: **zero nominal eligible fresh-Start arrivals are lost to busy**, although the discard rule exists. A Start arriving before entry is rejected by the Play gate and must not be replayed. The nominal window is derived from the Python schedule, not a guaranteed hardware bound; Pause continues captures/service and does not extend COMMIT's modeled completion interval.

### Reproduction and latency sensitivity

A temporary Python driver reused `tests/test_model.py` helpers: start a goal-20 Match, force P1 Points to 19, place slot 2 ahead of it, and complete that Step. It entered G_MATCH at **M=13** with COMMIT outstanding. Send one Start at tick 14: application at tick 16 (**M+3**) entered PREP; tick 18 released Play. This confirms an early fresh press works in the nominal schedule.

Then repeat, artificially withholding the COMMIT response bus through M+3 and restoring it before M+4's capture. This is a **response-delay injection**, not a simulated safe CDC protocol or measured hardware latency. The same Start applied at M+3 while busy and was discarded; response completion became usable at M+5, and the game remained in G_MATCH through M+6 without another press. No score/Reward service implementation was altered in the repository.

More generally, if completion becomes usable at **M+D**, the first fresh arrival is applied at M+3; a loss first appears for integer **D ≥ 4**. Potential lost arrival ticks are `M+1` through `M+D−3`: **max(0,D−3)** sampled input windows, approximately that count ×16.7 ms at nominal 60 Hz. This arithmetic assumes the current two-tick input path and unchanged phase gate. Different CDC/input latency, an HDL reset clear in IDLE, folded preparation states or longer concurrent Reward service require a fresh calculation. No universal board loss window is established here.

### Pending-Start default and constraints

**Locked-spec requirements:** ignore every Start during the Crash display, require a fresh Start after it/for another Match, prepare all three initial Rewards before release, and ensure in-flight input/memory results cannot corrupt reset. Pause freezes logical state and timers. The exact busy-Start policy and Start-while-paused rule are not explicitly fixed; ignoring paused Start is the existing model choice and review D5(i)'s recommendation. See [[CS-256 Tron Agreed Specification 2026-10-20#Start, Crash display, Pause and reset]] and [[CS-256 Tron Game Model Hardware Map#Choices the model makes (proposals)]].

**Engineering recommendation:** at the normal game-domain input application edge, qualify a new Start against its arrival eligibility and the current unpaused eligible wait. If idle, act immediately; if busy, record one pending request. Drain it once idle **only in that same eligible wait**. First request wins; duplicates coalesce until it is consumed. Do not reset Points/Lives, change phase, or issue PREPARE until service is available. This is a one-entry lifecycle request, not another Arena command outstanding.

Store the pre-edge game tick used for seed mixing and synchronized goal value with the pending new-Match request; do not recapture them at delayed dispatch. Immediate Starts retain today's behavior (`game_top.py:143,199–202`). Capturing at the qualifying application edge is the existing tick-resolution interpretation of Start timing, not physical button/UART arrival time. G_READY only releases an existing Round and must neither reseed nor sample a new Points Goal. If the team instead wants physical-arrival seed timing, that is a separate event-metadata/CDC choice.

Clear pending Start on reset, synchronized Pause assertion, consumption, or departure from its eligible wait; require a new request after resume. Reject delayed pre-Pause/pre-Crash events using control eligibility/version metadata, rather than letting them recreate pending state after a clear. **Never set pending from an ineligible arrival**, including the last Crash-display tick or G_PREP. A held button is not a fresh press: the board producer must generate debounced press events, and browser key repeat/transport duplicates need a defined policy. Pending state alone does not solve those producer issues.

The current arrival gate uses the render snapshot. In HDL, if display publication lags control, use coherent **control eligibility** independently of visible blink state; otherwise a fresh post-wait press can be rejected or an old one admitted. See [[CS-256 Tron SystemVerilog Readiness Research#7. Input ordering, eligibility and UART reuse]]. A full input-epoch design is unverified; the pending latch cannot substitute for it. For this prototype, preserve and test the current arrival gate and add the pending policy at application.

### Alternatives, cost and smallest tests

Dropping is a defensible minimum-change default **while measured service plus input timing proves the nominal masking invariant**. Its cost is a second press whenever that invariant stops holding, with no visible explanation to the Player. Prefer the pending latch now because it keeps future latency options open. Delaying entry to G_MATCH until COMMIT ends would prevent the overlap but would delay the specified immediate logical final wait and discard presses during that delay. Queuing all Starts adds no useful gameplay behavior and risks replay across Matches. Buffering indiscriminately during Crash contradicts the locked fresh-Start rule.

**Engineering estimate:** one pending bit, captured seed/goal fields (the existing game counter is 32 bits and goal selection two bits), and eligibility/reset qualification. If an event epoch already exists, reuse it; exact extra epoch width/logic depends on the input protocol. No extra Arena port or simultaneous command is required. In a stalled eligible wait, phase and final Points/Lives remain stable until dispatch. Preserve one command outstanding and let existing COMMIT/Reward work finish. This proposal has **not** been implemented or synthesized.

The smallest new test is the response-delay injection above: send exactly one eligible Start while busy, check it remains pending with final score intact, restore completion, then assert exactly one PREPARE and automatic first-Round release. Change goal switches while pending and assert the captured goal/seed do not change. Repeat with reset and Pause before completion and assert no automatic Start afterward; press during the last Crash tick and assert no pending state appears. Include both G_READY and G_MATCH, both input sources, repeated events, and a genuinely fresh press immediately after wait entry.

Expected model/scenario consequence: add pending fields and dispatch logic to `game_top.py`, targeted lifecycle tests, and contract rules for qualification/capture/discard. The **12 nominal scenario logs should remain unchanged** because their mailbox never exercises a qualifying busy application; this is a source-based prediction for the pending implementation, **not a tested patch result**. Add a delayed-service test/scenario rather than regenerate unchanged golden logs. A seed tied incorrectly to dispatch would create avoidable new-Match sequence drift under stalls.

Revisit if measured handshakes prove no eligible busy application is possible in all startup/end-Match cases and the extra state confuses lifecycle verification; removing it is cheap and does not change the mailbox interface. If board playtests show cancellation on Pause loses a deliberately queued Start, reconsider that cancellation rule explicitly with the team. A stuck mailbox needs a fault/recovery policy; retaining Start indefinitely must not conceal service failure. No finite timeout or automatic new-Match retry is recommended without evidence.

## Implementation handoff

Confirm code-6 storage and the one-pending-Start semantics with Alan/Roman, then record adopted scope in ADR 0003 onward and reconcile contract §§3–5. For A, specify placement, occupancy, retained identity/blink metadata and final-wait behavior; update `params.py`'s comment, model writes, the three existing expectations and renderer handling. For B, specify the capture edge, first-request coalescing, eligible-wait scope and Pause/reset invalidation. Keep functional tests separate from the CDC, BRAM collision and coherent-frame evidence gates. Neither question requires changing the locked specification to implement these working defaults.
