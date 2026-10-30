---
schema_version: 1
id: cs256-step-transaction-displayed-heading-research-20261028
title: CS-256 Step Transaction and Displayed Heading Research
type: note
subject: CS-256
status: draft
created_at: "2026-10-28"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[0002-follow-ta-divided-game-clock]]"
  - "[[0003-step-transaction-mailbox-and-render-codes]]"
  - "[[CS-256 Tron Game Model Hardware Map]]"
  - "[[CS-256 Tron SystemVerilog Readiness Research]]"
  - "[[CS-256 Tron SystemVerilog Readiness Decisions]]"
  - "[[CS-256 Official FPGA Coding Practices]]"
review_status: unreviewed
tags:
  - tron
  - fpga
  - research
  - systemverilog
---

# CS-256 Step Transaction and Displayed Heading Research

Research checked **28 October 2026**, on `docs/systemverilog-readiness`. This note extends [[CS-256 Tron SystemVerilog Readiness Research#2. Proposed blocks and register ownership|register ownership]], [[CS-256 Tron SystemVerilog Readiness Research#3. Clock relationship, X1 and the six-tick budget|X1 timing]] and [[CS-256 Tron SystemVerilog Readiness Research#4. Coherent rendering and BRAM semantics|render coherence]], without selecting the crossing protocol. **Research only: neither a team decision nor acceptance of ADR 0003.** Its items 1 and 5 record Roman's position; Alan's confirmation remains open in [[CS-256 Tron SystemVerilog Readiness Decisions#Authority and evidence]].

**Working defaults:** keep READ2 → game-domain `step_resolve` → COMMIT, and display the resolved Step's Heading together with its resulting head Cell. These already work in the Python model and preserve the agreed owner split. Build and test these small functional blocks now; use an interchangeable transaction bridge rather than baking the model's two-tick response assumption into them.

Labels below distinguish **Locked requirement**, **Engineering recommendation**, **Implementation evidence**, and **Unverified assumption**. Authority follows [[CS-256 Tron Architecture and Documentation Map#Authority and status]], the course handout, locked specification, accepted ADR 0002, then the reconciled contract. The review's [[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits|adoption limits]] apply, especially its qualifications on D3 timing, render coherence and in-flight Pause.

## Item 1 — Step transaction

### Working default and requirements

**Engineering recommendation — high confidence in functional structure; hardware schedule unverified.** Keep both target reads in the fast Arena service, return the two codes as one coherent result, resolve both Bikes combinationally in the game domain, and submit one bounded write list. `step_unit` registers a single outcome enable for Alan's scoring/lifecycle blocks. A memory acknowledgement retires that transaction; it must never award Points a second time.

**Locked requirements:** both target Cells are read before either move is written; same-target and swap are Head-on Crashes; no Player movement priority. Crashed Bikes keep their last valid head Cells. A surviving Bike completes its Step and collects any Reward. Add Rewards and the Survival Bonus, deduct Lives, then evaluate the Points Goal and final-Life result using the full final-Step totals. The Step cadence is six approximately 60 Hz game ticks. See [[CS-256 Tron Agreed Specification 2026-10-20#Movement, Turns and Crashes]], [[CS-256 Tron Agreed Specification 2026-10-20#Match, Points Goal and scoring]] and contract §§3–4, 6.

Keep these events distinct:

| Event | Meaning and owner |
|---|---|
| Launch | Roman's `turn_unit` applies the Pending Turn; `step_unit` captures both targets and launched Headings. Subsequent requests use that new Heading, preventing the F3 stale-Heading reversal hazard. |
| Logical outcome | Roman resolves both targets; Alan updates Points, Lives, result and phase from that outcome on the same game edge. This is the model's effective logical commit. |
| Arena write completion | Alan's `arena_ctrl` has applied the entire write list and invalidated collected Reward slots. This is distinct from bridge acceptance. |
| Display publication | A coherent Arena version and matching head/Heading/Crash snapshot become visible together. It can follow the logical outcome. |

**Implementation evidence:** `model/step_unit.py:38–54` detects same-target and swap explicitly, treats only Empty/Reward as passable, suppresses collection for crashed Bikes, and produces survivor old-head/new-head writes. `:77–94` separates launch, resolve and retirement. `model/game_top.py:166–189` scores once at resolve and submits COMMIT; `model/score_unit.py:16–32,50–62` evaluates victory after all additions/deductions. Paths in this note are relative to `prototipos/tron_fpga/` unless otherwise stated. [[CS-256 Tron Game Model Hardware Map#Tick timing]] and review D2-A/§5.7 describe the proposal; code establishes its present behavior.

### Alternatives and what each crossing must provide

| Option | Correctness, ownership and practical cost | Needs from any slow/fast crossing; why not now |
|---|---|---|
| **READ2 → slow resolve → COMMIT** | Both targets refer to pre-Step occupancy; explicit same-target/swap checks. Reward slot IDs and Crash flags feed one scoring event. Preserves Roman's game-domain Turn/Step ownership and Alan's memory/Match ownership. | Two dependent command/result exchanges, coherent paired codes, held transaction identity, no duplicate completion, reset recovery and a measured reuse bound. Best starting point because the model and 12 M2 traces already use it. |
| Atomic fast-domain read/resolve/write | Still correct if it reads both targets before writing, explicitly detects same-target/swap, returns both collection/Crash outcomes together, and leaves Points/Lives/victory in the game domain. Can remove one dependent round trip. | One coherent command carrying old heads/targets and one exactly-once outcome after writes; must budget return latency and publication. Moves Roman's G2 resolution into Alan's service area and needs a coordinated interface/domain change. Keep as the fallback if X1 cannot sustain six ticks. It is not permission to move the whole game engine fast. |
| Game-domain occupancy shadow | Could resolve locally and send only writes. A blocking bitmap alone is insufficient: distinguish Reward slots and keep their removal/replacement synchronized. Explicit head comparisons still detect Head-on/swap. | Ordered, versioned initialization and every occupancy/Reward update, not only a COMMIT acknowledgement. A full 4-bit shadow duplicates 32 Kibit and requires another read/storage design; a bitmap plus Reward metadata still has two authorities to reconcile. More state and tests than the problem currently needs. |
| Sequential per-Bike with priority | Same empty target could let the first Bike win while only the second Crashes, violating the locked simultaneous rule. Changing iteration order changes results. | Even a perfect crossing cannot fix that semantic error. Sequential **reads and writes on one BRAM port are fine** if both reads precede resolution and all writes; that is serialization of storage access, not Player priority. Reject priority processing. |

No crossing type alone establishes a universal tick count. For example, AMD's [UG953 2024.2, XPM_CDC_HANDSHAKE](https://docs.amd.com/r/2024.2-English/ug953-vivado-7series-libraries/XPM_CDC_HANDSHAKE) requires receipt acknowledgement and rearming before reuse; depth and consumer-edge behavior matter. Selecting a toggle, handshake macro or FIFO remains ADR 0003 item 2 work, not a consequence of selecting READ2/COMMIT.

### Storage, concurrency and latency

**Locked requirement:** `arena_ctrl` is the sole writer of the 8192 × 4-bit Arena at `{cy[5:0],cx[6:0]}`; `drawcon` reads port B. Codes come from [[CS-256 Tron Agreed Specification 2026-10-20#Clocks, Arena encoding and service boundary]], not a second table here. **Engineering recommendation:** use port A for two sequential synchronous reads and up to four Step writes; do not borrow port B. All simultaneous-rule options above fit that port arrangement. Four writes cover two survivors; adding the proposed Crash-code writes still needs at most four entries. Crash code 6 adoption is a separate ADR 0003 item 4 question; current `step_resolve` writes nothing for crashed Bikes.

Reserve occupancy from READ2 acceptance through COMMIT: no background Reward placement may alter the read targets or install a Reward into a pending head Cell. Simplest first build: defer placement writes for that interval, while video reads continue. Clear collected slot presence as part of applying COMMIT. Replacement search can follow in the background, revalidating before writing; its exact sequence/schedule belongs to the Reward investigation. Do not require an entire replacement search to finish before the next Step merely because Python currently does so (`model/arena_ctrl.py:83–91`). The spec permits temporarily absent replacements and continuing play.

**Unverified assumption:** Python's READ2 result at `k+2` and retirement at `k+4` fit a launch at `k+6`. `model/params.py:75–78` and `model/game_top.py:145–148` encode that assumption and detect an overrun; they do not measure it. Actual budget must include both crossings, synchronizer/consumer edges, bridge rearm, configured BRAM latency, arbitration and any vblank wait. Fast reads/writes take few cycles, but the slow crossing can cost milliseconds. Keep completion-driven FSMs; assert six-tick readiness rather than silently stretching the agreed Step. No freeze-grade proof is needed to start simulation, but the integrated build must demonstrate its cadence.

### Pause and reset during a Step

**Locked requirement:** Pause preserves logical state/timers and ignores steering while clocks/video/Scoreboard keep running; reset returns to Start wait and stale results must not corrupt it. **Engineering recommendation:** use the model's boundary initially: before launch, do nothing; after READ2 but before outcome, hold the result until resume; after logical outcome/COMMIT issue, finish the already-issued Arena transaction without scoring again. Retire the bridge while paused. Do not stop halfway through a write list. `model/game_top.py:159–178` and `step_unit.py:73–75` implement this policy, differing from the review's broader “all open transactions complete” wording.

The visible treatment of a previously resolved but unpublished Step when Pause arrives needs team confirmation alongside render publication. Working interpretation: publishing that already-registered outcome completes the prior Step; no additional logical Step advances during Pause. Reset is stronger: invalidate pending snapshots and responses, quiesce the writer before clearing/reinitializing memory, and release readiness only after both domains agree on a new session. A sequence counter alone is not a reset epoch. Python resets both domains and clears memory immediately (`game_top.py:88–119`); hardware needs a real clear FSM and coordinated recovery.

### Change triggers, consequences and first check

**Change the default if** a phase-swept bridge/service test shows READ2/COMMIT cannot retire and rearm before the next six-tick launch, including display scheduling. First improve scheduling or overlap bridge rearm. If still insufficient, try atomic fast STEP while preserving the pure resolver and game-domain score owner. Cost: moderate wrapper/FSM, crossing payload, contract and timing-model changes; low cost to reuse the resolver's functional vectors. A shadow costs substantially more because every Reward update becomes a coherence obligation. Neither schedule failure nor a faster implementation justifies Player priority.

**Model/scenarios/contract:** no functional model change is needed for this default. Replace fixed response timing only when a candidate bridge establishes a different schedule. Reconcile contract §§3–4 with explicit request acceptance, outcome-valid, write-done, readiness, reset/session and Pause meanings, flattened per-Player ports, write-valid mask and collection-slot IDs. Roman owns `turn_unit`/`step_unit`; Alan owns `match_ctrl`/`score_unit`, `arena_ctrl` and bridge. Keep outcome enable separate from write completion. Preserve the 12 M2 cases: Walls, own/other Trail, same-target, swap, reversal, two inputs, Reward respawn, goal, both final Lives, new Match and long random play. Logs include shown Headings, outcome ticks and post-COMMIT Reward slots (`model/steplog.py:1–24`); they are not pure movement vectors. A latency/placement change may require intentional regenerated expectations. Ignoring `tick` alone can hide changed Turn eligibility; retain separate timing assertions and replay the same event boundary semantics.

**Smallest first-build check:** one `.sv` testbench connects the pure resolver and score block to a tiny port-A synchronous RAM service plus a controllably delayed bridge. Arrange same Empty target, swap, own/other Trail, and one Wall Crash while the survivor enters slot 2 at 39 Points/goal 40. Assert both reads precede any write, both Head-on cases collect nothing, crashed heads stay, survivor moves and finishes at **45 Points**, one Life deduction, one scoring pulse despite delayed acknowledgements. Inject Pause/reset in READ, outcome/COMMIT issue, each write, and response wait; check no half-Step survives reset or scores twice. Then substitute the real bridge/BRAM, sweep phases and latency, and assert next-launch readiness every six game ticks. Alan authors Roman's official resolver tests; Roman authors Alan's service/bridge tests. Replay all 12 logs after this small test passes, with independently derived rule assertions beside the model comparison.

## Item 5 — Displayed Heading

### Working default and current behavior

**Engineering recommendation — high confidence:** sprites use the resolved Step's Heading and resulting head Cell as one pair. Do not rotate on a Pending Turn or READ2 launch. This is a display policy, not the Turn-validity register: control Heading still changes at launch as required to avoid review F3. **Locked requirements** fix Turn validity, movement and crashed head position, but do not specify which intermediate Heading the artwork shows. ADR 0003 item 5 proposes this display policy; it remains proposed.

**Implementation evidence:** `turn_unit.py:45–55` changes control Heading on launch. `step_unit.py:64–67,77–89` holds `shown` through launch, then updates both head Cells and `shown` at resolve; `retire()` changes only FSM state. `game_top.py:249–261,282–296` exports `step.shown` to the renderer. Thus “last committed Step” currently means **last resolved logical outcome**, not receipt of the COMMIT acknowledgement. The model executes Arena writes synchronously within `_fast_after_edge()` before latching that render state (`:241–247`), so the viewer cannot expose the physical gap.

For a crashed Bike the model still sets `shown` to its attempted launched Heading while retaining its last valid Cell. Keep this small cosmetic choice initially: the resolved Crash is a committed outcome even though that Bike did not advance. It helps show the failed Turn and respects the locked position rule. If the team means “last successful movement Heading” instead, say so explicitly; that would be a different Crash-only policy. It must not accidentally change control Turn validity.

### Alternatives and render consequences

| Sprite source | Benefit | Why not the first default |
|---|---|---|
| **Resolved Step Heading** | Sprite rotates with its new head/Trail geometry; one coherent pair to publish. | Requires a separate 2-bit shown register per Bike, already present in Python. |
| Launched Heading | Earlier feedback during READ2/COMMIT latency. | Turns at the old head Cell before movement, potentially pointing toward an unoccupied target for several slow ticks. Does not solve cell/snapshot coherence. |
| Pending Turn | Feedback as soon as an eligible input is consumed. | Can rotate repeatedly while stationary as requests replace the Pending Turn, and may preview a Turn that reset/phase transition prevents. Needs additional coherent input-derived state in the display path. A separate future Turn indicator is cheaper to reason about than repurposing the Bike sprite. |

At six ticks per Step, movement intervals are about **100 ms**. Waiting for movement therefore adds up to roughly one Step of feedback delay, plus input transport, resolution and display-publication latency. In Python the launch-to-outcome component is two ticks (~33 ms); hardware may differ. This is a playtest tradeoff, not evidence of unacceptable response. Measure press-to-visible feedback and keep launched/pending fields internal so the display choice remains cheap to change.

**Engineering recommendation:** `drawcon` receives two head Cells (7-bit cx, 6-bit cy), two **2-bit shown Headings**, Bike visibility, per-Bike Crash/blink state, and phase/Pause metadata needed by the selected layers, all from one held snapshot. Include a transaction/version association in the publication controller for verification. It does not need Pending Turns or launched Headings for this default. Reward codes can be drawn from port B; if explicit Reward positions/presence are also supplied, they must belong to the same visible Arena version. The current PC snapshot directly reads fast slot registers; that is not a hardware coherence solution.

Vblank snapshot changes alone are insufficient if the Arena has already changed mid-frame. **Candidate first-build integration**, subject to the separate render investigation: stage the short Step write list and matching snapshot, apply the list during vblank, then publish the matching snapshot before active drawing/prefetch resumes. Route all visible Reward mutations through the same publication discipline. Measure the additional wait in the six-tick budget; if it does not fit, use the render investigation's forwarding/display-copy alternative. This recommendation does not choose item 2's CDC or claim the live Arena is double-buffered.

Pin actual BRAM read latency/mode and avoid active-display same-address read/write exposure. See [[CS-256 Tron SystemVerilog Readiness Research#4. Coherent rendering and BRAM semantics]] and [[CS-256 Official FPGA Coding Practices#Arena memory and reset]]. [AMD UG473 v1.14, Conflict Avoidance, Tables 1-4/1-5](https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources) is the underlying reference identified there; this run reached its publication page, not the PDF table text. Do not claim generic WRITE_FIRST makes port B see a correct new value. Preserve the course's output-aligned coordinates and early ROM read by actual latency (course sprite tips, “Potential timing issues”; contract §4).

### Change triggers, consequences and first check

**Change the default if** measured press-to-move feedback consistently confuses Players in board playtests. Compare a launched-Heading preview against the same input trace, recording the added render/input coupling. Cost is low for a snapshot source mux plus tests/contract wording; Pending Turn preview also needs coherent replacement/eligibility handling. Neither requires changing collision rules or Arena encoding. If only Crash orientation is confusing, hold the previous shown Heading for crashed Bikes with a per-Bike enable: a small RTL/model change, but update any affected `p1`/`p2` log Heading expectations. If rendering tests show mixed Arena/snapshot versions, change publication scheduling/buffering rather than the Heading policy; that is a separate, potentially moderate implementation cost.

**Model/scenarios/contract:** keep present shown-Heading behavior; add targeted launch/resolve/Crash assertions because outcome-only logs cannot prove that sprites stayed unchanged in between. Contract §3's generic “dirección” should distinguish control Heading, launched Heading and shown Heading, and specify that head Cell/Heading/Crash metadata publish together. No ADR or contract is edited by this research.

**Smallest first-build check:** start RIGHT, accept UP, launch, and delay READ2 and COMMIT responses. Assert the visible pair remains old Cell/RIGHT through Pending Turn and launch; after publication it becomes new Cell/UP together. Repeat with a Wall Crash: old Cell/UP plus Crash state, matching the current model. Inject a second Pending Turn while the first Step is in flight and verify it cannot rotate the displayed Bike. Publish at vblank with port B reading old/new head Cells around the boundary; assert each active frame uses one version, including the first prefetched sprite pixel. Repeat with Pause/reset before publication; reset must discard the stale snapshot. This is a small frame-boundary test, not a full VGA artwork test.

## Evidence run and remaining team choices

This research ran, with `PYTHONDONTWRITEBYTECODE=1`, `python3 -m unittest discover -s tests -p test_model.py` (**57 passed**) and `-p test_scenarios.py` (**4 passed**, including all 12 scenario/log pairs), from `prototipos/tron_fpga/`. The environment printed stream-fd warnings, but both commands exited 0. A separate inline Python check confirmed shown Heading holds at launch and changes with heads at resolve before retirement, the Crash-orientation detail, and survivor **39 + 3 Reward + 3 Survival Bonus = 45** against goal 40. No HDL simulation, routed timing/CDC check or board measurement was performed; future testbenches above are proposals.

The team can proceed with these working defaults while choosing X1 independently. Confirm the READ2/game-domain ownership and shown-Heading semantics, including the Crash-only interpretation; settle publication/Pause timing together with the render note. Bridge choice and measured six-tick feasibility remain engineering work with a clear fallback, not reasons to delay the pure resolver. This file changes no model, scenario, contract, ADR or locked decision record.
