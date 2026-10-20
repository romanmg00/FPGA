---
schema_version: 1
id: cs256-tron-glossary-20261014
title: CS-256 Tron Glossary
type: note
subject: CS-256
status: active
created_at: "2026-10-14T17:00:00"
updated_at: "2026-10-20T15:14:27"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
review_status: verified
tags:
  - tron
---

# CS-256 Tron Glossary

The shared language of the CS-256 class-project game: a two-player Tron light-cycle game on the Nexys A7 board. Terms here are game concepts, not module or signal names. The [[CS-256 Tron Agreed Specification 2026-10-20]] owns rule details; this glossary defines vocabulary, not a second rules specification.

## Play structure

**Match**:
A complete game made of one or more Rounds.
_Avoid_: Game (ambiguous with the whole project)

**Round**:
One stretch of play that starts with prepared Bikes and Arena state and ends when a Crash or the end of the Match stops play.
_Avoid_: Level, stage

**Crash**:
A Bike's failed move into an occupied or inaccessible Cell. A Crash ends the Round and costs the crashed Player one Life; exact collision cases are in the agreed specification.
_Avoid_: Collision (reserve for the general hardware-check sense), death

**Head-on Crash**:
Both Bikes Crash in the same Step because they meet: they enter the same Cell, or they swap Cells (each enters the Cell the other is in). Both Players lose a Life.
_Avoid_: Head-on collision

**Draw**:
A Round in which both Bikes Crash in the same Step, or a Match with equal final Points when both Players reach the Points Goal or lose their final Life in the same Step.
_Avoid_: Tie

**Life**:
One of a Player's three chances in a Match; a Crash costs one Life.

**Points Goal**:
The configured Points threshold for winning a Match. Its values and sampling point are in the agreed specification.
_Avoid_: Limit (use Points Goal for the victory threshold)

**Points**:
A per-Player in-game score, earned from Rewards and the Survival Bonus and shown on the Scoreboard. Distinct from the course's grading Marks.
_Avoid_: Score (when it could be confused with Marks)

**Survival Bonus**:
Points awarded to a Player who survives the other Player's Crash. The value and simultaneous-Crash behavior are in the agreed specification.
_Avoid_: Win bonus, round points

**Marks**:
The course's grading points for the demo, pre-demo and report. Never an in-game quantity.

## Participants and phases

**Player**:
One of the two game participants controlling a Bike.

**Pause**:
A temporary suspension of gameplay and game timers that preserves the Match state; resuming continues the same Match. Video and Scoreboard display activity continue during Pause.
_Avoid_: Reset (which clears the Match)

**Play**:
The active part of a Round in which Bikes take Steps. Match lifecycle and Pause behavior are defined in the agreed specification.

## World

**Arena**:
The playing area shown on the VGA screen, made of Cells and bounded by Walls.
_Avoid_: Map, world, board (ambiguous with the FPGA board)

**Cell**:
The smallest square unit of the Arena; each Cell is empty, part of one Player's Trail, part of a Wall, or holds a Reward.
_Avoid_: Tile, block

**Wall**:
The fixed Cells around the Arena's edge that cause a Crash.
_Avoid_: Border (the handout's drawn white frame is a separate visual feature; it is not the collision Wall)

**Reward**:
A collectible item in an Arena Cell; collecting it awards Points. Slot count and values are defined in the agreed specification.
_Avoid_: Coin, objective, power-up

**Power-up**:
A collectible that changes play (speed, Trail, etc.) rather than only granting Points. Deferred; not yet defined.
_Avoid_: Power, poder, Reward

**Bike**:
A Player's light-cycle, drawn as a sprite and occupying a head Cell.
_Avoid_: Motorcycle, car, player (the person and the Bike are different)

**Heading**:
The direction a Bike is travelling: up, down, left or right.
_Avoid_: Direction (when the Player's input is meant)

**Turn**:
A 90° change of a Bike's Heading, requested by its Player. A 180° reversal is never a Turn and is ignored.

**Pending Turn**:
The last valid Turn requested since the previous Step, waiting to be applied at the next Step; a later valid request replaces it. Validity is judged against the Bike's current Heading.

**Step**:
The moment in which every Bike advances one Cell along its Heading. Steps occur at a fixed rate during a Round.
_Avoid_: Tick, move (when the timing unit is meant)

**Trail**:
The permanent line of every Cell a Bike has occupied during a Round, including the Cell it is in now; one Cell wide; cleared only when the Round ends.
_Avoid_: Wake, tail, estela (use Trail in English documents)

## Feedback

**Scoreboard**:
The board's eight 7-segment digits, used to show each Player's Points and Lives. Digit mapping and view timing are defined in the agreed specification.
_Avoid_: HUD (reserve for an on-screen display)

**HUD**:
An on-screen display of game information. Its contents and working placement are defined in the agreed specification.
