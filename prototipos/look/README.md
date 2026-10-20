# CS-256 Tron prototype

> **Implementation status, 20 October 2026:** this README describes the existing local viewer/model, which predates the team's locked specification. The target uses 16 px Cells, four-bit Arena words, Rewards +1/+1/+3, Survival Bonus +3, a configurable goal defaulting to 10, native RGB444 `.coe` sprites, and one shared headless rules model in the team repository. Migration has not been implemented. See [[CS-256 Tron Agreed Specification 2026-10-20]] and [[CS-256 Tron Architecture and Documentation Map]]; current prototype defaults and passing tests do not establish those decisions as implemented.

This is the earlier L1/M1 PC prototype: two Players can play while comparing art, sizes and HUD layouts. Those work-list labels describe prototype work, not a remaining rule-lock gate. The locked target is in the agreed specification; this local model and viewer have not been migrated to it. Visual/layout review can still revise the explicitly working geometry through a documented specification update.

The viewer defaults to the `synthwave` style preset. Sizes and Player colours still default to the recorded design: 8 px Cells, a 32 px Bike, P1 cyan and P2 orange.

## Quick start

This is a local, two-player Python desktop game. You need Python 3.10 or newer, a keyboard, and a graphical desktop. No FPGA board or Vivado installation is needed to play. The dependencies are pygame-ce, NumPy and Pillow.

Open a terminal in this `prototype/` folder, which contains `requirements.txt`, `look/` and `model/`. From the vault root, enter it with:

```sh
cd "CS-256/Game_research/prototype"
```

Create the virtual environment outside the vault so it is not synced by OneDrive/Syncthing. Choose the commands for your operating system.

### Linux / macOS

Run these commands from `prototype/`:

```bash
python3 -m venv "$HOME/.venvs/cs256-tron"
source "$HOME/.venvs/cs256-tron/bin/activate"
python -m pip install -r requirements.txt
python -m look
```

### Windows (PowerShell)

Run these commands from `prototype/`:

```powershell
py -3 -m venv "$env:USERPROFILE\.venvs\cs256-tron"
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m pip install -r requirements.txt
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m look
```

These Windows commands use the environment's Python directly, so activating a PowerShell script is unnecessary.

### Run again later

Open a terminal in `prototype/`. On Linux/macOS:

```bash
source "$HOME/.venvs/cs256-tron/bin/activate"
python -m look
```

On Windows (PowerShell):

```powershell
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m look
```

Launch the package with `-m look`; running `look/app.py` directly does not set up its package imports.

## Play your first Round

1. Click the game window so it receives keyboard input.
2. Press **Space** or **Enter** to start.
3. Player 1 uses the **arrow keys**; Player 2 uses **W/A/S/D**. Bikes move automatically; these keys request Turns.
4. Avoid Walls and Trails, and collect Rewards for Points. After the Crash freeze, press **Space** or **Enter** to start the next Round.
5. Press **P** to pause, **Backspace** to reset, or **Esc** to quit. In fullscreen, the first **Esc** returns to windowed mode.

The side panel lets you compare visual candidates. **Tab** cycles its pages or hides it, **M** changes the style preset, and **F11** toggles fullscreen. The complete controls are below.

## Troubleshooting

- **`No module named look` or `No module named model`:** make sure the terminal is in `prototype/`, then use `python -m look` (or the full Windows Python command above).
- **Missing `pygame`, `numpy` or `PIL`:** install `requirements.txt` using the same environment's Python that launches the game. The package providing `PIL` is Pillow; the package providing `pygame` here is pygame-ce.
- **`python3` or `py` is not found:** install Python 3.10 or newer and reopen the terminal. On Windows, enable the Python launcher during installation.
- **Linux cannot create a virtual environment:** install your distribution's Python venv support (often the `python3-venv` package), then retry.
- **No window appears over SSH or an error mentions a video device:** launch from a graphical desktop session. The interactive viewer needs a display; the tests below can run headless.
- **The game is too fast:** press **[** to slow it down; **]** speeds it up.

## Tests

Run both test suites from `prototype/`:

```powershell
python -m unittest discover -s tests
```

`tests/test_model.py` checks the Game Model rules: Steps, Turns, Crashes, Rewards, Points, Rounds, Matches and geometry. `tests/test_look_limits.py` runs headless and checks sampled frames from every preset for RGB444 and the handout's white border, including Crash frames. It also checks that pulse stripes are clearly brighter than both Player Trails, the default look fits BRAM and Arena-clear blanking, and generated art has the expected square, power-of-two sizes. M2's scenario files, Step logs and HDL log comparison are separate work.

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
| 4 | Bike style (`bike_style`) | `synth`, `racer`, `cycle`, `arrow`, then any `png:<name>` found in `assets/` |
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
| V | Bike effects (`bike_fx`) | `glow`, `streaks`, `none` |

The presets in `look/candidates.py` pair `synthwave` with `synth` + `glow`, `outrun` with `racer` + `streaks`, and `classic` with `cycle` + `none`. Both `glow` and `streaks` pulse any Bike halo; `none` leaves it at its fixed dim tint.

