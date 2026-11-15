---
title: Step every 6 ticks by default and draw the Bikes sliding between Cells
status: proposed
created_at: "2026-11-15"
---

# Step every 6 ticks by default and draw the Bikes sliding between Cells

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

Alan chose C. Roman's agreement has not been recorded.

## Decision

1. **Step interval.** `game_top` has one parameter, `STEP_TICKS`, passed to
   `position_logic` and to both `bike_glide`. Its default is **6**
   (about 10 Cells/s). This is the playtest selection ADR 0007 calls for, and
   it meets ADR 0007's "approximately 10 Cells/s remains a desirable target".
   Values from 8 to 10 stay one-line changes.
2. **Sliding.** Each Bike's square is drawn moving from its previous Cell to
   its current one over one Step: after *t* ticks it has covered
   round(16 *t* / `STEP_TICKS`) px. The game is unchanged: `position_logic`
   still moves one Cell per Step, and Turns and Crashes are decided on Cells.
   Only what `drawcon` is given changes.
3. **Registered.** `bike_glide`'s outputs are registers on `clk_juego`. The
   glide arithmetic (a divide by `STEP_TICKS` and an add) runs at 60 Hz, so
   the `clk_pix` path stays register → `drawcon` comparisons → `vga_out`.

## Why

- ADR 0007 relaxed the fixed six-tick cadence so a slower Arena crossing
  could fit, but it left the final value to playtesting and kept ~10 Cells/s
  as the target. The board showed 8 ticks is too slow to play.
- A Bike that jumps 16 px reads as a low frame rate even at 60 Hz. The
  handout's own block demo moves 4 px per slow-clock tick (step 12 of
  *Drawing Logic Module*); sliding gives the same per-tick motion while the
  game keeps the agreed 16 px Cells.
- Variant C first met routed timing with only +0.062 ns, because the glide
  arithmetic sat in the pixel path. With the registered outputs it is again a
  register-to-register crossing, as in A.

## Consequences

- **What the player sees lags the game by one Step** (100 ms at 6 ticks). A
  Turn shows one Step after it is taken; at a Crash the square finishes its
  slide into the last Cell and stops. A jump of more than one Cell (back to
  the start) is drawn at once.
- **Arena crossing.** The `core_blocks` crossing study needs 8 ticks for the
  "captured" crossing (READ2 + COMMIT) with no CDC waiver; a 6-tick variant
  works with a 5-endpoint waiver. When `arena_map` and its service are added,
  re-check this; if they need more ticks, raise `STEP_TICKS` (the slide
  follows it).
- **Trails.** When Trails are drawn from `arena_map`, the Trail Cell appears
  when the Step happens, one Step ahead of the sliding head. Decide then
  whether the Trail also waits one Step.
- **Still open.** The drawn positions cross from `clk_juego` to `clk_pix`
  without a synchronizer (the five critical CDC-1 rows), and `drawcon` is not
  pipelined. Both are in the issue opened for Roman with this ADR (X1 snapshot
  and `drawcon` look-ahead).
- The interface contract, the shared model (`STEP_TICKS = 6`) and the
  contract test agree on 6 again.
