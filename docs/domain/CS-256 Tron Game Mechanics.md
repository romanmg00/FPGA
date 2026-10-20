---
schema_version: 1
id: cs256-tron-game-mechanics-20261014
title: CS-256 Tron Game Mechanics
type: note
subject: CS-256
status: active
created_at: "2026-10-14T23:00:00"
updated_at: "2026-10-20T14:21:11"
term: 2026-fall
sources:
  - "[[CS-256 Tron Game Overview]]"
  - "[[CS-256 Tron Glossary]]"
review_status: unreviewed
tags:
  - tron
---

# CS-256 Tron Game Mechanics

The game rules on one page, for group discussion. Capitalised words are defined in [[CS-256 Tron Glossary]]. Each rule is marked:

- ✅ agreed
- 🔵 proposed, not yet agreed
- ⏳ waits for the rendered size test

**Discussion closed and decisions locked on 20 October 2026:** see [[CS-256 Tron Agreed Specification 2026-10-20]] for the consolidated agreed baseline. The schedule and Arena layout remain tentative/revisable as explicitly requested. Remaining implementation investigations are not additional unanswered game-rule choices.

**Authority:** course requirements and the TAs' strict-architecture instruction take precedence, followed by the **team repository's interface contract**, updated with these meeting decisions. This note and the glossary are synchronized references; discrepancies in existing code must be reconciled to that contract. The current remote contract has not yet been updated during this interview.

> [!info] Team decisions, 20 October 2026
> Course requirements take precedence. The team selected a configurable Points Goal (default 10), three Rewards worth +1/+1/+3, a +3 Survival Bonus, the last valid Turn, and a wait for Start between Rounds. P1 uses board buttons and P2 uses WASD over USB-UART. The first integrated build contains the core game, chosen scoring, sprites, these inputs and the 7-segment Scoreboard; HUD follows. See [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]]. The Python models still implement their previous rules until reconciled.
>
> The TAs’ strict-handout instruction is confirmed: the final game uses the divided approximately 60 Hz game clock, with the pixel clock for video. See [[0002-follow-ta-divided-game-clock]].

## Match and Rounds

- ✅ Two Players, each steering one Bike, in a shared Arena surrounded by Walls.
- ✅ A Match is a series of Rounds. Every Round starts with an empty Arena and both Bikes at their start positions.
- ✅ Each Player starts the Match with **3 Lives**.
- ✅ The first Player to reach or exceed the **Points Goal** wins the Match immediately. The Points Goal defaults to **10** and is configurable using the leftmost board switches **SW15 and SW14** (team decision, 2026-10-20).
- ✅ Reading the two-bit field as `{SW15, SW14}`: `00` → 10, `01` → 20, `10` → 30, `11` → 40. Both switches down selects the default 10.
- ✅ Sample the Points Goal when a new Match starts and keep it fixed across all its Rounds. Mid-Match switch changes affect the next Match (team decision, 2026-10-20).
- ✅ Otherwise, a Player who reaches zero Lives loses the Match, regardless of their Points total (team decision, 2026-10-20).
- ✅ Evaluate each Step as one simultaneous update: resolve movement/Crashes, award collected Reward Points and any Survival Bonus, then evaluate Match victory. If both reach or exceed the Points Goal in the same Step, the higher final Points total wins; equal totals are a Draw. If neither reaches the goal and both lose their final Life in the same Step, the higher final Points total wins; equal totals are a Draw. Otherwise, the Player at zero Lives loses (team decision, 2026-10-20).
- ✅ After the Match ends, gameplay freezes with final Points and Lives retained; the Scoreboard continues alternating its views. One Start press begins a new Match: Lives go back to 3, Points to 0, the goal switches are sampled and the Arena is prepared (team decision, 2026-10-20).
- ✅ Working start Cells: **P1 `(20,27)` heading RIGHT; P2 `(59,27)` heading LEFT**, with each 32 × 32 Bike sprite centred on its head Cell. These positions use the selected Arena layout and remain revisable with it after testing (team decision, 2026-10-20).
- ✅ After a **non-final** Crash freeze, the next Round is set up and waits for either Player to request Start: board BTNC or Space/Enter from the UART controller. This is the Round-ready wait, separate from the debugging pause switch (team decision, 2026-10-20).
- ✅ After a non-final Crash, show crashed Bikes blinking at their last valid Cells for approximately **2 seconds**, then prepare the next Round and wait for a **fresh Start press**. Ignore Turns/Start during the effect; no pre-start steering or countdown. If that Crash ends the Match (last Life or scored Points Goal), retain the winner immediately, show the same effect, then go to Match-over **without preparing another Round**. A Points Goal reached without a Crash goes directly to Match-over (team decision, 2026-10-20).
- ✅ At power-up, wait for Start. One Start press from power-up or Match-over prepares the Match and begins its first Round as soon as preparation completes; do not require a second press. Between subsequent Rounds, keep the fresh-Start rule above (team decision, 2026-10-20).
- ✅ Keep the mirrored starts. Their odd Manhattan separation makes same-Cell Head-on Crashes unreachable in ordinary equal-speed play from these starts; swapping remains possible. Retain both collision rules and verify same-Cell Head-on Crashes using deliberately arranged test positions (accepted Q35 recommendation, 2026-10-20).

