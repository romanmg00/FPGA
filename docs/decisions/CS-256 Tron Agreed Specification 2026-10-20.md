---
schema_version: 1
id: cs256-tron-agreed-specification-20261020
title: CS-256 Tron Agreed Specification 2026-10-20
type: note
subject: CS-256
status: active
created_at: "2026-10-20T14:17:26"
term: 2026-fall
decision_status: agreed
sources:
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
  - "[[CS-256 Tron Game Mechanics]]"
  - "[[CS-256 Official FPGA Coding Practices]]"
  - "[[CS-256/cs256-fall-2026/classproject/README]]"
  - "[[CS-256/cs256-fall-2026/classproject/sprites/README]]"
review_status: unreviewed
tags:
  - tron
  - specification
---

# CS-256 Tron Agreed Specification 2026-10-20

The team requested that the decisions reached in the 20 October discussion be locked and explained. This note consolidates the agreed baseline; [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] retains the question-by-question provenance. **The Arena layout and schedule remain explicitly tentative and revisable after testing.** Agreement on a rule does not claim that its implementation has been migrated or verified.

## Authority, repository and team

Course requirements and the TAs' instruction to follow the handout architecture strictly take precedence. The next authority is the **interface contract in [romanmg00/FPGA](https://github.com/romanmg00/FPGA)**, once reconciled with these decisions. Local mechanics, glossary, plans and both prototypes must agree with it.

The team is **Roman and Alan**. Kevin is no longer a member, as instructed by the TAs. One shared **headless rules model in the team repository** will serve both PC viewers and HDL verification; the viewers must not maintain independent rule implementations.

The remote contract and executable implementations have **not** been changed by this decision-recording session. Their older single-clock/PS2/single-rayo/Scoreboard assumptions are implementation discrepancies to reconcile, not reasons to override this agreed baseline. The course repository remains reference-only.

## Match, Points Goal and scoring

- Two Players begin each Match with **3 Lives and 0 Points**. Points and remaining Lives carry between Rounds.
- The first Player to reach **or exceed** the selected **Points Goal** wins. Otherwise, losing the final Life loses the Match.
- Capture the goal only when starting a **new Match**. Hold it across all that Match's Rounds; switch changes apply to the next Match.

| `{SW15, SW14}` | Points Goal |
|---|---:|
| `00` | **10**, default |
| `01` | 20 |
| `10` | 30 |
| `11` | 40 |

Each Step is evaluated simultaneously: resolve movement and Crashes, award any collected Reward and the Survival Bonus, then evaluate victory. If both reach the goal in the same Step, higher final Points wins; equal totals are a Draw. If neither reaches it and both lose their final Life in the same Step, higher final Points wins; equal totals are a Draw.

**The old 99-Point cap is removed.** The selected goal is the victory threshold, not an additional 99-Point rule. Retain the full final-Step total, consistent with the agreed simultaneous-finish comparison: for example, 19 + 3 = 22 wins a goal-20 Match. This does not introduce clamping to the goal. Storage and addition widths must accommodate the complete legal final Step without wrapping.

## Movement, Turns and Crashes

- Move one **16 px Cell every six approximately 60 Hz game-clock ticks**: about **10 Cells/s, 160 px/s**. Keep the first build's speed fixed; tune through playtesting.
- Turns are 90 degrees. Ignore 180-degree reversals and same-Heading requests without cancelling a valid Pending Turn.
- Retain **one Pending Turn**, the last valid request against the current Heading. New valid requests replace old ones; there is no LIFO stack replay.
- Preserve ordered keyboard/UART requests. Debounced board events use sampled arrival order. For valid requests tied in one sample, the authorized simple fallback is **UP > RIGHT > DOWN > LEFT**. This does not give either Player movement priority.
- Ignore steering outside running play, including the Crash display, ready wait and debug pause.
- Trails are permanent, one Cell wide, include the occupied head Cell and clear between Rounds.
- Read both target Cells before committing either move. Crashing into a Wall, either Trail or the other Bike is fatal. Same-target and head-swapping moves Crash both Bikes.
- A crashed Bike remains at its **last valid head Cell** and loses one Life. The surviving Bike completes its Step and can collect a Reward. Both Crashing costs both one Life.
- No timeout ends a long Round. A Crash ends it, or reaching the Points Goal ends the Match and its current Round.

