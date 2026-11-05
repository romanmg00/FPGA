---
schema_version: 1
id: cs256-adr-0006-single-wizard-counter-game-clock-20261105
title: CS-256 One Clocking Wizard, a Counter Game Clock, and the Handout as Guidance
type: note
subject: CS-256
status: accepted
created_at: "2026-11-05"
supersedes_in_part: "ADR-0002: the second Clocking Wizard and the strict-handout premise"
review_status: unreviewed
sources:
  - "TA meeting attended by Roman and Alan, reported by Alan on 2026-11-05"
  - "GitHub issue #10 (Reloj de píxel a 106 MHz y quitar el segundo Clocking Wizard)"
  - "[[CS-256/cs256-fall-2026/classproject/README]], Creating the Clock and Drawing Logic Module step 10"
---

# One Clocking Wizard, a counter game clock, and the handout as guidance

Roman and Alan met the TAs about the clocking questions in issue #10 and the
project handout. Alan reported the outcome on 5 November 2026. It changes two
things that ADR 0002 rested on.

## Decision

1. **One Clocking Wizard.** The design uses one Clocking Wizard, `clk_wiz_0`,
   which turns the 100 MHz board clock into the pixel clock `clk_pix`. The
   requested frequency stays **83.46 MHz**; the generated clock is
   83,455,882 Hz. The second Wizard, `clk_wiz_1`, is removed.
2. **The game clock comes from a counter on `clk_pix`.** A 20-bit counter on
   `clk_pix` toggles a register every *N* cycles, and that register drives
   `clk_juego`, giving approximately 60 Hz. Derive *N* from the achieved
   frequency: 83,455,882 / (2 × 60) ≈ 695,466. Issue #10 gives 695,467,
   which it derived from 83.456 MHz. Both fit in 20 bits (2²⁰ = 1,048,576).
   This is the default; the team can change it in a later ADR.
3. **The handout is guidance, not a strict specification.** The TAs said the
   handout is a good general path to follow, but the team does not have to
   follow it step by step. This replaces the "follow the handout architecture
   strictly" instruction recorded on 20 October 2026. The course's
   deliverables and assessment, the TAs' later instructions, and the locked
   agreed specification still apply.

## Why

- Handout step 10 asks for "another clock divider" followed by a counter.
  Issue #10 reads that as a divider, not necessarily a second Clocking Wizard,
  and the TAs agreed that a counter on the pixel clock is enough.
- When `game_top` was first built, two Wizards that each owned an input buffer on E3 failed
  placement (*Shape Builder 18-119*). `main` therefore chains `clk_wiz_1`
  from `clk_pix`; other experiments share one input buffer between two
  Wizards. Either way the second MMCM only produces the 5 MHz input of the
  same counter.
- The 106.5 MHz pixel clock proposed in issue #10 is not adopted. The game
  keeps the 83.46 MHz, 1280×800 at 60 Hz timing from slide 7 and the handout.

## Consequences

- **What ADR 0002 keeps.** Game-state logic still runs on a separate
  approximately 60 Hz `clk_juego`, not on `clk_pix` with an enable. The fast
  Arena service, the X1 game/render transfer, and the timing and CDC
  obligations in ADR 0002's Consequences are unchanged. `clk_juego` is still
  not aligned with vertical blanking, so the tearing fix in issue #14 is still
  needed.
- **Clock buffer and constraints.** Keep the registered toggle feeding a
  `BUFG`, as `game_top.sv` does now. In `game_top_timing.xdc`, keep the
  toggle register's C pin as the generated clock's source and the `BUFG`
  output as its target, and set `-divide_by` to 2*N. The divider's feedback
  is then timed on `clk_pix`.
- **Earlier alternatives.** The strict instruction was the reason ADR 0001's
  pixel-clock frame enable was closed. This ADR does not reopen ADR 0001.
  Any departure from the handout, including that one, needs its own ADR with
  its reasons and evidence.
- **Documents.** The locked 20 October records still say "second Clocking
  Wizard" and "strictly". They stay byte-identical; this ADR overrides those
  two points. The interface contract (§1, §3, §4, the `game_top`
  paragraph and §9) was updated to match on 5 November 2026.
- **Implementation.** On 5 November 2026 `main` still instantiates
  `clk_wiz_1` and divides its 5 MHz output. This ADR changes documentation
  only and verifies nothing about the one-Wizard design. The earlier
  two-Wizard build and board evidence stays valid for those builds. The change needs updates to `game_top.sv`,
  `game_top_timing.xdc`, `build_game_top.tcl`, the simulation clocks in
  `sim_clocks/`, `game_top_tb`, a new bitstream and a board check.

> **Implementation status, 5 November 2026:** the Paso 4c change removes
> `clk_wiz_1` from `game_top`. With *N* = 695,466, the full build passes its
> 10 testbenches and meets routed timing with one MMCM (Vivado 2025.2). The
> new bitstream has not yet been checked on the board.
