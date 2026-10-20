---
schema_version: 1
id: cs256-tron-development-plan-20261015
title: CS-256 Tron Development Plan
type: plan
subject: CS-256
status: draft
created_at: "2026-10-15T16:58:26"
updated_at: "2026-10-20T14:21:11"
term: 2026-fall
sources:
  - "[[CS-256 Tron Game Mechanics]]"
  - "[[CS-256 VGA and Sprite Design Plan]]"
  - "[[CS-256 Official FPGA Coding Practices]]"
  - "[[CS-256 L11 Slides]]"
review_status: unreviewed
tags:
  - tron
  - schedule
---

# CS-256 Tron Development Plan

The week-by-week plan for building the Tron game in time for the pre-demo, the demo and the report. Game terms follow [[CS-256 Tron Glossary]]; the rules are in [[CS-256 Tron Game Mechanics]].

> [!info] Agreed baseline recorded, 20 October 2026
> The user closed the discussion and locked the decisions in [[CS-256 Tron Agreed Specification 2026-10-20]]. The two-person ownership, core rules and divided-game-clock architecture are settled. The **schedule, feature staging and working Arena layout remain tentative/revisable**. Open items below are engineering and verification work, not unapproved replacements for the agreed rules.

> [!info] Team reconciliation in progress, 20 October 2026
> [[CS-256 Tron Agreed Specification 2026-10-20]] and [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] supersede conflicting older values below: selected Points Goals 10/20/30/40 (default 10, captured at new-Match Start), Rewards +1/+1/+3, Survival Bonus +3, no 99-Point cap, last valid Turn, and BTNC/UART Space/Enter Start. Geometry is the revisable 16 px Cell / 32 px Bike / 16 px Reward / 64 px HUD layout. Speed is one Cell per six slow ticks; non-final Crashes show two seconds of blinking before preparation/fresh Start, while final Crashes show the effect then enter Match-over. P2/P1 Scoreboard banks alternate together every three seconds. One Start launches a prepared new Match with all three initial Rewards. Implementation and the remote contract still need reconciliation; the schedule is explicitly tentative.

## Planning vocabulary

These words are for this plan only; they are not game terms.