## Rewards and randomness

Maintain three independent single-Cell Reward slots: **+1, +1, +3**. When exactly one Player Crashes, the survivor earns a **+3 Survival Bonus**; neither gets it when both Crash.

Prepare **all three initial Rewards before releasing a Round**. After collection during play, the replacement may remain absent while the hardware searches; gameplay continues. Replacements must occupy empty playable Cells and cannot overlap Walls, Trails, Bikes, HUD or other Rewards. If no empty Cell exists, that slot remains absent until the next Round.

Use **pseudorandom** placement, with a seed influenced by Start timing in normal play and a fixed-seed mode for repeatable tests. The exact generator, seed capture/advancement and bounded placement-service schedule remain an explicit engineering investigation. Model and HDL must eventually implement the same selected sequence and schedule. Revalidate a pending candidate before committing it if gameplay has changed occupancy.

## Start, Crash display, Pause and reset

- **Power-up:** wait for Start. A single Start captures the goal, resets Match Points/Lives, prepares Walls/Bikes/all three Rewards, then begins the first Round. No second press or countdown is required.
- **Non-final Crash:** freeze gameplay and blink crashed Bikes at their last valid Cells for approximately **2 seconds**. Ignore Start and Turns during this display. Then prepare the next Round and wait for a **fresh Start**; no pre-start steering or countdown.
- **Match-ending Crash:** calculate and retain the winner immediately, still show the **2-second Crash display**, then enter the final waiting state. Do not prepare another Round. Start becomes eligible after that effect.
- **Goal without a Crash:** go directly to the final waiting state.
- **Final waiting state:** retain final Points/Lives. One fresh Start prepares and launches a new Match as above.
- **SW0 up:** pause logical game state and game timers; ignore steering. **SW0 down:** resume immediately. Keep clocks, video and Scoreboard cycling.
- **CPU_RESETN:** clear the game and return to waiting for Start. In-flight memory/input results must not corrupt the reset state; handling them is an implementation obligation.

Start is accepted from **board BTNC (N17)** or **Space/Enter on the browser UART controller**. Either Player can start a Round/Match. P1 steers with board directional buttons; P2 uses WASD through USB-UART. Retain the existing 115200-baud, 8N1 plan; the controller/decoder wire encoding for Enter remains a documented implementation task.

## Physical Scoreboard

Use all eight 7-segment digits. **P2 owns the left four; P1 owns the right four.** Each bank has a two-character label and two decimal value digits.

| View | Left bank, P2 | Right bank, P1 | Duration |
|---|---|---|---|
| Points | `P2 nn` | `P1 nn` | 3 seconds |
| Lives | `L2 nn` | `L1 nn` | 3 seconds |

Both banks change views **together**, continuously visible, with **no intentional dark/blink periods**. Begin a new Match on Points, display current values and continue alternating during Crash, ready wait, Pause and Match-over. The rapid digit scan is separate from the three-second view timer.

In the course numbering, P2 uses `dig7..4`, P1 `dig3..0`. The project decoder must support P and L; leave the course homework reference unchanged.

## Video, sprites and working layout

- Course video: **1280 × 800**, RGB444, requested **83.46 MHz pixel clock**, approximately 60 Hz refresh, and a visible **10 px white border**.
- Working geometry: **16 px Cells**, **32 × 32 Bike sprites**, **16 × 16 Reward sprites**. Bikes are centred on their head Cells; collision is based on the head Cell, not the artwork footprint.
- Reserve **64 px at the top for HUD**, four Cell rows and 8% of image height; start with **32 px text**. A separate 16 px Wall below it yields **78 × 44 playable Cells**, `cx=1..78`, `cy=5..48` (pixels `x=16..1263`, `y=80..783`). Keep HUD text subordinate to gameplay and inside the selected band.
- Working starts: **P1 `(20,27)` RIGHT; P2 `(59,27)` LEFT**. Preserve mirrored starts. Same-Cell Head-on Crash remains a tested rule using arranged test positions, even though ordinary mirrored starts only permit the swapping case.
- The team explicitly permits revising these **layout/start choices after game review/testing**. This lock records the current baseline; it is not a hard geometry freeze. Record any revision consistently.
- Use native-size **12-bit RGB444 `.coe` ROM data**: 1024 words per Bike, 256 per Reward. Use `000` for transparency and `0F0` for Player tint; initial colours are **P1 cyan, P2 orange**. No special `080` dim/glow key in the core format.
- Follow the handout's output-aligned coordinates and combinational drawing baseline. Start ROM reads early enough for the **actual generated latency**; the course's 2-cycle ROM is an example, not a universal constant.