## Movement

- ✅ Bikes never stop. Every Step, each Bike advances one Cell along its Heading.
- ✅ A Player can Turn 90° left or right. A 180° reversal is ignored.
- ✅ If a Player presses several directions between two Steps, the last valid Turn is applied at the next Step (team decision, 2026-10-20).
- ✅ A Turn is judged against the Bike's current Heading. Pressing that Heading or a reversal does not cancel a Pending Turn. For example, RIGHT → UP → LEFT requests result in an UP Turn.
- ✅ Keep one Pending Turn: a later valid request replaces the previous request, and older requests are not replayed. Process each Player's requests in arrival order, matching PC keyboard-event order and UART byte order (team decision, 2026-10-20).
- ✅ For board buttons, use debounced press events in their sampled arrival order. For valid Turns first observed in the same sample, use a fixed tie priority **UP > RIGHT > DOWN > LEFT**, after rejecting same-Heading and reversal requests. This is the simple implementation fallback authorized by Q10; it does not give either Player movement priority.
- ✅ Turn requests are ignored while no Round is running; starting a Round uses the recorded initial Headings with no pre-start steering (team decision, 2026-10-20).
- ✅ Movement is stepped (Cell by Cell) for now. Smooth movement is a possible later upgrade.
- ✅ Default speed: **one Cell every six divided-game-clock ticks**. At approximately 60 Hz and 16 px per Cell, this is approximately **10 Cells/s or 160 px/s**. Keep speed fixed for the first build and tune through playtesting (team decision, 2026-10-20). These are slow game-clock ticks, not pixel clocks or an assumed video-frame lock.

## Trails and Crashes

- ✅ Every Cell a Bike passes through becomes part of its Trail, including the Cell it is in now. Trails are one Cell wide and stay until the Round ends.
- ✅ A Bike Crashes if it moves into a Wall, any Trail (including its own), or the same Cell as the other Bike in the same Step.
- ✅ Head-on Crash: if the two Bikes enter the same Cell, or swap Cells, in one Step, both Crash.
- ✅ Both Bikes move at the same time; neither has priority.
- ✅ In a Step where one Bike Crashes, that Bike stays at its last valid Cell. The other Bike still completes its move, leaving Trail and collecting any Reward it enters.
- ✅ A Crash ends the Round, and the crashed Player loses one Life. If both Crash in the same Step, both lose a Life.
- ✅ After a Crash, show approximately 2 seconds of blinking crashed Bikes. Then enter Match-over if a winner/Draw was determined, or prepare the next Round and wait for Start as agreed above.
- ✅ No timeout ends a long Round. Reaching the Points Goal ends the Match, including the current Round.

## Points

- ✅ Points come from **Rewards** and the **Survival Bonus**. They carry over between Rounds and reset only at a new Match.
- ✅ **Survival Bonus:** when one Player Crashes, the Player who did not Crash gains **+3 Points**. Neither receives the bonus if both Crash (team decision, 2026-10-20).
- ✅ **Remove the obsolete 99-Point cap.** The selected 10/20/30/40 Points Goal ends the Match. Keep the full final-Step total for the agreed comparison; reaching or exceeding the goal wins, without wrapping or a newly introduced goal clamp.
- ✅ In a Step where one Bike Crashes, the surviving Player receives any collected Reward's Points and the +3 Survival Bonus before Match victory is evaluated. A crashed Bike cannot collect from a Cell it failed to enter. There is no separate 99-Point gameplay cap.

## Rewards

- ✅ Three single-Cell Rewards are maintained in the Arena: **two worth +1 and one worth +3** (team decision, 2026-10-20).
- ✅ Each appears at a pseudorandom empty spot. When collected, request replacement by a new Reward of the same kind. Its slot may remain temporarily absent while hardware searches; movement continues and replacement occurs as soon as placement succeeds (team decision, 2026-10-20).
- ✅ Normal games use pseudorandom Reward placement with a seed influenced by Start timing; tests provide a fixed-seed mode for reproducibility (team decision, 2026-10-20). This is pseudorandomness, not a claim of physical true randomness.
- 🔵 Implementation follow-up requested by the team: select and verify the exact generator, seed capture, advancement schedule, occupied-Cell rejection and bounded/multi-frame placement service. The existing generators differ and still need reconciliation. Revalidate occupancy before committing a pending placement and preserve the agreed full-Arena behavior.
- ✅ The Cells a Bike drives through while collecting become its Trail, as usual.
- ✅ Prepare all three initial Rewards, Walls and Bikes before a Round becomes ready or starts. This preparation precedes the one-press first-Round launch and the subsequent-Round fresh-Start wait (team decision, 2026-10-20).
- ✅ If the Arena has no empty Cell left, a collected Reward remains absent until the next Round. Three Reward slots are maintained, but fewer than three Rewards may be visible during replacement or in a full Arena (team decision, 2026-10-20).
- ✅ Reward sprites are **16 × 16 px**, half the Bike sprite's side and one Cell wide (team decision, 2026-10-20).

