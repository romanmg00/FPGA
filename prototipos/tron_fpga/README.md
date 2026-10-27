# CS-256 Tron FPGA prototype (`tron_fpga`)

> **Implementation status, 21 October 2026:** the headless model in `model/` and the viewer in `juego/` follow [[CS-256 Tron Agreed Specification 2026-10-20]], [ADR 0002](../../docs/adr/0002-follow-ta-divided-game-clock.md) and the FPGA limits in [[CS-256 Official FPGA Coding Practices]]. Its constants use the names of `game_pkg` in the [interface contract](../../proyecto_final/Contrato%20de%20interfaces%20game_top%20(CS%20256).md), and a test checks them against it. The passing tests show that this Python model behaves as specified; they are not HDL, timing or board evidence. Where the shared rules model will live, and which prototype it starts from, is still open in the contract, so this is not yet the selected shared model.

`tron_fpga` is a PC version of the game built around the planned Nexys A7 hardware. `model/` splits the rules into the hardware blocks: the Arena memory, the Turn latch and Step controller, Round/Match control, scoring, Reward placement and the physical Scoreboard view. The viewer package `juego/` draws 1280 × 800 frames in RGB444 with ROM-style sprites and fonts, and estimates block RAM use. The Reward LFSR is the prototype's own candidate: the agreement leaves the generator, its seed and its placement schedule to be selected, so the HDL should not copy it until that decision is made. The folder was imported as `prototipos/look/` and renamed on 20 October 2026; "Look Prototype" remains the name of its L1 objective in the Development Plan.

The viewer starts on the `core` style preset, which draws only what the agreed core build draws. The other presets show extras, which come after the core.

## Quick start

This is a local, two-player Python desktop game. You need Python 3.10 or newer, a keyboard, and a graphical desktop. No FPGA board or Vivado installation is needed to play. The dependencies are pygame-ce, NumPy and Pillow.

Open a terminal in this `prototipos/tron_fpga/` folder, which contains `requirements.txt`, `juego/` and `model/`. From the repository root, enter it with:

```sh
cd prototipos/tron_fpga
```

Create the virtual environment outside the repository so it is not synced by OneDrive/Syncthing. Keep it separate from the environment for `prototipos/requirements.txt`: that one installs `pygame` and this one installs `pygame-ce`, and both provide the `pygame` module. Choose the commands for your operating system.

### Linux / macOS

Run these commands from `prototipos/tron_fpga/`:

```bash
python3 -m venv "$HOME/.venvs/cs256-tron"
source "$HOME/.venvs/cs256-tron/bin/activate"
python -m pip install -r requirements.txt
python -m juego
```

If `python3 -m venv` reports that `ensurepip` is missing and `uv` is installed, `uv venv "$HOME/.venvs/cs256-tron"` followed by `uv pip install --python "$HOME/.venvs/cs256-tron/bin/python" -r requirements.txt` creates the same environment.

### Windows (PowerShell)

Run these commands from `prototipos/tron_fpga/`:

```powershell
py -3 -m venv "$env:USERPROFILE\.venvs\cs256-tron"
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m pip install -r requirements.txt
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m juego
```

These Windows commands use the environment's Python directly, so activating a PowerShell script is unnecessary.

### Run again later

Open a terminal in `prototipos/tron_fpga/`. On Linux/macOS:

```bash
source "$HOME/.venvs/cs256-tron/bin/activate"
python -m juego
```

On Windows (PowerShell):

```powershell
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m juego
```

Launch the package with `-m juego`; running `juego/app.py` directly does not set up its package imports.

## Play your first Match

