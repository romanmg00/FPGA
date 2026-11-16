---
title: Keep the contract's names and record where proyecto_final departs from the handout
status: proposed
created_at: "2026-11-15"
---

# Keep the contract's names and record where proyecto_final departs from the handout

[ADR 0006](0006-single-wizard-counter-game-clock-and-handout-as-guidance.md)
made the course handout guidance, not a strict specification, and asked that
every departure from it be recorded in an ADR with its reasons. The course
describes `proyecto_final/` in two places that do not use the same names:

- **Handout text:** `classproject/README.md` in the course repository
  (sections *VGA Sync Signals*, *Creating the Clock*, *Visible Pixel
  Counter*, *Drawing Logic Module*) and `classproject/sprites/README.md`
  (*Tips on Implementing Sprites*).
- **Slides:** [`cs256-project1-fall26.pdf`](../../proyecto_final/cs256-project1-fall26.pdf),
  slides 10–11. Their `game_top` diagram contains a **position logic** block
  (buttons and switches in, `blkpos_x`, `blkpos_y` out), `drawcon`
  (`curr_x`, `curr_y` in; `draw_r`, `draw_g`, `draw_b` out), `vga_out`
  (`pix_r`, `pix_g`, `pix_b`, `hsync`, `vsync`), `clk_div_106mhz` and
  `clk_div_60hz`.

