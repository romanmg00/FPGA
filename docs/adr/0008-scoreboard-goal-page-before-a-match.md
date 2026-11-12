---
title: Show the Points Goal on the Scoreboard before a Match
status: proposed
created_at: "2026-11-12"
---

# Show the Points Goal on the Scoreboard before a Match

On the 12 November board check of the playable core, Alan could not see which
Points Goal `{SW15, SW14}` selected: nothing on the board showed it until a
Match ended. He asked for the Scoreboard to show it. This adds a third view
to the Physical Scoreboard of the locked specification, which only alternates
Points and Lives. Alan chose this design; Roman's agreement has not been
recorded.

## Decision

- **When.** Only while waiting for a new Match: before the first Match and
  at Match-over, the two places where Start takes the Points Goal. During a
  Match (play, Crash, ready wait, Pause) the Scoreboard is unchanged.
- **Views.** While waiting, the views cycle Points → Lives → Goal, three
  seconds each, both banks together and without dark periods, as the
  specification requires of the other views.
- **Feedback.** Changing `{SW15, SW14}` while waiting jumps to the Goal view
  and restarts its three seconds, so the switches show their effect at once.
- **Goal view.** `GOAL  nn` across all eight digits: `GOAL` on P2's bank, two
  blank digits, then the goal the next Start would take (10, 20, 30 or 40).
  On the display the "O" is the same glyph as "0". The project decoder adds
  G and A to P and L.

A new Match still begins on Points. The Goal view shows the switches, not a
stored goal, so the Match uses the value the specification samples at Start.

## Considered options

- **Goal view only, before a Match.** Rejected: Points and Lives at
  Match-over would disappear until the next Start.
- **Goal as a third view in every state.** Rejected: during a Match the goal
  is fixed, and a third page would slow the Points/Lives cycle.
- **Layouts** `-- 20 --` and `G 20  G 20`. `GOAL  20` was chosen as the
  easiest to read.

## Consequences

- Supersedes, if accepted, only the Physical Scoreboard view list and the
  Match-over behaviour of the locked specification. The 20 October records
  stay byte-identical.
- Implemented in the shared model (`prototipos/tron_fpga/model/seg7.py`,
  `game_top.py`) and in `proyecto_final/prototypes/core_blocks/` (`seg7_page`,
  `seg7_driver`, the game-to-fast snapshot). Evidence and the board check are
  in `core_blocks/game/FINDINGS.md`, sections 8 and 9.
- The contract's `seg7_driver` description and the Glossary's Scoreboard
  entry change only after the team accepts this ADR.
