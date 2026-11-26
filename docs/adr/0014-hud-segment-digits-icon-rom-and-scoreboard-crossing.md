---
title: HUD drawn from segment rectangles and a 64-word icon ROM, fed by the Scoreboard's crossing
status: proposed
created_at: "2026-11-26"
---

# HUD drawn from segment rectangles and a 64-word icon ROM, fed by the Scoreboard's crossing

> Proposed by Alan on 26 November 2026 with the HUD branch (`hdl/hud`). The HUD
> is Roman's (contract §4, "Marcador en pantalla (`texto_capa`, `font_rom`)"),
> so this waits for Roman's review. It departs from that row's module names and
> its font ROM.

The [Agreed Specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md)
reserves the top 64 px for the HUD and says to "start with 32 px text", kept
"subordinate to gameplay and inside the selected band". The contract's §4 row
names two modules, `texto_capa` and `font_rom`, for "Puntos y vidas en la
franja de 64 px, con texto de 32 px". The look follows the Python viewer
(`prototipos/tron_fpga/juego/hud.py` and `font.py`, synthwave), which Alan's
prototype already rebuilt in HDL and checked on the board on 12 November
(`proyecto_final/prototypes/core_blocks/game/FINDINGS.md` §10).

## Decision

- **One module, `hud_layer`, in English.** It replaces the contract's
  `texto_capa` and `font_rom`. `game_top` instantiates it on `clk_pix`, and
  `drawcon` takes its colour as one input, `hud_color`, in the band's branch
  (`curr_y < 64`), which keeps its place in `drawcon`'s priority.
- **Digits from segment rectangles, not a font ROM.** Each Player's Points are
  two seven-segment digits, 16 × 32 px: `font.py`'s 8 × 16 glyph at scale 2,
  so the text is 32 px tall as the specification starts with. Homework 1's
  `sevenseg` decoder gives each digit's segments, and seven comparisons of the
  glyph column and row give the segment rectangles. Unlit segments are not
  drawn (the viewer's ghost was removed on 12 November).
- **Icons from a 64 × 16-bit ROM.** Three Life diamonds per Player, hollow
  once lost, and a centre icon: "play", blinking while the Bikes wait for
  Start, and after the Match a crown in the winner's colour, white for a Draw.
  `sprites/hud_icons.mem` (four 16 × 16 icons, one word per row, bit c =
  column c) is written from the viewer's bitmaps by
  `proyecto_final/prototypes/core_blocks/tools/make_hud_icons.py`, and loaded with `$readmemh`
  like `sun_rows.mem`.
- **Layout and colours.** `hud.py`'s positions: P1's digits at x 24 and 44,
  its Lives at 68, 88 and 108; P2 mirrored, Lives at 1156, 1176 and 1196,
  digits at 1220 and 1240; digits at y 21, icons at y 29; the centre icon at
  x 632. Band `000`, P1 `0DF` and P2 `F80` as the Bikes (Alan's choice on 25
  November), play icon and Draw crown `FFF`.
- **Values from the Scoreboard's crossing.** `seg7_link` already copies Points
  and Lives to `clk_pix` for `seg7_driver`; it now carries 25 bits instead of
  20, adding the Bikes waiting for Start (`position_logic`'s `load`), the
  Match result and which Players crashed (a `game_top` register, set by the
  Crash and cleared when its 2 s pause ends). `hud_layer` copies them once per
  frame, at `curr_x = 0`, `curr_y = 800`, so a frame never shows two values.
- **Blinks on frames.** `hud.py` blinks 16 ticks on and 16 off from the start
  of each phase. `hud_layer` counts frames since the phase last changed and
  hides the play icon, or a crashed Player's digits, when bit 4 is set. A frame
  and a `clk_juego` tick differ by 108 `clk_pix` cycles in 1.39 million.
- **Registered colour.** The colour of each pixel is worked out for the next
  pixel (`curr_x + 1`) and registered; what depends only on the line (segment
  rows and icon rows) is registered once per line. The HUD adds no logic
  between `curr_x` and `vga_out`.

## Options considered

| Option | Why not |
|---|---|
| `font_rom` with a 10-glyph font, read per pixel | A ROM read in the pixel path for ten digits that seven comparisons draw; the viewer's own font is defined as segment rectangles |
| Lives as digits ("L 3") | The viewer draws diamonds; the digits stay on the Scoreboard |
| `hud_layer` inside `drawcon` | Four to seven more `drawcon` ports, and another session edits `drawcon`'s other branches |
| A second crossing for the HUD | `seg7_link` already copies Points and Lives each tick; one crossing keeps the Scoreboard and the HUD equal |
| Blink from a `clk_juego` counter | Needs a counter and more crossed bits; frames and ticks run at the same rate |
| **Segment rectangles, a 64-word icon ROM, `seg7_link`'s copy** (chosen) | The module is not named as in the contract |

## Consequences

- The contract's §4 row and §7 change: Roman writes them (Spanish text in the
  HUD PR).
- `seg7_link`'s `set_max_delay` already covers `values_juego_reg[*]` and
  `values_pix_reg[*]`; `build_game_top.tcl` now requires 25 cells on each side
  instead of at least one.
- Tests: `hud_layer_tb` checks every band pixel for Points 0–45, Lives 0–3,
  the play icon, the three crowns and the blinks against a model written from
  `hud.py` and `font.py`; `game_top_tb` predicts every band pixel in every
  checked frame, ties the band to `score_unit` and `match_fsm`, and checks the
  numbers after the Crashes in `wall_crash`, `match` and `uart_uturn`.
- Pause does not stop the blinks, unlike the viewer's `phase_ticks`.
