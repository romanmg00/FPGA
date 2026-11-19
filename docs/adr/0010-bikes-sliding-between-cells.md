---
title: Draw the Bikes sliding between Cells and step every 8 ticks
status: accepted
created_at: "2026-11-15"
---

# Draw the Bikes sliding between Cells and step every 8 ticks

> Proposed by Alan on 15 November 2026 as "Step every 6 ticks by default and
> draw the Bikes sliding between Cells" (file
> `0010-six-tick-steps-and-bikes-sliding-between-cells.md`). Accepted by Roman
> on 16 November 2026 with one change: the Step interval is **8** ticks, not 6.
> The title and file name were changed to match.

On 15 November 2026 Alan played the two-Bike `game_top` on the board (PR #28)
at 8 ticks per Step, the first value [ADR 0007](0007-configurable-step-interval.md)
asked to evaluate. Every check passed, but the game looked slow and choppy: a
16 px square jumped once every 133 ms, while the screen redraws 60 times a
second. Three throwaway images were then compared on the same board:

| Image | Ticks per Step | Drawing | Alan's verdict |
|---|---|---|---|
| A | 6 (10 Cells/s) | jumps one Cell per Step | right speed, still jumpy |
| B | 8 (7.5 Cells/s) | slides 2 px every tick | smooth, too slow |
| C | 6 (10 Cells/s) | slides 3, 5, 8, 11, 13, 16 px over the Step | chosen |

Alan chose C and merged it in PRs #31 and #32.

## Roman's acceptance (16 November 2026)

Roman accepts the sliding but chooses image B's interval, **8 ticks** (7.5
Cells/s). He played it on the board with the sprite ROMs (PR #35) and found it
smooth and playable. His reasons:

- **The slide removes the choppiness.** What looked slow and jumpy at 8 ticks
  was the 16 px jump, not the speed. With the slide, 8 ticks moves the Bike
  2 px every tick, in even steps.
- **The Arena crossing fits at 8 without waivers.** The `core_blocks` crossing
  study needs 8 ticks for the "captured" crossing (READ2 + COMMIT) with no CDC
  waiver; 6 ticks needs a 5-endpoint waiver. Choosing 8 now avoids changing the
  speed again when Trails and `arena_map` are added.

## Decision

1. **Step interval.** `game_top` has one parameter, `STEP_TICKS`, passed to
   `position_logic` and to both `bike_glide`. It is **8** (7.5 Cells/s),
   inside ADR 0007's 8–10 evaluation range. The defaults of `position_logic`
   and `step_counter` are also 8. Other values stay one-line changes.
2. **Sliding.** Each Bike's square is drawn moving from its previous Cell to
   its current one over one Step: after *t* ticks it has covered
   round(16 *t* / `STEP_TICKS`) px, which is 2 *t* px at 8 ticks. The game is
   unchanged: `position_logic` still moves one Cell per Step, and Turns and
   Crashes are decided on Cells. Only what `drawcon` is given changes.
3. **Registered.** `bike_glide`'s outputs are registers on `clk_juego`. The
   glide arithmetic (a divide by `STEP_TICKS` and an add) runs at 60 Hz, so
   the `clk_pix` path stays register → `drawcon` → `vga_out`.

## Why sliding

- A Bike that jumps 16 px reads as a low frame rate even at 60 Hz. The
  handout's own block demo moves 4 px per slow-clock tick (step 12 of
  *Drawing Logic Module*); sliding gives the same per-tick motion while the
  game keeps the agreed 16 px Cells.
- Variant C first met routed timing with only +0.062 ns, because the glide
  arithmetic sat in the pixel path. With the registered outputs it is again a
  register-to-register crossing, as in A.

## Consequences

- **What the player sees lags the game by one Step** (133 ms at 8 ticks). At
  a Crash the square finishes its slide into the last Cell and stops. Since
  [ADR 0011](0011-a-crash-stops-both-bikes.md) no Bike moves in a Crash Step,
  so that last slide is the one from the Step before the Crash. A jump
  of more than one Cell (back to the start) is drawn at once.
- **Sprite heading.** `heading` changes on the same `advance` edge as the
  Cell, so the sprite points along the slide it starts. It turns one tick
  (about 16 ms) before the slide begins, because `bike_glide` sees the new
  Cell one tick later. This was not visible on the board.
- **Arena crossing.** Re-check the 8-tick margin when `arena_map` and its
  service are added. If they need more ticks, raise `STEP_TICKS`; the slide
  follows it.
- **Trails.** When Trails are drawn from `arena_map`, the Trail Cell appears
  when the Step happens, one Step ahead of the sliding head. Decide then
  whether the Trail also waits one Step.
- **Crossing to `clk_pix`.** Since PR #48 (X1), `pos_link` carries the drawn
  positions and headings to `clk_pix` and gives `drawcon` one set per frame,
  copied at row 800. The picture can lag the game by up to one more frame,
  and heading and position still change together.
- **Still open.** `drawcon` has no look-ahead for the 2-cycle `bike_rom`
  read, so each sprite is drawn 2 px to the right (issue #30, step 3); Roman
  left that for the end, if time allows.
- **To reconcile.** The interface contract and `proyecto_final/README.md` say
  8. The shared model (`prototipos/tron_fpga/model/params.py`) and the
  `core_blocks` prototype's `game_pkg.sv` still use 6; they are Alan's to
  update.
