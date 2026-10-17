# CS-256 Tron prototype

The L1 Look Prototype viewer runs on the headless M1 Game Model. Two Players can play while comparing art, sizes and HUD layouts. See [[CS-256 Tron Development Plan#Phases]] for L1/L2 and M1/M2. Candidate choices and model defaults remain subject to L2; this viewer does not close L1 or M1.

The viewer defaults to the `synthwave` style preset. Sizes and Player colours still default to the recorded design: 8 px Cells, a 32 px Bike, P1 cyan and P2 orange.

## Install, run and tests

Install from `Game_research/`:

```powershell
python -m pip install --user -r prototype/requirements.txt
```

The dependencies are pygame-ce, NumPy and Pillow. Keep virtual environments outside the vault, which syncs through OneDrive/Syncthing.

Run from `prototype/`:

```powershell
python -m look
```

Run the headless Game Model tests from `prototype/`:

```powershell
python -m unittest discover -s tests
```

These check Steps, Turns, Crashes, Rewards, Points, Rounds, Matches and geometry. M2's scenario files, Step logs and HDL log comparison are separate work.

## Controls

| Key | Action |
|---|---|
| Arrows | P1 Turn requests |
| W / A / S / D | P2 Turn requests |
| Space / Enter | Start |
| P | Toggle the pause switch |
| Backspace | Hard reset (`CPU_RESETN`) |
| `[` / `]` | Increase / decrease K (frames per Step): slower / faster; range 1–30, default 4 |
| G | Toggle the debug Cell overlay |
| M / Shift+M | Next / previous style preset: `synthwave`, `outrun`, `classic`; presets never change geometry |
| Tab | Cycle the panel in windowed mode: look page, BRAM page, effects page, hidden |
| F11 | Toggle fullscreen; 1:1 on the 1280 × 800 lab monitor, integer enlargement on larger displays |
| F12 | Save the game image to `prototype/out/`, without the panel or debug overlay |
| Esc | Leave fullscreen, or quit in windowed mode |

Candidate keys cycle forward; hold Shift to go back. The panel shows each axis by its field name, shortened to fit.

| Key | Axis | Choices |
|---|---|---|
| 1 | HUD layout (`hud`) | `top`, `sides`, `corners` |
| 2 | Cell side (`cell_px`) | 4, 8, 16 px |
| 3 | Bike side (`bike_px`) | 16, 32, 64 px |
| 4 | Bike style (`bike_style`) | `synth`, `cycle`, `arrow`, then any `png:<name>` found in `assets/` |
| 5 | Reward look (`reward_look`) | `neon`, `gem`, `orb`, `gem+star` (`neon` and `gem+star`: +3 gem, +5 star) |
| 6 | Reward side (`reward_size`) | `half-bike`, `cell` |
| 7 | Palette (`palette`) | `synthwave`, `outrun`, `classic`, `softer`, `strong` |
| 8 | Trail look (`trail`) | `pulse`, `neon`, `full`, `inset`, `core` |
| 9 | Grid lines (`grid`) | `neon`, `floor`, `off`, `32px`, `cell` |
| 0 | Bike anchor (`anchor`) | `centre`, `nose` |
| F | Digit font (`font`) | `neon`, `chrome`, `seg`, `block` |
| H | Digit height (`digit_px`) | 32, 48, 64 px |
| B | Background (`bg`) | `sunset`, `stars`, `sky`, `plain` |
| N | Wall look (`wall`) | `neon`, `flat` |
| R | Reward animation (`reward_anim`) | `pulse`, `spin`, `still` |
| X | Crash effect (`crash`) | `ring+flash`, `ring`, `blink` |
| C | CRT effect (`crt`) | `scanlines`, `off` |

Changing HUD layout, Cell side or digit height creates a new Match. Other axes redraw the current state. The top HUD reserves a band rounded to 16 px; sides reserve 96 px each. Corners cover Arena Cells and need a rule before lockdown.

The renderer's frame counter drives animation. `fx.phase` selects four phases of eight frames each. Changing any look axis or preset rebuilds the renderer and restarts animation. Pause freezes the Game Model, including Crash age; ambient animation keeps running.

Reported steady drawing is about 8–10 ms per 1280 × 800 frame on the development PC (rendering only, measured headless). Renderer rebuilds take longer.

## Panel and FPGA limits

The panel shows the phase, Round, Step, Points, Lives, display scale and measured frame rate. Arena dimensions count interior Cells, excluding Walls and HUD reservations. Speed uses the hardware frame rate (about 59.998 Hz): Steps/s = frame rate / K. It also shows px/s and the time to cross the Arena width. The PC loop targets 60 fps; it is not cycle-accurate.

The six limits are in [[CS-256 Tron Development Plan#FPGA limits for the Look Prototype]].

| Limit | Viewer check or readout |
|---|---|
| 1: fixed 1280 × 800 | The game image keeps this size; the window scales its presentation. Use fullscreen on the lab monitor for 1:1. |
| 2: RGB444 | The finished game image is reduced to 4 bits per channel. The PC panel is outside that image. |
| 3: sprite format | PNG checks flag non-square or non-power-of-two art. ROM address rotation gives four Headings; `000` is transparent and `0F0` is tinted. Sprite pixels are not scaled or alpha blended. |
| 4: Cell side | The axis and geometry allow only 4, 8 or 16 px. Arena dimensions and speed update with it. |
| 5: pixel position and state, fixed layers | The renderer models sky → stars → sun → grid lines → Walls → HUD area → 10 px border → Trails → Rewards → Bikes → crash ring → HUD. A final colour stage applies crash flash, then scanlines, skipping the white border, then outputs RGB444. PC surfaces cache the drawing; the HDL uses no framebuffer. |
| 6: BRAM and Arena-clear budget | Live estimates cover two Bike ROMs, each distinct Reward ROM, the padded 3-bit Arena grid, digit font, HUD icons and effect tables from `fx.lut_items`. Arena clear assumes one write per pixel clock over the full padded grid. |

BRAM counts use RAMB18 halves: 270 halves = 135 RAMB36 blocks = 4,860 Kb on the XC7A100T. Rows show instance counts, total bits in Kb and estimated halves. `LUT?` marks ROMs of at most 2,048 bits per instance that may use LUTs instead. These are estimates; the Block Memory Generator summary and synthesis report decide the actual mapping.

Arena clear is compared with 47,040 pixel clocks of vertical blanking: 28 lines × 1,680 clocks at 83.46 MHz, or 563.6 µs. At 8 px Cells, the padded grid is 256 × 128 and clear takes about 392.6 µs.

“Needs fixing before lockdown” flags cover excess clear time, excess BRAM, invalid sprite dimensions, HUD coverage of Arena Cells and use of dim tint key `080` outside FPGA limit 3. Informational notes cover non-power-of-two digit scaling, Rewards larger than Cells, PNG Bike size overriding the size axis, and worst-case Reward placement. These notes still need review: at 8 px Cells, `placement_us` estimates about 417 µs per Reward and 834 µs for two in one Step. G4/A2 needs a bounded or multi-frame HDL schedule; the functional model does this work immediately.

## 80s style effects and their hardware

Each effect is a function of pixel position, a frame counter and game state. The proposed hardware needs no framebuffer or alpha blending. These are the stated costs in `fx.HW_COST`, pending HDL implementation and synthesis.

| Effect | Appearance | Stated hardware cost |
|---|---|---|
| sky | Colour bands forming a sky gradient | Row LUT, 50 × 12 bits; index `y[9:4]` |
| stars | Small stars that twinkle | Hash; three constant multiplications by shift/add |
| sunset | Striped sun with a colour gradient | Row LUT holding half-width and colour |
| neon grid | Bright grid lines with a dim halo and pulsing colour | `x/y[4:0]` tests; four pulse colours |
| floor grid | Perspective grid with rows moving towards the viewer | Row LUT for `1/d`, lines and colour; one DSP |
| neon Wall | Bright tube along the Wall edge | Four edge comparators |
| neon Trail | Coloured edge with a bright core | Cell-local x/y bit tests |
| pulse Trail | Near-white stripes moving along Trails, on any Player colour | `(x+y-2f) mod 64 < 6` selects `c/4 + 12` per channel |
| crash ring | Expanding square rings from each crashed Bike, kept inside the white border | Compare `max(abs(dx), abs(dy))` with radius |
| flash | Brief brightening after a Crash | `c/2+7` per channel for four frames of Crash age |
| scanlines | Dim alternate rows | `y[0] ? c - c/4 : c` |
| Reward pulse | Reward tint brightens and dims | Four-entry tint table per kind |
| Reward spin | Reward turns through four Headings | Heading from `frame[4:3]`, using ROM addressing |
| glow halo | Dim tint around Bike and Reward art | Key `080` selects half the tint; L2 proposal |
| neon digits | Lit segments over faint unlit segments | Ghost from segment-area comparators |
| chrome digits | Row shading with a dark centre split | Row LUT, 2 × 16 × 12 bits |

The neon digit ghost is the union of the segment rectangles, using comparators on glyph x/y in hardware. It does not need a second ROM read.

`fx.lut_items` adds the active sky gradient, sun row, floor row, pulse colour and chrome row tables to the BRAM budget. Small tables may become LUT ROM; the synthesis report decides the mapping.

## Art workflow

From `Game_research/`, `python tools/make_candidate_art.py` writes `assets/candidates/*.png`. It keeps existing files; `--force` overwrites them. An edited PNG with the same name replaces generated art when the viewer next loads it. Restart the viewer after editing because ROMs are cached.

Any `assets/bike-<name>.png` appears as Bike style `png:<name>` on restart. Its native size overrides the Bike size axis, and `half-bike` Rewards follow that native size. Candidate Bikes are generated at 16/32/64 px; Rewards at 4/8/16/32 px.

The new candidate files are `bike-synth-*.png`, `reward-neon-gem-*.png` and `reward-neon-star-*.png` in `assets/candidates/`, at those sizes.

Art must be square with a power-of-two side and point UP. Use RGB444 colours: black `000` is transparent, green `0F0` is the Player/Reward tint key, and `111` gives visible black. In PNG RGB bytes these are `#000000`, `#00FF00` and `#111111`. The loader keeps the top four bits of each channel and treats alpha below 128 as transparent. Do not rely on partial alpha. L3's `.coe` asset flow follows lockdown.

Dim tint key `080` (PNG `#008800`) selects half the Player/Reward tint, channel by channel, for glow halos. This is an L2 proposal outside FPGA limit 3. The viewer flags art using it under “needs fixing before lockdown”. A literal `080` pixel in older art is now treated as the dim key too.

## Game Model and HDL contract

The modules follow hardware blocks. `model/` has no graphics imports; it checks functional state at frame and Step boundaries.

| Module | Work-list objectives | Responsibility |
|---|---|---|
| `params.py` | A1/A2, G1–G5 | Arena geometry, HUD reservations, start Cells and rule parameters |
| `arena.py` | A1/A2 | Grid memory, address calculation, Walls, clear, reads and writes |
| `steering.py` | G1 | Heading codes, Turn latch, next Cell |
| `step.py` | G1/G2, A2 | Both Bikes' reads, Crash checks and Trail writes |
| `game.py` | G3; connects G1–G5 and A1/A2 | Round/Match state, frame-to-Step rate, Lives and ordered updates |
| `lfsr.py` | G4 | Deterministic placement draws |
| `rewards.py` | G4, A2 | Empty-Cell search and Reward placement |
| `scoring.py` | G5 | Points addition with a cap; Lives are updated by `game.py` |
| `__init__.py` | M1 | Public package exports |

The current model fixes the following comparison contract for HDL, pending L2 decisions:

- Grid addresses concatenate Cell y and x bits, with power-of-two row and column allocations. Cell words are 3 bits: `0` empty, `1` Wall, `2` P1 Trail, `3` P2 Trail, `4`/`5`/`6` Reward slots 0/1/2; `7` is unused. HUD space and padding hold Wall. This encoding is a model proposal.
- Heading codes are UP=0, RIGHT=1, DOWN=2, LEFT=3. Each Bike latches its last valid Turn against its current Heading.
- The LFSR is 32-bit Fibonacci, shifts left, and XORs bits 31, 21, 1 and 0 into bit 0. A draw advances 32 shifts. The default seed is `0x1D2C3B4A`; zero is illegal. Hard reset restores the seed; ordinary new Rounds and Matches continue the sequence.
- Reward placement tries up to 64 draws, taking x from the low x bits and y from the next y bits. The first empty Cell wins. If all fail, scan in address order starting after the last candidate, wrapping through the full allocation. If none is empty, leave that slot empty until the next Round. Initial placement uses slots 0, 1, 2; collected Rewards are replaced in P1 then P2 order.
- Each Step applies pending Headings, then reads and checks both next Cells before either Bike writes. A crashed Bike stays in its Cell; a surviving Bike completes its move and leaves Trail, including when it collects a Reward.
- Award Reward Points before the Survival Bonus. Each addition is capped at 99 by default. Reward values default to 3, 3, 5; the Survival Bonus defaults to 5.

## Model choices awaiting L2

The Game Model proposals below are in [[CS-256 Tron Game Mechanics]]. The style proposals follow them. None is an agreed change:

- [[CS-256 Tron Game Mechanics#Movement|Movement]]: judge Turns against current Heading; a same-Heading request keeps a pending Turn; ignore requests outside a running Round.
- [[CS-256 Tron Game Mechanics#Trails and Crashes|Trails and Crashes]]: a crashed Bike stays; the survivor still moves, leaves Trail and collects Rewards in that Step.
- [[CS-256 Tron Game Mechanics#Points|Points]]: Reward Points precede the Survival Bonus, with the 99 cap on the total.
- [[CS-256 Tron Game Mechanics#Rewards|Rewards]]: place Rewards at each Round's start; a full Arena leaves a collected slot empty until the next Round.
- [[CS-256 Tron Game Mechanics#Match and Rounds|Match and Rounds]]: wait for Start after the Crash freeze; Start at Match end begins the new Match straight away.
- [[CS-256 Tron Game Mechanics#Match and Rounds|Start positions]]: mirrored starts keep an odd Manhattan distance, so only the swap Head-on Crash is reachable. Decide whether to shift one start Cell by one Cell for the same-Cell case.
- [80s style effects](#80s-style-effects-and-their-hardware): decide whether to adopt dim tint key `080` for glow halos and add it to FPGA limit 3.
- Final colour stage: decide whether to adopt crash flash and scanlines after the HUD, skipping the white border. Keep Decision B pixel alignment from [[CS-256 VGA and Sprite Design Plan#Decision B: prefetch sprite data while keeping current-pixel timing]].
