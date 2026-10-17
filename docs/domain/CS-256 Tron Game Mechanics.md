---
schema_version: 1
id: cs256-tron-game-mechanics-20261014
title: CS-256 Tron Game Mechanics
type: note
subject: CS-256
status: draft
created_at: "2026-10-14T23:00:00"
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

## Match and Rounds

- ✅ Two Players, each steering one Bike, in a shared Arena surrounded by Walls.
- ✅ A Match is a series of Rounds. Every Round starts with an empty Arena and both Bikes at their start positions.
- ✅ Each Player starts the Match with **3 Lives**.
- ✅ The Match ends when either Player has no Lives left. **The Player with more Points wins.** Equal Points is a Draw.
- ✅ After the Match ends, the game freezes with the final Scoreboard shown. Pressing Start begins a new Match: Lives go back to 3 and Points to 0.
- ✅ Start positions: P1 at left-centre heading right; P2 at right-centre heading left.

## Movement

- ✅ Bikes never stop. Every Step, each Bike advances one Cell along its Heading.
- ✅ A Player can Turn 90° left or right. A 180° reversal is ignored.
- 🔵 If a Player presses several directions between two Steps, the last valid one is applied at the next Step.
- ✅ Movement is stepped (Cell by Cell) for now. Smooth movement is a possible later upgrade.
- ⏳ How many frames pass per Step (Bike speed).

## Trails and Crashes

- ✅ Every Cell a Bike passes through becomes part of its Trail, including the Cell it is in now. Trails are one Cell wide and stay until the Round ends.
- ✅ A Bike Crashes if it moves into a Wall, any Trail (including its own), or the same Cell as the other Bike in the same Step.
- ✅ Head-on Crash: if the two Bikes enter the same Cell, or swap Cells, in one Step, both Crash.
- ✅ Both Bikes move at the same time; neither has priority.
- ✅ A Crash ends the Round, and the crashed Player loses one Life. If both Crash in the same Step, both lose a Life.
- 🔵 After a Crash, the game freezes for about 2 s with the crashed Bike blinking. Then the next Round starts.
- ✅ No extra mechanic ends a long Round. Rewards are what tempt Players to take risks.

## Points

- ✅ Points come from **Rewards** and the **Survival Bonus**. They carry over between Rounds and reset only at a new Match.
- ✅ **Survival Bonus:** when a Round ends, the Player who did not Crash gains bonus Points. This makes crashing on purpose a losing move. 🔵 Value: +5.
- 🔵 Points stop at 99.

## Rewards

- ✅ Three Rewards are in the Arena at all times: 🔵 two worth +3 and one worth +5.
- ✅ Each appears at a random empty spot. When a Bike collects one, a new one of the same kind appears elsewhere at once.
- ✅ The Cells a Bike drives through while collecting become its Trail, as usual.
- ⏳ Reward size: about half the Bike's size.

## Controls

| Who | Input | Actions |
|---|---|---|
| P1 | Board buttons BTNU / BTNL / BTND / BTNR | Turn |
| P2 | PC keyboard, W / A / S / D, through the team's web controller page (Chrome or Edge, Mac or Windows) sending over USB-UART | Turn |
| Either | 🔵 BTNC, or 🔵 Space on the controller page | Start the Match or the next Round |
| Anyone | CPU_RESETN (red button) | Hard reset: back to power-up state |
| Anyone | Reset switch (up) | Hold the game paused, for debugging. Later this becomes the Setup Phase switch |

✅ The controller page only sends; it does not receive. Two-way UART (the board sending Points and Lives back to the page) stays an option for the UI/HUD session.

## Scoreboard (7-segment)

- ✅ All 8 digits, in decimal: 2 Points digits and 2 Lives digits per Player.
- 🔵 Left to right: `P1 Points | P1 Lives | P2 Points | P2 Lives`.

## Display sizes

- ⏳ Cell size (default 8 px), Bike sprite size (default 32 × 32), Reward size, and the Arena dimensions in Cells. These are decided with a PC prototype first, then confirmed on the monitor.
- ⏳ An on-screen area for a HUD is reserved in principle. Its layout is decided in a separate UI/HUD session.
- 🔵 Default colours before customisation exists: P1 cyan, P2 orange.

## Beyond the core game

✅ Demo scope tiers (agreed 2026-10-15). The core game in this note is the Must tier.

- **Should:** On-screen HUD.
- **Could:** Setup Phase with switch-chosen Player colours, background and options (the Master is whoever sets the switches); challenge settings (e.g. speed).
- **Won't this term:** Power-ups; smooth movement.