- **Week:** a KAUST work week, Sunday to Thursday.
- **Objective:** a deliverable with a done check. Objectives are listed in [Work list](#work-list).
- **Task:** one step of an Objective. Each Objective is split into Tasks when it is scheduled.

## Calendar and freezes

| Week | Dates (Sun–Thu) | Fixed events |
|---|---|---|
| W0 | Thu 15 Oct | Planning starts |
| W1 | 18–22 Oct | Look Prototype; design lockdown target Thu 22 Oct |
| W2 | 25–29 Oct | Game Model verification ready Thu 29 Oct |
| W3 | 1–5 Nov | |
| W4 | 8–12 Nov | Last build week for the pre-demo build |
| W5 | 15–19 Nov | **Tentative pre-demo build target Sun 15 Nov.** Course pre-demo Thu 19 Nov (individual) |
| W6 | 22–26 Nov | **Tentative demo freeze Mon 23 Nov.** Buffer for fixes/rehearsal |
| W7 | 29 Nov–3 Dec | Demo Mon 30 Nov (group) |
| W8 | 6–10 Dec | Report due Thu 10 Dec (individual) |

**Tentative planning targets:** pre-demo build around **15 November** and demo-code freeze around **23 November**. The team explicitly kept the schedule/feature staging flexible in Q40; these are not hard commitments. The **course assessment dates** (19 November pre-demo, 30 November demo, 10 December report) remain fixed. The older 26 November team-contract freeze is not the selected target.

- **Pre-demo target (around Sun 15 Nov, tentative):** work toward the agreed core, including Rewards/scoring and the alternating Scoreboard, with staging adjusted to actual two-person progress. The scope is agreed; completing every feature on that date is not a hard commitment.
- **After the tentative pre-demo build target:** prioritize validation, fixes, individual preparation and any unfinished core work. HUD follows the core if time allows. The old automatic deferral of Rewards/scoring/Scoreboard to this week is superseded by flexible staging.
- **The 4 buffer days before the pre-demo:** each person writes a short individual brief: the design, their own modules and their test evidence. It is reused later for the report.

Working assumption: 6–8 hours per person per week.

Optional features (Should and Could tiers) are added only when the Must tier is done; no cut order is planned.

## Schedule

**Tentative working sequence**, revised after the two-member change and Q40. Each Week’s Objectives come from the [Work list](#work-list); revise staging based on integration evidence rather than treating these rows as hard commitments.

| Week | Objectives |
|---|---|
| **W1** 18–22 Oct | S1, S2, S3 · L1 → **L2 (Thu 22 Oct)** · M1 · V1 · I2 (UART RX testbench) |
| **W2** 25–29 Oct | L3 · M2 · V2, V3 · I1 · I2 on the board · G1, G2 (Cell size as a parameter, compared against Step logs) |
| **W3** 1–5 Nov | V4 · X1/X2 · A1/A2 · P2/P3 · I3/I4 · advance G3–G5 as interfaces become ready |
| **W4** 8–12 Nov | Integrate G1–G5, Arena, inputs, sprites and Scoreboard · board playtests (Z1/Z2) → tentative pre-demo target |
| **W5** 15–19 Nov | Z3 brief/rehearsal · core fixes/completion as needed · course pre-demo Thu 19 |
| **W6** 22–26 Nov | Tentative demo freeze Mon 23 Nov · fixes/rehearsal · Z4 |
| **W7–W8** 29 Nov–10 Dec | Demo Mon 30 Nov · Z5 report writing |

W3 is the heaviest week. G1/G2 sit in W2 and the Scoreboard (I4) in W3, ahead of its Must-tier deadline, to keep W3 and W5 manageable.

**Rolling detail:** only W1–W2 Objectives are split into Tasks now. Each later Week's Objectives are split at the meeting in the Week before.

### Meetings

| Slot | Purpose |
|---|---|
| **Tuesday 11:30** (weekly) | Review the current Week, unblock problems, split next Week's Objectives into Tasks |
| **Thursday after 14:30** | Integration build and board checks (Z1): merge, build, read the reports, run HW checks, save evidence. Closes the Week. Design lockdown + playtest (L2) uses the Thu 22 Oct slot |
| **Monday after 14:30** | Optional extra board time |

### W1 Tasks (18–22 Oct)

| Obj. | Tasks | Done when |
|---|---|---|
| S1 | Create the repo and invite all · agree a branch workflow · move `Game_research/` into it · check the myws Vivado version and pick the IP-generation version | All three can clone and push; Vivado version recorded in the README |
| S2 | Tcl script that builds the project from sources (`xc7a100tcsg324-1`) · build script: synthesis → implementation → bitstream + report set · program the board from each laptop (start with `test-dualcomb.bit`) | One command produces the V1 bitstream; each member has programmed the board once |
| S3 | xsim run script per testbench · `tb_frame_dump`: decodes sync → `.ppm` · `.ppm` → PNG helper | `tb_vga_out` runs with one command; one frame dumped and viewed |
| L1 | Viewer shell: 1280 × 800 (scaled to fit), RGB444 reduction, BRAM and clear-time readout · 2–3 HUD layouts · Bike art at 16/32/64 px · Cell sizes 4/8/16 with Arena dimensions · Reward look | Candidates ready to compare on Thursday |
| L2 | Playtest on M1 · go through the lockdown checklist · show the candidates on the lab monitor · update the mechanics note, glossary and VGA plan | Checklist signed off; mechanics note all ✅, or falls back to the existing design |
| M1 | Block functions (Step/Turn, Crash including Head-on, grid, Round/Match FSM, Rewards with LFSR, Points) · keyboard play (P1 arrows, P2 WASD) · rule values and Step rate as parameters | Two people can play a full Match |
| V1 | `vga_out` per handout steps 5–9 + switch colour · `tb_vga_out` checks (test table in the VGA plan) · Clocking Wizard 83.46 MHz + XDC · board: switch colour on the monitor, achieved frequency recorded | Testbench passes; monitor locks; `V1-*` evidence saved |
| I2 | UART receiver on `pixclk` (settings below): 2-FF sync, 16× oversampling · testbench: single and back-to-back bytes, a bad stop bit | Testbench passes |

W2 Tasks are split at the Tue 20 Oct meeting.

**UART settings (agreed 2026-10-15):** 115200 baud, 8N1. One ASCII byte per key press (`w`, `a`, `s`, `d`, space); upper and lower case are treated the same. The receiver plan uses `pixclk` (83.46 MHz). With the divided game clock selected on 2026-10-20, commands need deliberate transfer into the slow game domain, preserving order and the last valid Turn. Space and Enter are both selected Start keys; their shared wire encoding remains an implementation follow-up. The 16× oversampling divider is 45, giving 115,916 baud, 0.6% above 115,200 and well within UART tolerance.

## Scope tiers

As recorded in [[CS-256 Tron Game Mechanics#Beyond the core game]]:

| Tier | Contents |
|---|---|
| Must | All agreed rules (Rounds, 3 Lives, Trails, Crashes, Rewards, Survival Bonus); Bike sprite from BRAM; P2 over UART with the Web Serial page; 7-segment Scoreboard |
| Should | On-screen HUD |
| Could | Switch-chosen Player colours (Setup Phase); speed/challenge switch |
| Won't (this term) | Power-ups; smooth movement |

## Phases

### Look Prototype (W1)

A PC program for the HUD, sprite and Cell sizes, Bike art and the overall look of the game.

1. **Free design.** Any sizes or mock-ups are allowed. The viewer always shows the image at 1280 × 800 and reduced to RGB444. Anything that breaks the [FPGA limits](#fpga-limits-for-the-look-prototype) is marked "needs fixing before lockdown".
2. **Design review and playtest session.** Target Thu 22 Oct, both members. The 20 October working layout is 16 px Cells, 32 × 32 Bikes, 16 × 16 Rewards, a 64 px top HUD band and a 78 × 44 playable interior. Review art, readability, geometry and remaining 🔵/⏳ rules. Geometry is **not hard-locked**: revise it after game review/testing when needed, and keep the authoritative team contract, mechanics, glossary and implementations consistent. Record accepted rules as ✅; the review date alone does not approve unanswered proposals.
3. **Constrained asset flow (after lockdown, W2).** PNG → `png2coe.py` → `.coe` → viewer. The viewer draws sprites from the `.coe` files, so the PC shows exactly what the ROMs will hold.

### Game Model (W1–W2)

The game logic in software, as the ground truth recommended in [[CS-256 L11 Slides]] (p. 44). Level: **it mimics the hardware's functional architecture** (one function per hardware block), and it is **bit-accurate only where it can be seen**: Cell coordinates, Points/Lives and final-Step totals with the selected Points Goal; no obsolete 99-Point cap, and the same LFSR as the HDL for Reward placement. It is checked once per Step, not per clock cycle, so it does not depend on the clock design.

- **Selected on 20 October:** one shared, headless rules model in the team repository, imported by the PC viewers and used for HDL verification scenarios. The current local `prototype/model/` and team `prototipos/tron/juego.py` are migration inputs, not two continuing rule authorities. Choose the migration base/location and viewer adapters during implementation planning.
- Playable by Thu 22 Oct, for the playtest session.
- Step logs, scenario files and the diff script ready by Thu 29 Oct.

### HDL build (W1–W5)

The handout steps (V1–V4), setup (S1–S3) and device I/O (I1–I3) do not depend on the prototypes and start in W1. Game logic (G), the Arena grid (A), the sprite pipeline (P2) and the HUD (H2) start after lockdown, from W2.

## Verification

### Testbench or board

- **Testbench first, always**, for anything with logic: counters, FSMs, clock crossings, the grid controller, UART bit timing, pixel alignment.
- **Board check only for what simulation cannot show:** monitor lock and colours, real button bounce, a real browser sending over UART, 7-segment visibility, game feel and speed, repeated reset and pause.
- **Timing, CDC and DRC reports on every weekly integration build** (commands in [[CS-256 Official FPGA Coding Practices#Evidence to collect before choosing or shipping either path]]).
- A Task is done when its testbench passes. An Objective marked HW is done only after its board check.

### Step-log comparison

Use only the parts of the L11 testing methods that help this project:

1. A **scenario file** lists the inputs for each Step (P1/P2 Turn requests, Start).
2. The shared headless Game Model and the HDL testbench both read it, and each writes a **per-Step state log in the same text format**: head Cells, Headings, Crash flags, Points, Lives, Reward Cells. The testbench only writes, with `$fwrite` (L11 p. 40).
3. A short Python script compares the two logs and reports the first Step where they differ.

Not used: self-checking SystemVerilog with `$fscanf` (L11 p. 41), and pixel-for-pixel frame comparison. `tb_frame_dump` (`.ppm`) stays, for looking at frames and for report figures.

Scenario set (L11 p. 43, corner cases). Add a scenario whenever a bug is found:

1. Each of the four Walls
2. Own Trail
3. Other Bike's Trail
4. Head-on Crash into the same Cell
5. Head-on Crash by swapping Cells
6. 180° input ignored
7. Two inputs between Steps (the last valid one wins)
8. Reward collected and respawned, with the respawn landing on an occupied Cell
9. Selected Points Goal reached/exceeded, including simultaneous finish and final-Step overshoot
10. Both Bikes Crash on their last Life (a Draw)
11. New Match after the Match ends
12. Long random game with random inputs from both Players (stresses the LFSR)

## FPGA limits for the Look Prototype

Every locked design element must pass these. They come from the hardware and from [[CS-256 Official FPGA Coding Practices]].

1. **1280 × 800, fixed.** Verified 2026-10-15: the [class handout](../cs256-fall-2026/classproject/README.md) sets the visible region to `hcount` 336–1615 (1,280 pixels) and `vcount` 27–826 (800 lines), with `curr_x` 0–1279 and `curr_y` 0–799. Its 83.46 MHz pixel clock over 1680 × 828 total gives 59.998 Hz.
2. **RGB444 only (4,096 colours).** Verified 2026-10-15: the Nexys A7 Reference Manual (revised 10 July 2019, §8, p. 18) says the board drives VGA with "4 bits-per-color" through resistor dividers, giving 16 levels per channel and "4096 different colors". The handout uses 4-bit `pix_r/g/b`, the sprite tips use 12-bit RGB `.coe` words, and the class XDC maps `VGA_R/G/B[3:0]`. The manual's timing example is 640 × 480, so it does not confirm the 1280 × 800 mode; that comes from the handout alone.
3. Sprites are square with power-of-two sides. The only rotations are the four 90° turns made by addressing. Black `000` is transparent and green `0F0` is the tint key. No alpha blending or scaling.
4. Cell side is a power of two (4, 8 or 16 px).
5. Each pixel's colour depends only on its own position and the game state, with a fixed layer order (race the beam, no framebuffer).
6. The viewer shows a live BRAM budget (sprite ROMs + Arena grid + HUD font ROM against 4,860 Kb) and the Arena-clear time against the vertical-blanking budget.

## Work list

Verified in: TB = testbench, HW = board check.

| ID | Objective | Verified in |
|---|---|---|
| **S: Setup** | | |
| S1 | Team repo, folder layout, Vivado version agreed (local 2025.2 vs myws) | — |
| S2 | Scripted build: Tcl project, synthesis/implementation, report set, `.bit` → laptop | HW (program once) |
| S3 | Simulation harness: xsim scripts and `tb_frame_dump` (`.ppm`) | TB |
| **L: Look Prototype** | | |
| L1 | Free design of HUD, sizes, Bike art, palette (replaces the earlier size test and UI/HUD session) | PC at 1280 × 800, RGB444 |
| L2 | Design lockdown and playtest session | team sign-off |
| L3 | Asset flow: Bike art and `png2coe.py` with checks (1,024 words, row order), viewer draws from `.coe` | script check |
| **M: Game Model** | | |
| M1 | Playable Game Model in hardware-block structure | playtest |
| M2 | Step logs, 12 scenarios, log-diff script | script |
| **V: Video, handout steps (built literally)** | | |
| V1 | `vga_out`: counters, sync, visible region + `tb_vga_out` | TB → HW (monitor lock, switch colour) |
| V2 | `curr_x/curr_y`, `game_top`, wizard moved to top, rectangle | TB → HW |
| V3 | `drawcon`: border, block, compositing | TB (frame dump) → HW |
| V4 | Divided game clock + generated-clock constraint; ±4 moving block with border limit (handout step 10, also the final game’s clock architecture per ADR 0002) | TB → HW |
| **X: Clock crossing (Path A)** | | |
| X1 | Game → render coherent snapshot and Arena command/result interface; restored by [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md). Verify memory-service scheduling and throughput | TB |
| X2 | Input synchronization/debounce and ordered button/UART command transfer into the divided game-clock domain; preserve valid requests | TB |
| **P: Sprites** | | |
| P2 | Bike ROM ×2, early-read pipeline, rotation by address | TB (first/last pixel, line/frame wrap, 4 rotations) → HW |
| P3 | Reward sprite(s) | TB → HW |
| **A: Arena** | | |
| A1 | Arena grid BRAM on `pixclk`: render read port, Walls | TB → HW |
| A2 | Grid controller: check/write commands, Arena clear with timing budget | TB |
| **G: Game logic** | | |
| G1 | Step/Turn: Heading, 180° ignored, last valid input, Step rate | TB |
| G2 | Crash: Wall, Trail, Head-on Crash (same Cell or swap) | TB |
| G3 | Round/Match FSM: Start, crash freeze + blink, respawn, Lives, Match end | TB → HW |
| G4 | Rewards: 3 on the Arena, random empty Cell, collect, respawn | TB → HW |
| G5 | Rewards/Survival Bonus scoring, selected Points Goal, simultaneous finishes and full final-Step totals | TB |
| **I: Device I/O** | | |
| I1 | Buttons: sync, debounce, Turn events; pause switch; CPU_RESETN | TB → HW |
| I2 | UART RX + WASD/Space decoder | TB (bit timing) → HW (serial terminal) |
| I3 | Web Serial controller page (Chrome/Edge, Mac and Windows) | HW |
| I4 | Scoreboard: BCD → `multidigit`, 8 digits | TB → HW |
| **H: HUD (Should)** | | |
| H2 | Digit font ROM + HUD renderer (layout comes from L2) | TB → HW |
| **C: Could** | | |
| C1 | Player colours from switches (tint key) | HW |
| C2 | Speed/challenge switch | HW |
| **Z: Integration and assessment** | | |
| Z1 | Weekly integration build + report checklist (timing, CDC, DRC) | reports |
| Z2 | Full-game playtest checklist | HW |
| Z3 | Individual pre-demo brief + rehearsal | — |
| Z4 | Demo script + rehearsal | HW |
| Z5 | Report evidence capture (every week) + individual report writing (W7–W8) | — |

## Report evidence

Each Objective's done check includes saving one piece of evidence for the reports: a waveform PNG, a `.ppm` frame, a board photo, or a timing/CDC report excerpt. Files go in `evidence/`, named `<ObjectiveID>-<short-name>.<ext>` (for example `V1-hsync-waveform.png`), and get one line in the log below. Both members’ individual reports draw from the same set.

| File | Objective | What it shows | Date |
|---|---|---|---|

## Ownership

**Team membership confirmed by the TAs, 20 October 2026: Roman and Alan only.** Kevin is no longer a project member; the previous three-person assignments and test rotation are superseded.

**Q33 direction:** distribute the HDL game engine between both members, otherwise keep the recommended division. The following module-level allocation implements that direction and is included in the final meeting record for review.

| Person | Design ownership | Independent official tests |
|---|---|---|
| **Roman** | VGA/timing and clock generation; renderer, Bike/Reward sprite ROMs, later HUD; HDL movement/Turn handling and collision resolution (V1–V4, L3, P2/P3, H2, G1/G2) | Alan’s Round/Match/scoring logic, Arena/controller, placement, inputs/UART and Scoreboard |
| **Alan** | HDL Round/Match control, Lives and scoring (G3/G5); shared headless model/viewer adapters (M1/M2); Arena/fast memory controller and Reward placement (A1/A2/G4); inputs/UART/web controller and Scoreboard (I1–I4, X2); top-level integration, constraints and build automation (S2) | Roman’s movement/collision blocks and VGA/sprite pipeline; compare HDL behavior with the shared model |
| **Both** | X1 game/service/render-snapshot contract; repository and verification harness; playtesting, integration, timing/CDC/DRC review and report evidence (S1/S3, L2, X1, Z1–Z5) | Co-review the complete board build and verify each other’s authored blocks from the contract |

Use separate game-engine responsibilities rather than both editing the same register-owning block. Roman’s Step logic reports movement, Crash and collected-Reward results; Alan’s phase/scoring logic owns Match/Round state, Lives, Points and Start/Pause handling. Alan’s fast Arena controller owns memory writes. Exact request/result/commit signals and register ownership must be fixed in the team contract before integration.

Alan coordinates the shared reference model, but both now contribute HDL game logic. The previous claim that the entire software model and entire HDL engine have different authors no longer applies. Preserve independence through the other member’s official tests and review of expected results for each block.

## Open items

1. Use the Q33 two-person split and cross-testing to revise the **tentative** 15/23 November targets and feature staging as progress becomes clear. Q40 explicitly keeps the schedule flexible; the course assessment deadlines remain fixed.
2. Clock architecture is settled on 2026-10-20: the TAs recommended strict handout architecture. Use the divided game clock and restore X1; see [[0002-follow-ta-divided-game-clock]]. The older [[CS-256 TA Email - Game Clock]] is a superseded draft, not a pending prerequisite. Design X1 before integrating game and renderer.
3. Implement and verify the decisions in [[CS-256 Tron Agreed Specification 2026-10-20]]. Q35 preserves mirrored starts; same-Cell Head-on Crash scenarios use arranged positions. Preparation must place all three initial Rewards; Match-ending Crashes retain the winner, show the two-second effect and then enter Match-over. The 99-Point cap is removed.
4. G4/A2: the current software search tries 64 LFSR draws (32 shifts each), then scans the padded grid. At selected **16 px Cells / 8192 words**, the existing idealized estimator gives `(64 × 32 + 8192) / 83.46 MHz ≈ 123 µs` per placement, or **246 µs for two**, before memory/controller overhead. The old 417/834 µs estimate applied to 8 px Cells. Neither estimate proves a feasible divided-game-clock interface or safe update timing. Verify a bounded or multi-frame placement service, occupancy revalidation and coherent transfers; do not pace an 8192-word bulk clear one word per 60 Hz tick.
5. Q36 keeps glow, scanlines and animated backgrounds optional after the core build. The core art convention uses only `000` transparency and `0F0` tint; `080` is not an extra glow key. Reconcile existing candidate art/effects before claiming core-format compliance. Any later colour stage must preserve the course-aligned pixel timing.