1. Click the game window so it receives keyboard input.
2. Press **T** to choose the Points Goal if you want more than 10. It stands in for `{SW15, SW14}` and applies from the next Match.
3. Press **Space** or **Enter** to start. One press prepares the Arena, both Bikes and three Rewards, then releases the first Round.
4. Player 1 uses the **arrow keys** (the board's direction buttons); Player 2 uses **W/A/S/D** (the browser UART controller). Bikes move automatically; these keys request Turns.
5. Avoid Walls, Trails and the other Bike, and collect Rewards for Points. After a Crash, the crashed Bike blinks for about 2 seconds. Then press **Space** or **Enter** to start the next Round.
6. The first Player to reach the Points Goal wins; otherwise, losing the last of three Lives loses. Press **Space** or **Enter** after the Match to start a new one.
7. Press **P** to pause (`SW0`), **Backspace** to reset (`CPU_RESETN`), or **Esc** to quit. In fullscreen, the first **Esc** returns to windowed mode.

The side panel shows the phase, Points, Lives, the Points Goal and the eight Scoreboard digits. The `core` preset has no on-screen HUD, because the agreement puts it after the core; press **H** to show it. **Tab** cycles its pages or hides it, **M** changes the style preset, and **F11** toggles fullscreen. The complete controls are below.

## Troubleshooting

- **`No module named juego` or `No module named model`:** make sure the terminal is in `prototipos/tron_fpga/`, then use `python -m juego` (or the full Windows Python command above).
- **Missing `pygame`, `numpy` or `PIL`:** install `requirements.txt` using the same environment's Python that launches the game. The package providing `PIL` is Pillow; the package providing `pygame` here is pygame-ce.
- **`python3` or `py` is not found:** install Python 3.10 or newer and reopen the terminal. On Windows, enable the Python launcher during installation.
- **Linux cannot create a virtual environment:** install your distribution's Python venv support (often the `python3-venv` package), or use `uv` as above, then retry.
- **No window appears over SSH or an error mentions a video device:** launch from a graphical desktop session. The interactive viewer needs a display; the tests below can run headless.
- **The game is too fast or slow for a playtest:** **[** slows it down and **]** speeds it up. The panel marks any value other than the agreed 6 ticks per Step.

## Tests

Run both test suites from `prototipos/tron_fpga/`:

```powershell
python -m unittest discover -s tests
```

`tests/test_model.py` checks the model against the agreed specification. It compares the constants with `game_pkg` in the interface contract, then checks the Arena layout and codes and Step collisions, including Head-on and swap Crashes and each Wall. It also covers Turns and same-sample ties, the Round and Match phases, Rewards and the Survival Bonus, the Points Goal and simultaneous finishes, Pause, reset and the Scoreboard view. A long random game checks that Rewards stay on playable Cells and that the Arena codes and Points stay consistent.

`tests/test_look_limits.py` runs headless. It checks sampled frames from every preset for RGB444 and the handout's white border, including Crash frames and Bikes on the edge Cells, which overlap the border by 2 px. It also checks that pulse stripes are clearly brighter than both Player Trails, and that every preset fits the BRAM and Arena-clear budgets. Keyboard tests check that reset drops keys pressed before it in the same frame, and that Turns and Start pressed during Pause do not apply after resuming. Sprites must be at their native size and use only the core keys. The scenario files, Step logs and HDL log comparison of M2 are separate work.

## Controls

| Key | Action |
|---|---|
| Arrows | P1 Turn requests (board buttons) |
| W / A / S / D | P2 Turn requests (browser UART controller) |
| Space / Enter | Start |
| P | Toggle the Pause switch `SW0`; Turns and Start pressed while paused are dropped |
| T | Step the Points Goal switches `{SW15, SW14}`: 10, 20, 30, 40; applies at the next new Match |
| Backspace | Reset (`CPU_RESETN`): back to waiting for Start; keys pressed earlier in the same frame are dropped |
| H | Show or hide the on-screen HUD (an extra, after the core) |
| `[` / `]` | More / fewer game-clock ticks per Step (slower / faster), 1–30; the agreed value is 6 |
| G | Toggle the debug Cell overlay |
| M / Shift+M | Next / previous style preset: `core`, `synthwave`, `outrun`, `classic` |
| Tab | Cycle the panel in windowed mode: look page, BRAM page, effects page, hidden |
| F11 | Toggle fullscreen; 1:1 on the 1280 × 800 lab monitor, integer enlargement on larger displays |
| F12 | Save the game image to `prototipos/tron_fpga/out/`, without the panel or debug overlay |
| Esc | Leave fullscreen, or quit in windowed mode |

Candidate keys cycle forward; hold Shift to go back. The panel shows each axis by its field name, shortened to fit. The first choice of each axis is the core look; the others are extras.

| Key | Axis | Choices |
|---|---|---|
| 1 | Bike style (`bike_style`) | `cycle`, `arrow`, `racer`, `synth`, then any `png:<name>` found in the root `assets/` |
| 2 | Reward look (`reward_look`) | `gem+star` (+1 gem, +3 star), `gem`, `orb`, `neon` (neon gem and star) |
| 3 | Palette (`palette`) | `synthwave`, `outrun`, `classic`, `softer`, `strong` |
| 4 | Trail look (`trail`) | `full`, `inset`, `core`, `neon`, `pulse` |
| 5 | Grid lines (`grid`) | `off`, `32px`, `cell`, `neon`, `floor` |
| H | On-screen HUD (`hud`) | `off`, `on` |
| F | Digit font (`font`) | `seg`, `block`, `neon`, `chrome` |
| B | Background (`bg`) | `plain`, `sky`, `stars`, `sunset` |
| N | Wall look (`wall`) | `flat`, `neon` |
| R | Reward animation (`reward_anim`) | `still`, `pulse`, `spin` |
| X | Crash effect (`crash`) | `blink`, `ring`, `ring+flash` |
| C | CRT effect (`crt`) | `off`, `scanlines` |
| V | Bike effects (`bike_fx`) | `none`, `streaks` |

The `core` preset uses the `classic` palette and the first choice of every other axis. `synthwave` pairs `synth` Bikes with neon effects, `outrun` pairs `racer` Bikes with `streaks`, and `classic` adds 32 px grid lines and the HUD to the core look. The three non-core presets show the HUD. Geometry is not a candidate: Cells, sprite sizes, the HUD band and the start Cells are the agreed working layout in `model/params.py`. Changing a look axis redraws the current state.

The renderer's frame counter drives animation. `fx.phase` selects four phases of eight frames each. Changing any look axis or preset rebuilds the renderer and restarts animation. Pause freezes the game state, including the Crash display; ambient animation and the Scoreboard view keep running.

See [Performance and hardware tracking](#performance-and-hardware-tracking) for measured frame times and renderer rebuild costs.

## Performance and hardware tracking

From `prototipos/tron_fpga/`, run:

```powershell
python -m juego.metrics
```

This renders every preset headless on the agreed 16 px layout. Each run measures 240 frames after 30 warm-up frames. Draw time includes the game tick, Trail update, drawing and final colour stage; build time measures a renderer rebuild.

The command appends rows to `prototipos/tron_fpga/metrics/look-metrics.csv` and rewrites [prototipos/tron_fpga/metrics/latest.md](metrics/latest.md). The CSV columns, in `FIELDS` order, are `date`, `commit`, `dirty`, `host`, `python`, `pygame`, `config`, `cell_px`, `build_ms`, `draw_ms_median`, `draw_ms_p95`, `ramb18`, `ramb18_pct`, `effect_table_bits`, `clear_us`, `placement2_us`, `blank_us`, `rgb444_ok`, `border_ok` and `flags`.

Commit code first, run the metrics from a clean working tree, then commit both metrics files. This makes each row name the clean commit measured. The `dirty` column flags any uncommitted change in the repository. Timing is per machine, recorded in `host`; compare rows from the same host. Hardware figures are estimates, pending synthesis.

The [baseline on Alan-Legion at commit `69842fc`](metrics/latest.md) predates the agreed layout: it compared 4, 8 and 16 px Cells and the legacy `080` glow, and has not been rerun since. Its draw medians of 3.34–10.13 ms and p95 times of 3.83–10.83 ms are all below the 16.7 ms frame budget.

## Panel and FPGA limits

The panel shows the phase, Round, Step, Points, Lives, the Points Goal and its switches, the eight Scoreboard digits, display scale and measured frame rate. It shows the playable Arena (78 × 44 Cells of 16 px, below a 64 px HUD band) and the speed: Steps/s = 60 Hz game clock / ticks per Step, about 10 Cells/s or 160 px/s at the agreed 6 ticks. The PC loop runs one game-clock tick per 60 fps frame; it is not cycle-accurate.

The legacy candidate checks are in [[CS-256 Tron Development Plan#Historical limits used by the Look Prototype]].

| Limit | Viewer check or readout |
|---|---|
| 1: fixed 1280 × 800 | The game image keeps this size; the window scales its presentation. Use fullscreen on the lab monitor for 1:1. |
| 2: RGB444 | The finished game image is reduced to 4 bits per channel. The PC panel is outside that image. |
| 3: sprite format | Bikes are 32 × 32 (1024 words) and Rewards 16 × 16 (256 words), pointing UP. ROM address rotation gives four Headings; `000` is transparent and `0F0` is tinted. Sprites are not scaled or alpha blended. Other sizes are flagged. |
| 4: Cell side | 16 px, fixed by the agreement. The Arena address is `{cy[5:0], cx[6:0]}`. |
| 5: pixel position and state, fixed layers | The renderer models sky → stars → sun → grid lines → Walls → HUD band → Trails → Rewards → Bikes → crash ring → HUD (when shown) → 10 px white border. The border is on top, so a 32 px Bike centred on an edge Cell does not cover it. A final colour stage applies crash flash, then scanlines, skipping the border, then outputs RGB444. PC surfaces cache the drawing; the HDL uses no framebuffer. |
| 6: BRAM and Arena-clear budget | Live estimates cover two Bike ROMs, each distinct Reward ROM, the 8192 × 4-bit Arena, the digit font and HUD icons when the HUD is shown, and effect tables from `fx.lut_items`. Arena clear assumes one write per pixel clock over all 8192 words. |

BRAM counts use RAMB18 halves: 270 halves = 135 RAMB36 blocks = 4,860 Kb on the XC7A100T. Rows show instance counts, total bits in Kb and estimated halves. `LUT?` marks ROMs of at most 2,048 bits per instance that may use LUTs instead. These are estimates; the Block Memory Generator summary and synthesis report decide the actual mapping. The `core` preset, without the HUD, estimates 6 halves (2.2%).

Arena clear is compared with 47,040 pixel clocks of vertical blanking: 28 lines × 1,680 clocks at 83.46 MHz, or 563.6 µs. At 16 px Cells the 8192-word clear takes about 98.2 µs. The panel lists anything that breaks the agreed sprite format or these budgets under *Outside the agreed format or limits*, and notes the number of extras in use. A worst-case Reward placement is estimated at about 123 µs (246 µs for two); see [[CS-256 Tron Development Plan#Open items]]. These figures are idealized and do not prove a feasible HDL service schedule.

## 80s style effects and their hardware

Every effect here is an extra: the agreement puts the HUD, glow, scanlines and animated backgrounds after the core. Each effect is a function of pixel position, a frame counter and game state, so the proposed hardware needs no framebuffer or alpha blending. These are the stated costs in `fx.HW_COST`, pending HDL implementation and synthesis.

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
| crash ring | Expanding square rings from each crashed Bike | Compare `max(abs(dx), abs(dy))` with radius |
| flash | Brief brightening after a Crash | `c/2+7` per channel for four ticks of the Crash display |
| scanlines | Dim alternate rows | `y[0] ? c - c/4 : c` |
| Reward pulse | Reward tint brightens and dims | Four-entry tint table per kind |
| Reward spin | Reward turns through four Headings | Heading from `frame[4:3]`, using ROM addressing |
| speed streaks | Flickering lines behind a moving Bike, only during Play | Rectangle compares against the head position and Heading |
| HUD | Points digits, Life pips and a state icon in the 64 px band | Box comparators plus the digit font and icon ROMs |
| neon digits | Lit segments over faint unlit segments | Ghost from segment-area comparators |
| chrome digits | Row shading with a dark centre split | Row LUT, 2 × 16 × 12 bits |

Pulse Trail stripe pixels take `c/4 + 12` per channel, near white for any Player colour; a fixed add was invisible on cyan because its green and blue channels were already 15.

The neon digit ghost is the union of the segment rectangles, using comparators on glyph x/y in hardware. It does not need a second ROM read.

`fx.lut_items` adds the active sky gradient, sun row, floor row, pulse colour and chrome row tables to the BRAM budget. Small tables may become LUT ROM; the synthesis report decides the mapping.

## Art workflow

From the repository root, `python tools/make_candidate_art.py` writes the generated art at its native size into `assets/candidates/`: `bike-<style>-32.png` and `reward-<look>-16.png`. It keeps existing files; `--force` overwrites them. An edited PNG with the same name replaces generated art when the viewer next loads it. Restart the viewer after editing because ROMs are cached. Older 16/64 px Bike and 4/8/32 px Reward files in that folder are no longer loaded, and some still contain the legacy `080` key.

Any `assets/bike-<name>.png` appears as Bike style `png:<name>` on restart. It must be 32 × 32; other sizes are flagged in the panel.

Art must be square and point UP. The viewer converts PNG channels to RGB444: black `000` is transparent, green `0F0` is the Player/Reward tint key, and `111` gives visible black. In PNG RGB bytes these are `#000000`, `#00FF00` and `#111111`. The loader keeps the top four bits of each channel and treats alpha below 128 as transparent. Do not rely on partial alpha. There is no `080` dim key: a `#008800` pixel is drawn as dark green. The selected target uses native RGB444 `.coe` sprites; the planned L3 conversion/check is unfinished, and this viewer reads PNG rather than `.coe` files.

## Game Model

`model/` has no graphics imports. `Game.tick()` is one tick of the ~60 Hz divided game clock; the viewer calls it once per PC frame and draws from `Game.snapshot()`. The model checks state at tick and Step boundaries, not per clock cycle.

| Module | Work-list objectives | Responsibility |
|---|---|---|
| `params.py` | A1/A2, G1–G5 | `game_pkg` constants: geometry, Arena layout, rule values, start Cells, Points/Lives widths; `RuleParams` for tests and playtest tuning |
| `arena.py` | A1/A2 | 8192 × 4-bit Arena, `{cy, cx}` addressing, Cell codes, clear, reads and writes |
| `steering.py` | G1 | Heading codes, Pending Turn latch, same-sample tie order, unsigned next Cell |
| `step.py` | G1/G2, A2 | Both Bikes' reads, Crash checks, then Trail and head writes |
| `game.py` | G3; connects G1–G5 and A1/A2 | Match/Round phases, Start, Pause, reset, Step cadence, Lives and the order of each Step |
| `scoring.py` | G5 | Victory and Draw evaluation |
| `rewards.py`, `lfsr.py` | G4 | Prototype placement search and LFSR |
| `scoreboard.py` | I4 | The eight-digit Points/Lives view and its 3-second timer |
| `__init__.py` | M1 | Public package exports |

### Agreed behavior implemented here

- **Arena:** 16 px Cells, 80 × 50 on screen, padded to 128 × 64 words of 4 bits at address `{cy[5:0], cx[6:0]}`. Rows `cy` 0–3 are the HUD band; Walls are `cy` 4 and 49 and `cx` 0 and 79; the playable area is `cx` 1–78 × `cy` 5–48. Clearing writes `1` (Wall) to every non-playable word, padding included, and `0` elsewhere. Codes: `0` empty, `1` Wall, `2`/`3` P1 Trail/head, `4`/`5` P2 Trail/head, `6` Crash, `7` reserved, `8`/`9`/`10` Reward slots 0/1/2.
- **Movement:** one Cell every 6 ticks. P1 starts at (20, 27) heading RIGHT and P2 at (59, 27) heading LEFT. A Bike keeps one Pending Turn, the last valid request against its current Heading; reversals and same-Heading requests are ignored without cancelling it. Requests arrive in order; a set of Headings from one board sample is resolved UP > RIGHT > DOWN > LEFT. Steering is ignored outside Play.
- **Steps:** both target Cells are read before either is written. Any code other than empty or a Reward is a Crash, so Walls, both Trails and the other Bike's head Cell are fatal; same-target and swapping moves Crash both. A surviving Bike turns its old head into Trail and writes its new head. A crashed Bike stays on its last valid head Cell and loses one Life.
- **Points:** Rewards are worth +1, +1 and +3, and the survivor of a single Crash gets +3. In each Step the model resolves moves and Crashes, awards Rewards and the Survival Bonus, then evaluates victory. There is no cap: the full total is kept (at most 45, which fits 6 bits).
- **Match result:** the first to reach or exceed the goal wins; if both do in one Step, higher Points wins and equal Points is a Draw. Otherwise losing the final Life loses; if both lose it in one Step, Points decide the same way.
- **Phases:** `IDLE` (power-up and reset) waits for Start. Start captures the goal from `{SW15, SW14}`, resets Points and Lives, prepares the Arena, both Bikes and all three Rewards, and enters `PLAY` directly. A Crash freezes play for 120 ticks (`CRASH`), ignoring Start and Turns. After a non-final Crash the next Round is prepared and `READY` waits for a fresh Start. A Match-ending Crash keeps the result, still shows the display, then enters `MATCH_OVER`; reaching the goal without a Crash enters it directly. Start in `MATCH_OVER` begins a new Match. These names map to the contract's proposed `G_IDLE`, `G_PLAY`, `G_CRASH`, `G_READY` and `G_MATCH`.
- **Pause and reset:** `SW0` freezes game state, game timers and steering; the Scoreboard view keeps cycling. Reset clears the Arena and returns to `IDLE`.
- **Scoreboard:** `P2nnP1nn` for Points and `L2nnL1nn` for Lives, switching together every 180 ticks; a new Match starts on Points.
- **Rewards:** three independent slots, all placed before a Round is released, only on empty playable Cells. A collected Reward is replaced in the same Step, in ascending slot order. If the Arena has no empty Cell, the slot stays absent until the next Round.

### Prototype choices the agreement leaves open

These are this model's working choices, not team decisions. Change them when the team selects otherwise, in the model and the contract together.

- **Reward generator and placement:** 32-bit Fibonacci LFSR (bits 31, 21, 1, 0), 32 shifts per draw. Up to 64 random draws, taking `cx` from the low 7 bits and `cy` from the next 6; the first empty Cell wins. If all fail, the model scans in address order after the last candidate. Placement completes inside the Step, so the agreed temporary absence while hardware searches never appears.
- **Seed:** reset loads the default seed. In normal play, each new-Match Start XORs the count of game ticks since power-up into the LFSR, so Start timing changes the sequence. `RuleParams(fixed_seed=True)` instead restarts every Match from `seed`, for repeatable tests.
- **Start while paused** is ignored, because Pause freezes game state.
- **Before the first Start** the Arena holds only Walls and no Bikes are shown.
- **Code `6` (Crash)** is defined but not written; a crashed Bike's Cell keeps its head code.
- **Same-Step timing:** Turns, Start and the Step all take effect on the tick they are given. The transfer latency through the fast Arena service and the input CDC (X1) is not modelled; when that interface is designed, the model must reproduce any added ticks.

### Remaining gaps

- The team has not chosen where the shared model lives or its migration base; Roman's `prototipos/tron/` still has its own rules. Viewers should import one model and keep no rule code.
- No Step-log writer, scenario files or log-diff script exist yet (M2).
- The PRNG, seed capture and placement service need a team decision before HDL work (Reward placement, G4).
- The viewer's optional HUD is a candidate for the post-core HUD (H2). The panel's Scoreboard text stands in for the board's 7-segment display.