Changing HUD layout, Cell side or digit height creates a new Match. Other axes redraw the current state. The top HUD reserves a band rounded to 16 px; sides reserve 96 px each. The corner candidate covers Arena Cells and is not the selected working layout in the agreement.

The renderer's frame counter drives animation. `fx.phase` selects four phases of eight frames each. Changing any look axis or preset rebuilds the renderer and restarts animation. Pause freezes the Game Model, including Crash age; ambient animation keeps running.

See [Performance and hardware tracking](#performance-and-hardware-tracking) for measured frame times and renderer rebuild costs.

## Performance and hardware tracking

From `prototype/`, run:

```powershell
python -m look.metrics
```

This renders the configurations in `look/metrics.py`'s `CONFIGS` headless: all three presets at 8 px Cells, then `synthwave` at 4 and 16 px Cells. Each run measures 240 frames after 30 warm-up frames. Draw time includes the Game Model frame update, Trail update, drawing and final colour stage; build time measures a renderer rebuild.

The command appends rows to `prototype/metrics/look-metrics.csv` and rewrites [prototype/metrics/latest.md](metrics/latest.md). The CSV columns, in `FIELDS` order, are `date`, `commit`, `dirty`, `host`, `python`, `pygame`, `config`, `cell_px`, `build_ms`, `draw_ms_median`, `draw_ms_p95`, `ramb18`, `ramb18_pct`, `effect_table_bits`, `clear_us`, `placement2_us`, `blank_us`, `rgb444_ok`, `border_ok` and `flags`.

Commit code first, run the metrics from a clean working tree, then commit both metrics files. This makes each row name the clean commit measured. The `dirty` column flags any uncommitted change in the repository. Timing is per machine, recorded in `host`; compare rows from the same host. Hardware figures are estimates, pending synthesis.

The [baseline on Alan-Legion at commit `69842fc`](metrics/latest.md) records draw medians of 3.34–10.13 ms and p95 times of 3.83–10.83 ms, all below the 16.7 ms frame budget. RAMB18 use ranges from 11 to 33 halves (4.1–12.2% of 270). The 4 px Arena-clear flag records 1,570.5 µs against 563.6 µs of blanking; 8 and 16 px Cells fit that estimate. The legacy metrics label every `synthwave` configuration and `outrun` as using dim tint key `080`; `classic` has no such flag. These candidate flags are not target-build sign-off.

## Panel and FPGA limits

The panel shows the phase, Round, Step, Points, Lives, display scale and measured frame rate. Arena dimensions count interior Cells, excluding Walls and HUD reservations. Speed uses the hardware frame rate (about 59.998 Hz): Steps/s = frame rate / K. It also shows px/s and the time to cross the Arena width. The PC loop targets 60 fps; it is not cycle-accurate.

The legacy candidate checks are in [[CS-256 Tron Development Plan#Historical limits used by the Look Prototype]].

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

The legacy metrics also emit the label “Needs fixing before lockdown” for excess clear time, excess BRAM, invalid sprite dimensions, HUD coverage of Arena Cells and use of dim tint key `080`. Informational notes cover non-power-of-two digit scaling, Rewards larger than Cells, PNG Bike size overriding the size axis, and worst-case Reward placement. At the old 8 px Cell configuration, `placement_us` estimates about 417 µs per Reward and 834 µs for two in one Step. The target's separate 16 px estimate is documented in [[CS-256 Tron Development Plan#Open items]] and is not proof of a feasible HDL schedule. The local Python model executes placement synchronously in software; G4/A2 still needs a measured bounded or multi-frame hardware schedule.

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
| glow halo | Dim tint around Bike and Reward art | Legacy viewer effect using key `080`; excluded from the selected core asset format |
| Bike glow pulse | Bike halo breathes through four animation phases | Four-entry dim-tint table per Player |
| speed streaks | Flickering lines behind a moving Bike, only while a Round is running | Rectangle compares against the head position and Heading |
| neon digits | Lit segments over faint unlit segments | Ghost from segment-area comparators |
| chrome digits | Row shading with a dark centre split | Row LUT, 2 × 16 × 12 bits |

Pulse Trail stripe pixels take `c/4 + 12` per channel, near white for any Player colour; a fixed add was invisible on cyan because its green and blue channels were already 15.

The neon digit ghost is the union of the segment rectangles, using comparators on glyph x/y in hardware. It does not need a second ROM read.

`fx.lut_items` adds the active sky gradient, sun row, floor row, pulse colour and chrome row tables to the BRAM budget. Small tables may become LUT ROM; the synthesis report decides the mapping.

## Art workflow

From `Game_research/`, `python tools/make_candidate_art.py` writes `assets/candidates/*.png`. It keeps existing files; `--force` overwrites them. An edited PNG with the same name replaces generated art when the viewer next loads it. Restart the viewer after editing because ROMs are cached.

Any `assets/bike-<name>.png` appears as Bike style `png:<name>` on restart. Its native size overrides the Bike size axis, and `half-bike` Rewards follow that native size. Candidate Bikes are generated at 16/32/64 px; Rewards at 4/8/16/32 px.

The new candidate files are `bike-synth-*.png`, `bike-racer-*.png`, `reward-neon-gem-*.png` and `reward-neon-star-*.png` in `assets/candidates/`, at those sizes.

Generated `synth` and `racer` Bike halos now hug the silhouette. `Canvas.glow` in `look/art.py` puts the dim tint key on transparent pixels within 1 px of drawn art, or 2 px for 64 px art.

Art in this local viewer must be square with a power-of-two side and point UP. It converts PNG channels to RGB444: black `000` is transparent, green `0F0` is the Player/Reward tint key, and `111` gives visible black. In PNG RGB bytes these are `#000000`, `#00FF00` and `#111111`. The loader keeps the top four bits of each channel and treats alpha below 128 as transparent. Do not rely on partial alpha. The selected target uses native RGB444 `.coe` sprites; the planned L3 conversion/check is unfinished, and this viewer reads PNG rather than `.coe` files.

The legacy viewer interprets dim tint key `080` (PNG `#008800`) as half the Player/Reward tint for glow halos. This key is excluded from the selected core asset format; the viewer flags it as a legacy candidate issue. Older local art with `080` pixels still uses this viewer behavior.

## Local Game Model (implementation reference)

This section documents the existing local `prototype/model/` code only. It is a migration input, not the selected HDL contract or the shared reference model. The team selected one headless model in the team repository for both PC viewers and HDL scenarios; the exact migration base and adapters remain engineering work. `model/` has no graphics imports and checks functional state at frame and Step boundaries.

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

The following behavior is implemented in this local model as of this README revision. It predates and differs from the locked target; use it to understand current prototype output, not as a rule decision:

- Grid addresses concatenate Cell y and x bits, with power-of-two row and column allocations. Cell words are 3 bits: `0` empty, `1` Wall, `2` P1 Trail, `3` P2 Trail, `4`/`5`/`6` Reward slots 0/1/2; `7` is unused. Words outside the configured interior, including HUD reservations and allocation padding, hold Wall. This is local implementation data, not the selected shared-model encoding.
- Heading codes are UP=0, RIGHT=1, DOWN=2, LEFT=3. Each Bike latches its last valid Turn against its current Heading.
- The LFSR is 32-bit Fibonacci, shifts left, and XORs bits 31, 21, 1 and 0 into bit 0. A draw advances 32 shifts. The default seed is `0x1D2C3B4A`; zero is illegal. Hard reset restores the seed; ordinary new Rounds and Matches continue the sequence.
- Reward placement tries up to 64 draws, taking x from the low x bits and y from the next y bits. The first empty Cell wins. If all fail, scan in address order starting after the last candidate, wrapping through the full allocation. If none is empty, leave that slot empty until the next Round. Initial placement uses slots 0, 1, 2; collected Rewards are replaced in P1 then P2 order.
- Each Step applies pending Headings, then reads and checks both next Cells before either Bike writes. A crashed Bike stays in its Cell; a surviving Bike completes its move and leaves Trail, including when it collects a Reward.
- Award Reward Points before the Survival Bonus. Each addition is capped at 99 by default. Reward values default to 3, 3, 5; the Survival Bonus defaults to 5.

### Game Model and HDL contract

Legacy heading retained for links from the historical comparison. The material in this section describes only this local prototype; it does not define the selected shared-model or HDL contract.

## Local implementation gaps against the locked agreement

These are differences between the present local prototype and [[CS-256 Tron Agreed Specification 2026-10-20]], not open rule questions. Reconcile them during the model migration and update this implementation note from the resulting code:

| Area | Locked target | Existing local prototype |
|---|---|---|
| Arena | 16 px working Cells; 8192 × 4-bit words and agreed codes | Configurable 4/8/16 px; 8 px default; 3-bit words |
| Points and Rewards | Goal 10/20/30/40 (default 10), no 99 cap; Rewards +1/+1/+3 and Survival Bonus +3 | No selected goal rule; 99 cap; Rewards +3/+3/+5 and Survival Bonus +5 |
| Step cadence | One Cell every six approximately 60 Hz game-clock ticks | Frame-based `frames_per_step`, default 4, in the PC model |
| Randomness | Start-influenced normal-play seed and fixed-seed test mode; exact sequence unresolved | Fixed 32-bit model seed and local 32-bit LFSR/search schedule |
| Model ownership | One shared headless model in the team repository | Separate local model remains here; migration has not happened |

The exact selected PRNG sequence, seed capture/advancement, and hardware placement schedule remain implementation questions. See [[CS-256 Tron Agreed Specification 2026-10-20#Rewards and randomness]] and the [[CS-256 Tron Architecture and Documentation Map#Traceability]] table.

The current candidate viewer still includes effects outside the core asset contract, including the legacy `080` dim-tint key. The selected core sprite format uses `000` transparency and `0F0` Player tint; optional effects must not be described as implemented core behavior.