Alan proposed this on 15 November 2026, four days before the Pre-Demo, so
that both members can explain each difference to the TAs. Roman's agreement
has not been recorded. The table was refreshed on 16 November 2026, after
the sprites (PRs #35, #39), the Arena (PR #40) and the Scoreboard modules
(PR #34) were merged.

## Decision

Keep the module and signal names of the
[interface contract](../../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md).
They follow the slides' diagram wherever the slides and the handout text
disagree. Nothing is renamed. The table below records each place where
`proyecto_final/` differs from the course material, where in the code the
difference is, and why. It changes no game rule and no interface.

Line numbers are those of `main` at `0c65662` (16 November 2026, after PRs #34, #35, #39 and #40).

| # | Course material | `proyecto_final/` | Where | Why |
|---|---|---|---|---|
| 1 | Slides 10–11: two clock dividers, `clk_div_106mhz` and `clk_div_60hz`. Handout *Drawing Logic Module* step 10: "another clock divider", then a counter to about 60 Hz | One Clocking Wizard `clk_wiz_0` at 83.46 MHz (`clk_pix`). `clk_juego` (~60 Hz) comes from a 20-bit counter on `clk_pix`, N = 695,466, through a `BUFG` | `game_top.sv:28` (`CLK_JUEGO_N`), `:50–53` (`u_clk`), `:57–70` (counter and `BUFG`); `game_top_timing.xdc` (`-divide_by 1390932`); `build_game_top.tcl` checks that N matches the XDC | The TAs approved one Wizard and the counter ([ADR 0006](0006-single-wizard-counter-game-clock-and-handout-as-guidance.md)). 83.46 MHz is the pixel clock of slide 7 and of the handout's *Creating the Clock*; 106 MHz on slides 10–11 is not adopted |
| 2 | Handout *VGA Sync Signals* steps 5–8: `vga_out` has an input `clk` and keeps the counters inside it, an 11-bit `hcount` and a 10-bit `vcount` | `vga_out`'s clock port is `clk_pix`. The counters are a separate module, `counters`, with `hcnt` and `vcnt`, both 11 bits. Counts, sync pulses and the visible window are those of the handout | `vga_out.sv:4` (`clk_pix`), `:18–23` (`c_counter`); `counters.sv:2–28` | The port name says which of the two clock domains the module is in (contract §1). The separate module is tested on its own in `counters_tb` (Pasos 1–2). An 11-bit `vcnt` also holds 0–827; 10 bits would be enough |
| 3 | Handout *Visible Pixel Counter* step 3: `game_top` has the same ports as `vga_out` (`pix_r`…, `hsync`, `vsync`) | `game_top`'s pins are `vga_r`, `vga_g`, `vga_b`, `vga_hs`, `vga_vs`, plus `cpu_resetn`, `sw[11:0]` and `btn[4:0]`. Inside, `vga_out` keeps `pix_*`, `hsync` and `vsync` | `game_top.sv:1–7`; `game_top.xdc` | The pin names are those of the Nexys A7 master XDC (`nexys-a7-100t-master.xdc`), so the constraints file only needs uncommenting. `cpu_resetn` is inverted once, as contract §1 requires |
| 4 | Handout *Drawing Logic Module* step 2: `drawcon` takes `draw_x`, `draw_y` and outputs `r`, `g`, `b` | `drawcon` takes `curr_x`, `curr_y` and outputs `draw_r`, `draw_g`, `draw_b` | `drawcon.sv:3–16`; `game_top.sv:159–177` | These are the slides' names. Each wire in `game_top` has the same name at both ends (`vga_out.curr_x` → `drawcon.curr_x`, `drawcon.draw_r` → `vga_out.draw_r`) |
| 5 | Handout step 2 and step 6: one block at `blkpos_x`, `blkpos_y`, drawn 32 × 32 | Two Bikes, `blkpos1_x/y` and `blkpos2_x/y`, each on one 16 × 16 Cell. Each is drawn as a 32 × 32 sprite from `bike_rom`, centred on its Cell and turned with its Heading. `drawcon` receives the positions through `bike_glide`, which slides each Bike between Cells (ADR 0010) | `position_logic.sv:20–23`; `game_top.sv:137–157` (`u_glide1`, `u_glide2`); `drawcon.sv:6–9`, `:28–31` (sprite offsets), `:97–122` (boxes) | It is a two-player game, and the agreed specification sets 16 px Cells. The 32 × 32 size of the handout is kept for the sprite, not for the Cell |
| 6 | Handout steps 3–7: background `bg_r/g/b` and block `blk_r/g/b` in two `always_comb` blocks, combined so a non-zero block colour wins; a white border within 10 px of the screen edge | One `always_comb` with a fixed priority: Walls, HUD, Bike 1, Bike 2, Trails, empty Arena. Sprite pixels `000` are transparent. Walls are 16 px. **The 10 px white border is not drawn yet** | `drawcon.sv:84–138` | One priority chain gives the same picture for opaque objects and adds layers without combining by colour. The 10 px border is still required (contract `BORDER_PX = 10`, README Paso 4b): it is unfinished work, not a departure |
| 7 | Handout step 8: "All logic in drawcon should be combinational" | `drawcon` is combinational except for its memory reads: it has a `clk` port, two `bike_rom` instances inside it, and it reads the Arena (`arena_map` port B) through `arena_addr`/`arena_code` | `drawcon.sv:4` (`clk`), `:14–15` (Arena ports), `:63–77` (`bike_rom_1`, `bike_rom_2`); `game_top.sv:130–134` (`u_arena_map`) | The sprite tips put a clocked ROM next to the drawing logic. The Arena is a memory too (contract §3), so `drawcon` gives it an address and uses the code that comes back; the colour logic stays one `always_comb` |
| 8 | Handout steps 10–13: the game logic is a synchronous `always` block **inside `game_top`** on the slow clock. BTNC puts the block back in the centre, each button moves it ±4 px, and it must not reach the border | `game_top` only connects the blocks. The game logic is the module `position_logic` on `clk_juego`, built from `round_fsm` (wait for Start, run, crash pause, wait for Start to be released), `step_counter` (one Step every 8 ticks; a 120-tick crash pause), two `bike_move` (Cell, Heading and Pending Turn of each Bike) and the Crash checks: Walls, the other Bike, and Trails from the Arena's neighbour codes (contract §3). A Crash stops both Bikes ([ADR 0011](0011-a-crash-stops-both-bikes.md), proposed). One `STEP_TICKS` in `game_top` (8, ADR 0010) sets the pace. The Arena itself (`arena_link`, `arena_ctrl`, `arena_map`) has no counterpart in the handout | `game_top.sv:16` (`STEP_TICKS`), `:87–106` (`u_position_logic`), `:109–134` (Arena); `position_logic.sv:50–176` (sections 1–6); `round_fsm.sv`; `step_counter.sv`; `bike_move.sv`; `arena_link.sv`, `arena_ctrl.sv`, `arena_map.sv` | Slides 10–11 draw this logic as a separate **position logic** block, and the handout ends by suggesting a game-logic module. The rules (Rounds, Steps, Turns, Crashes, Trails) come from the agreed specification, not from the ±4 px block demo. Each part has its own testbench |
| 9 | Handout procedure: a GUI project, *Copy constraints files into project*, behavioural simulation in the GUI | `build_game_top.tcl` builds from the repository without an earlier project: it generates `clk_wiz_0` and `bike_rom` from the IP Catalog, runs every testbench in XSim, then synthesizes, implements and checks timing. `comandos_vivado_myws.md` is Roman's GUI flow; it adds the files with `add_files -norecurse` instead of copying them | `build_game_top.tcl`; `comandos_vivado_myws.md` | Two members build on two machines. Referencing the files, and building from a script, keeps both on the same sources after each `git pull` |
| 10 | Sprite tips: Block Memory Generator, Single Port ROM initialised from a `.coe`, read latency 2, so the address is set two cycles early | `bike_rom`, a Block Memory Generator ROM of 1024 × 12 with latency 2, from `sprites/bike_synth.coe`. **The sprite address still comes from the current pixel**, so each sprite is drawn 2 px to the right (`game_top_tb`'s `SPRITE_SHIFT = 2`). The Arena read already uses the address of the pixel 2 ahead | `ip/bike_rom/bike_rom.tcl`; `build_game_top.tcl:156–166`; `drawcon.sv:28–31` (sprite address), `:33–36` (Arena address, 2 ahead) | Follows the tips. Reading the sprites two pixels ahead, as the tips and the contract (`draw_r` row) ask, is unfinished work (issue #30, step 3), not a departure |

## Considered options

- **Rename to the handout text's names** (`draw_x`/`draw_y`, `r`/`g`/`b`,
  `clk`, `hcount`/`vcount`). Rejected: the contract and both members' code and
  benches use the current names, and the slides use most of them too.
- **Rename only `drawcon`'s ports.** Rejected for the same reason; it would
  still leave rows 1–3 and 8 to explain.

## Consequences

- No HDL change. The Pre-Demo and the written report can use this table to
  relate each module and signal to the handout and the slides.
- When code moves, update the "Where" column. When a row stops being true
  (the 10 px border in row 6, the sprite look-ahead in row 10), edit or
  remove it.
- A later departure from the handout adds a row here or gets its own ADR.
