---
title: A Crash stops both Bikes in its Step
status: proposed
created_at: "2026-11-16"
---

# A Crash stops both Bikes in its Step

> Proposed and approved by Alan on 16 November 2026 after a board test of PR #39.
> Waiting for Roman's acceptance, because it changes a team rule.

The [Agreed Specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md)
(*Movement, Turns and Crashes*) says: "A crashed Bike remains at its last valid
head Cell and loses one Life. The surviving Bike completes its Step and can
collect a Reward."

On 16 November 2026 Alan played `game_top` with the sprite ROMs (PRs #35 and
#39). P1 moved up and P2 moved left into P1's head Cell. P2 crashed and stopped
at the contact, while P1 slid one more Cell before the pause. That is the rule
above, drawn one Step late by `bike_glide`
([ADR 0010](0010-bikes-sliding-between-cells.md)), but on screen it reads as
the hit Bike being pushed or skidding after the collision.

## Decision

**When either Bike Crashes, neither Bike moves in that Step.**

- The crashed Bike stays on its last valid head Cell and loses one Life, as before.
- The survivor also stays on its head Cell. It collects nothing in that Step,
  even if its target holds a Reward, and writes nothing to the Arena.
- The survivor still earns the **+3 Survival Bonus**. Head-on and swap Crashes
  are unchanged: both Bikes Crash and neither gets the Bonus.
- Everything else in the specification stands: both target Cells are read
  before either move is written, the Crash ends the Round, and the Points Goal
  is checked after the Step.

This supersedes only the sentence "The surviving Bike completes its Step and
can collect a Reward". The locked records are not edited.

## Options considered

| Option | Result | Why not |
|---|---|---|
| Keep the rule | The survivor slides one Cell after the Crash | Looks like a skid on the board; this ADR exists to remove it |
| Freeze only the drawing (`bike_glide` ignores the Crash Step) | Both drawings stop, but the survivor is drawn one Cell behind its real head | The screen disagrees with the game; once Trails are drawn, the survivor's Head Cell would show ahead of its sprite |
| Stop the survivor unless a Reward is ahead | The slide still happens whenever a Reward is ahead | Inconsistent, and it adds an Arena-code condition at the Step tick |
| **Stop both Bikes on any Crash** (chosen) | Both drawings stop on the Crash Step, matching the game state | The survivor loses a Reward it would have reached in that Step |

## Consequences

- **HDL:** `position_logic` advances a Bike only when neither Bike crashes
  (`advance = step && !crash`). `bike_move` and `bike_glide` do not change.
- **Drawing:** in a Crash Step neither Cell changes, so `bike_glide` starts no
  slide. ADR 0010's "the square finishes its slide into the last Cell and stops"
  now means the slide of the Step before the Crash.
- **Arena:** a Crash Step changes no Cell. No Crash code is written (code 6
  is unused, contract §3), so each Bike's head, crashed or not, stays a Head
  Cell in its Bike's colour. The Arena request after a Step may still send each
  Bike's old and new head; for a Bike that did not move they are the same Cell,
  and writing Trail then Head leaves it a Head Cell.
- **Points:** a Reward ahead of the survivor is not collected. A survivor can
  still reach the Points Goal through the Survival Bonus.
- **Shared model:** `prototipos/tron_fpga/model/step_unit.py` follows this
  rule ([ADR 0004](0004-shared-headless-model-base.md)). Its M2 scenario logs
  were rebuilt: only Crash lines change, each by the survivor's Cell. Its
  `step_resolve` writes nothing in a Crash Step, so its Arena image matches
  the HDL's.
- **Not updated:** Roman's viewer (`prototipos/tron/`) and the `core_blocks`
  prototype keep the old rule; neither is part of the delivered design.