## Controls

| Who | Input | Actions |
|---|---|---|
| P1 | Board buttons BTNU / BTNL / BTND / BTNR | Turn |
| P2 | PC keyboard, W / A / S / D, through the team's web controller page (Chrome or Edge, Mac or Windows) sending over USB-UART | Turn |
| Either | ✅ BTNC (N17), or ✅ Space / Enter on the controller page | Start; either Player may release the next Round's ready wait |
| Anyone | CPU_RESETN (red button) | Hard reset: back to power-up state |
| Anyone | ✅ SW0 up / down | Pause / resume game state and game timers immediately; not a reset or Setup Phase switch |

✅ While SW0 is up, ignore steering and freeze gameplay/timers. Resume immediately when it goes down. Keep video and Scoreboard cycling; do not stop clocks to pause. CPU_RESETN clears the game and returns to waiting for Start (team decision, 2026-10-20).

✅ The controller page only sends; it does not receive. Two-way UART (the board sending Points and Lives back to the page) stays an option for the UI/HUD session.

## Scoreboard (7-segment)

- ✅ Use all **8 physical 7-segment digits**: the **left four belong to P2**, the **right four to P1** (team revision, 2026-10-20).
- ✅ Each Player's four-digit bank uses its left two digits as a label and right two as a decimal value: `P2 nn` / `L2 nn` for P2, and `P1 nn` / `L1 nn` for P1. `P` identifies Points and `L` identifies Lives. Thus each Player has a Points view and a Lives view.
- ✅ Show the **Points view for 3 seconds**, then the **Lives view for 3 seconds**, repeating continuously. Digits remain visible; there are no intentional dark/blink periods (team decision, 2026-10-20).
- ✅ Both Player banks switch views together. Start each new Match on Points, show current values, and continue cycling during Crash, ready wait, debug pause and Match-over (accepted Q20 recommendation, 2026-10-20). Rapid digit multiplexing is separate from this three-second view timer.

## Display sizes

- ✅ **16 px Cells, 32 × 32 px Bike sprites and 16 × 16 px Reward sprites**, on the course's **1280 × 800 px** visible image. This gives an **80 × 50** screen grid before Walls and HUD reservations (team decision, 2026-10-20). Bike collision remains based on its head Cell; the larger sprite is cosmetic.
- ✅ Working layout: reserve a **64 px top band** for the later HUD: **four 16 px Cell rows**, or **8% of image height**. Bikes and Rewards cannot enter it. Preserve the required 10 px white border, keep text inside the band and favor the game's visible area over larger text. Use **32 px HUD text** as the initial layout (accepted Q23 recommendation, 2026-10-20).
- ✅ Working Arena bounds follow the current geometry model: a separate **16 px Wall below the HUD**, with interior `cx=1..78`, `cy=5..48`, giving **78 × 44 playable Cells**. Playable pixels span `x=16..1263`, `y=80..783`.
- ✅ These layout bounds are **provisional and revisable after game review/testing**, not a hard lock (team clarification, 2026-10-20). Record any revision consistently in the contract, notes and implementations. Until revised, fit text within the selected band rather than growing it implicitly.
- ✅ Store Bike and Reward sprites at their native sizes in **12-bit RGB444 `.coe` ROM data**; do not use the team's prior indexed-image/2× enlargement format as the selected asset contract (team decision, 2026-10-20).
- ✅ Centre Bike sprites on their head Cells. In RGB444 sprite data, **`000` is transparent** and **`0F0` is the Player-colour tint key**. Do not reserve `080` as an extra dim/glow key in the core format; remove/remap candidate glow-key art before claiming it follows that format (team decision, 2026-10-20).
- ✅ Initial Player colours: **P1 cyan, P2 orange**. Glow, scanlines and animated backgrounds remain optional after the core game works (team decision, 2026-10-20).
- ⏳ Final HUD contents and monitor validation remain for the later HUD/playtest work.

## Beyond the core game

✅ First integrated build scope (confirmed 2026-10-20): movement, permanent Trails, Crashes, Rounds/Lives, the Points Goal, three Rewards (+1/+1/+3), the +3 Survival Bonus, Bike sprites, P1 board buttons, P2 USB-UART and the 7-segment Scoreboard. Simultaneous finishes and temporary Reward absence are settled above; the placement implementation and its cycle budget remain open.

- **Should:** On-screen HUD.
- **Extras after the core build:** Menus, finite Trails, smooth movement and live configuration. These are not requirements for the first integrated build.
- ✅ SW15/SW14 select a Points Goal of 10/20/30/40; default 10. Sample only at new-Match Start.
- **Other proposed extras:** Setup Phase with switch-chosen Player colours, background and options (the Master is whoever sets the switches); challenge settings (e.g. speed).
- **Won't this term:** Power-ups.