## Clocks, Arena encoding and service boundary

The TAs' strict architecture and Q32 are settled: the game-state clock is **approximately 60 Hz from the second Clocking Wizard plus divider counter**. Video and memory service run at a suitable fast clock. A frame enable on a wholly pixel-clocked game engine is not the selected architecture. See [[0002-follow-ta-divided-game-clock]] and [[CS-256 Official FPGA Coding Practices]].

The Arena allocation is **8192 × 4-bit words**, addressed with 13-bit `{cy[5:0], cx[6:0]}` for the padded 128 × 64 grid. Codes must match in the shared model and HDL:

| Code | Meaning |
|---:|---|
| 0 | Empty |
| 1 | Wall / inaccessible Cell |
| 2 / 3 | P1 Trail / head |
| 4 / 5 | P2 Trail / head |
| 6 | Crash |
| 7 | Reserved |
| 8 / 9 / 10 | Reward slots 0 / 1 / 2 |

The fast Arena controller is the memory write owner. Define coherent slow-domain requests/results and render snapshots; check read/write collisions, transfer latency/backpressure, initialization, reset and Pause behavior. A slow game clock is not inherently aligned with blanking. No specific FIFO/handshake circuit or measured implementation bound is claimed by these decisions.

## Work division and independent verification

| Member | Agreed responsibilities |
|---|---|
| **Roman** | VGA/clock generation, renderer, sprite ROMs, later HUD; HDL movement/Turn handling and collision resolution (G1/G2) |
| **Alan** | HDL Round/Match control, Lives and scoring (G3/G5); shared headless model/viewer adapters; Arena/fast memory and Reward placement (A1/A2/G4); inputs/UART/web controller, Scoreboard; top-level integration, constraints and build automation |
| **Both** | Interface contract, game/service/render boundary, integration/playtests, official tests for the other's blocks, timing/CDC/DRC review and evidence for their individual reports |

Keep register ownership explicit across the shared HDL engine. Roman's Step logic reports movement/Crash/collection results; Alan's phase/scoring logic owns the Match/Round lifecycle, Lives and Points. Alan coordinates the reference model; because both now author HDL game blocks, independence is maintained through per-block cross-testing, not a claim that one person authors the entire model and another the entire engine.

## Scope and tentative schedule

The agreed **core scope** is movement, permanent Trails, Crashes, Rounds/Lives, the selected Rewards/Survival Bonus/goal, memory-backed sprites, board/UART inputs and the alternating physical Scoreboard.

The **HUD follows the core**. Menus, finite Trails, smooth movement, live customization, glow, scanlines and animated backgrounds are extras. Power-ups remain out of this term's scope.

**The schedule is tentative and flexible**, including feature staging and the proposed freeze targets. Aim for a pre-demo build around **15 November** and a demo-code freeze around **23 November**, adjusting to progress with the two-person team. Do not interpret the old post-freeze Reward/Scoreboard schedule or a complete-core-on-15-November proposal as an unqualified commitment. The selected core remains the target scope; changing it requires recording an explicit scope revision.

The **course assessment dates remain fixed**: pre-demo **19 November**, group demo **30 November**, individual report **10 December**. The team's flexible targets do not change these deadlines. Keep the existing Sunday–Thursday planning convention as a working organization, not a newly imposed delivery constraint.

## Remaining implementation work

1. Reconcile the authoritative team contract and both projects' constants/interfaces to this baseline; migrate to one rules model and viewer adapters.
2. Select/verify the exact pseudorandom generator, seed capture and placement schedule.
3. Implement and measure the fast-memory/slow-game transfer, coherent rendering, and reset/Pause behavior without dropped or stale transactions.
4. Finish UART Enter encoding and event buffering, project P/L glyphs, assets/COE generation and clock/IP/constraints setup.
5. Run meaningful model/HDL scenarios, sprite-boundary/latency tests, reset/Pause stress tests and board playtests; record Vivado/IP versions and routed timing/CDC/DRC evidence.

These are identified engineering tasks, not claims of completed implementation or additional unanswered gameplay decisions.
