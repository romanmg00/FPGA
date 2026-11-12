# Playable Tron core on the Nexys A7: provisional evidence, 29 October 2026

Built by the orchestrator (Claude Opus 5.5) after the GPT-6.1 Sol builders hit
their usage limit. Everything here is **provisional** under
[ADR 0005](../../../../docs/adr/0005-build-with-provisional-interfaces.md)
(proposed): it follows the working defaults of
[ADR 0003](../../../../docs/adr/0003-step-transaction-mailbox-and-render-codes.md),
and copies the model's choices where the agreement leaves the design open.
Passing these benches and builds is **evidence**, not team agreement. The
testbenches are the builder's checks, not the official other-owner benches of
contract §7.

**Status:** the core scope of the README's *Núcleo* is built and verified in
simulation, and its bitstream meets routed timing. Not yet run on the board;
section 5 is that check.

## 1. What was built

The full core game: movement, Turns with one Pending Turn, permanent Trails,
Wall/Trail/Bike Crashes and Head-on draws, Rounds and Lives, three Rewards
(+1, +1, +3) with replacement, the Survival Bonus, the Points Goal from
`{SW15, SW14}`, Start from BTNC or UART Space/Enter, Pause on SW0, `CPU_RESETN`,
the alternating 7-segment Scoreboard, and the VGA picture. The picture has
**sprites from ROM**: 32 × 32 Bikes rotated by address and centred on their
head Cells, 16 × 16 Rewards, a blinking crashed Bike, HUD Points bars and
Lives squares, and the 10 px white border.

| File | Domain | Owner (contract §4) | What it is |
|---|---|---|---|
| `game_core.sv` | `clk_juego` | Alan (match_ctrl, score) + Roman (Turns, Step) | `Game._game_edge` of `model/game_top.py`, register by register. Reuses `step/turn_unit`, `step/next_cell`, `step/step_resolve`, `score/score_unit`, `io/seg7_page` |
| `arena_svc.sv` | `clk_pix` | Alan (A2, G4) | Only writer of `arena/arena_map` port A: CLEAR at reset, PREPARE, READ2, COMMIT (code 6 at a crashed head, ADR 0003 item 4), and the model's Reward search (32-bit LFSR, taps 31/21/1/0, 32 shifts per draw in one cycle, 64 draws, then a wrapping scan) |
| `fast_core.sv` | `clk_pix` | Alan | Fast side of the mailbox, the input batch (axis latches gated by the snapshot phase) and the render/Scoreboard snapshot, including the displayed Headings |
| `sprite_rom.sv` | `clk_pix` | Roman (sprite_rom) | One RGB444 ROM, 2-cycle read latency, initialized from the `.mem` twin of a `.coe` |
| `drawcon_game.sv` | `clk_pix` | Roman (drawcon) | Design Plan Decision B: composes from the current `curr_x`/`curr_y`, and reads the Arena 1 position ahead and the sprite ROMs 2 positions ahead, from a full raster advance with line and frame wrap. Bike positions and Headings are latched once per frame, in vertical blanking |
| `sprites/` | — | Roman (art) | `bike-synth-32`, `reward-neon-gem-16` (+1), `reward-neon-star-16` (+3): the synthwave final design's art, as `.coe` and `.mem`, made by `tools/png2coe.py` |
| `reset_stretch.sv` | base clock | Alan | Holds the reset request for six game periods, so both domains reset together (review F7) |
| `tron_system.sv` | both | Alan (game_top) | Everything below the clocks: debounce, UART receive and decode, the two cores, drawcon, `vga_out`, `seg7_driver`, debug LEDs |
| `tron_top.sv`, `tron_top.xdc` | — | Alan | One Clocking Wizard since 12 November (two before; section 8), `video/game_clk_div` on `clk_pix`, reset synchronizers, contract §2 pins plus `dp` |
| `p2_controller.html` | host | Alan (web page) | Web Serial page: W A S D, Space, Enter at 115200 8N1 |

Also reused: `proyecto_final/vga_out.sv` and `counters.sv` (Roman's, fixed as
below), `prototypes/uart_input/uart_sync_2ff.sv`, `uart_rx.sv`,
`uart_cmd_decode.sv`, `board/board_reset_sync.sv`, `io/btn_debounce.sv`,
`io/seg7_driver.sv`.

### Changes to existing code (29 October, at Alan's request)

- **Roman's `vga_out.sv`.** It now drives `hsync`, `vsync` and `pix_*` with
  assignments from the counters, as the handout does, so `curr_x`/`curr_y`
  name the pixel on the pins in the same cycle (Decision B). Before, the
  outputs were registered, so the pins showed each coordinate one cycle later
  (`video/FINDINGS.md`).
- **Roman's `vga_out_tb.sv`.** It prints `PASS vga_out_tb` or calls `$fatal`,
  and compares the pixel in the same cycle. **`counters_tb.sv`** declares the
  11-bit `vcnt` agreed on 26 October.
- **`video/vga_out_check_tb.sv`.** It now checks everything against the
  current raster; before, it mixed two contradictory references.
- **`score/score_unit.sv`.** Reset loads Lives 3, so the idle Scoreboard shows
  `L203L103` like the model's idle view. `score_directed_tb` was updated to
  match.

### The provisional crossing

ADR 0003 item 2 is open. This build uses the model's **stable-payload mailbox**
(`model/mailbox.py`), the mechanism the Step logs were generated with:

- **Game to fast.** `game_core` changes `cmd_*` and the snapshot only on a
  `clk_juego` edge and toggles `tick_tgl` on the same edge. `fast_core`
  synchronizes `tick_tgl` with a 2-FF and latches the buses one cycle after
  the synchronized edge (`tick_seen`). Each path is bounded at one `clk_pix`
  period.
- **Fast to game.** `rsp_*` and `batch_*` change only on `tick_seen`, or when a
  command finishes within `WINDOW` cycles of it (2^18, about 3.1 ms). A
  command that overruns publishes at the next `tick_seen` and lights LED 4.
  `game_core` registers each bus once per edge, about 16.7 ms after it last
  changed, and only uses the register at the following edge. So a command
  issued at edge k is answered at k + 2, as in the model. A capture register
  that did go metastable would still have a whole game period to settle
  before use.
- **Reset.** `reset_stretch` holds both domains in reset for six game periods,
  so no mailbox sequence number survives.

### Other choices and deviations

- Crash code 6 is written (ADR 0003 item 4); the model keeps the head code.
  The Step logs are unaffected, because both codes block.
- `G_PREP = 5` and the input arrival gating follow the model (Hardware Map),
  not the contract's state list.
- The Reward LFSR, seed and schedule are the model's candidate, which the team
  has not selected (E1). The board mixes in the Start tick
  (`FIXED_SEED = 0`); the scenario bench uses the scenarios' fixed seeds.
- CLEAR writes WALL on the HUD rows and the padding (the model's
  `clear_word`); contract §6 says only WALL on the walls.
- **Sprite memories are inferred block ROMs** loaded from `.mem` files with
  `$readmemh`. The sprite tips build them with Block Memory Generator from the
  `.coe`. The words are identical: `png2coe.py` matches the viewer's
  `load_png` exactly. The 2-cycle latency is the tips' example. Swapping in the
  IP only needs its generated latency to stay 2.
- `vga_out`'s combinational outputs follow the handout but give a long
  combinational path to the pins: `vcnt` register → drawcon → `vga_g[3]` takes
  11.78 ns of the 11.98 ns budget. Registered outputs, Roman's original, are
  electrically cleaner but need a contract where coordinates lead the pins by
  one cycle. Roman should choose; if he keeps registered outputs, drawcon's
  look-aheads each grow by one.
- The on-screen score text (*Should*) and render coherence for mid-frame
  Arena writes are not built. A Round's CLEAR can show as one torn frame.

## 2. Source state and tools

Vivado/XSim **2025.2** in the `cs256-vivado-ubuntu24` container, part
`xc7a100tcsg324-1`. `evidence/sha256sum.txt` holds the hashes of every source,
sprite file and script used for the final results below.

## 3. Commands and results

From the repository root; the runners need sandbox escalation for
`sudo -n /usr/local/sbin/cs256-vivado`.

```bash
# Sprite art (only when the PNGs change)
python3 tools/png2coe.py proyecto_final/prototypes/core_blocks/game/sprites \
  assets/candidates/bike-synth-32.png assets/candidates/reward-neon-gem-16.png assets/candidates/reward-neon-star-16.png
# Event files and model logs (only when the scenarios or the model change)
(cd prototipos/tron_fpga && python3 ../../proyecto_final/prototypes/core_blocks/game/make_events.py)
proyecto_final/prototypes/core_blocks/run_all.sh              # block benches, Roman's vga_out checks included
proyecto_final/prototypes/core_blocks/game/run_game.sh        # 12 M2 scenarios vs the model
proyecto_final/prototypes/core_blocks/game/run_system.sh      # end-to-end pins and sprite bench
proyecto_final/prototypes/core_blocks/game/run_tron.sh        # bitstream and sign-off reports
# Roman's own bench
proyecto_final/prototypes/core_blocks/run_xsim.sh vga_out_tb vga_out_tb.sv vga_out.sv counters.sv
```

### Block regression (`run_all.sh`): 13/13 PASS

On the final sources, including `vga_out_check_tb` against the fixed
`vga_out`: two frames, 2 048 000 visible pixels, 0 sync, blanking,
coordinate or colour mismatches. Roman's `vga_out_tb` passes on its own
(`core-vga_out_tb-...` run of 29 October, 12:20).

### M2 scenario replay (`game_tb`): all 12 match the model, `tick` included

`game_tb` drives `game_core` + `fast_core` on two free-running clocks. Inputs
enter at the board seams: one-cycle debounced button pulses, UART bytes
through `uart_cmd_decode`, and raw switch levels into `game_core`'s
synchronizers. It writes each Step log with `$fwrite`. `run_game.sh` compares
each log with `tools/steplog_diff.py` and ignores no field. The Reward Cells
come from `arena_svc`'s slot registers. The bench also fails on any late
publish or Step overrun; there were none.

| Run | N (fast cycles per tick) | PHASE | WINDOW | Result | Host artifact |
|---|---:|---:|---:|---|---|
| first | 10000 | 3 | 9000 | 12/12 MATCH, 3261 lines | `core-game_tb-20261029-004514-689574` |
| phase sweep | 16384 | 7 | 12000 | 12/12 MATCH | `core-game_tb-20261029-032035-762877` |
| phase sweep | 12000 | 1 | 11000 | 12/12 MATCH | `core-game_tb-20261029-032035-762880` |
| final sources | 16384 | 3 | 12000 | 12/12 MATCH, 3261 lines | `core-game_tb-20261029-122036-870080` |
| after the crossing work (section 6) | 16384 | 3 | 12000 | 12/12 MATCH, 3261 lines | `core-game_tb-20261029-232239-1926173` |

### End-to-end pins and sprite bench (`tron_system_tb`): PASS, 43 checks

Artifact `core-tron_system_tb-20261029-232919-2007476` on the current sources
(`evidence/tron_system_tb.txt`; first run `core-tron_system_tb-20261029-122759-880512`). It sends serial 8N1 frames, presses bouncy
buttons, and reads the VGA pins and the eight multiplexed 7-segment digits.
Expectations come from the specification and the art, not from the model:

- The idle screen (border, Walls, no Bikes) and the idle Scoreboard.
- UART Start, both Bikes moving one Cell per Step, Trails, and Pause
  freezing play.
- **Sprite alignment.** Every opaque texel of a 32-pixel row through each
  Bike matches the art read through the Design Plan's rotation rule, for
  Headings Right, Left, Up and Down. A row of the +3 Reward matches too.
- A Turn from a bouncy BTNU and from UART `s`.
- A Wall Crash costing one Life and giving +3 to the survivor, then the
  crashed Bike blinking over its Crash Cell.
- The next Round back on the start Cells with the Crash Cell cleared, and a
  BTNC Start.

Scaling: `CLK_PIX_HZ = 1.152 MHz` (10 cycles per UART bit, 1 ms debounce =
1152 cycles) and 40 000 `clk_pix` cycles per game tick; pixel checks run while
paused.

### Bitstream and routed sign-off (`run_tron.sh`)

Final build: `/home/alan/.local/share/cs256-vivado/builds/tron-20261029-233130-2009133/`
(`run_tron.sh mailbox`, 6 ticks, `Performance_Explore`; section 6). The first
build was `tron-20261029-122928-881593`, WNS +0.202 ns, 1025 LUTs.
The bitstream `tron_top.bit` has its SHA-256 in `evidence/bitstream.sha256`.
The short reports are in `evidence/tron-*`.

| Check | Result |
|---|---|
| Achieved clocks (from the generated IP) | `clk_pix` 83 455 882.35 Hz; base 4 687 500 Hz; `clk_juego` = base / 78126 = 59.999 Hz |
| Sprite ROM contents | Synthesis log: all three `.mem` files "read successfully" |
| Setup / hold / pulse width | WNS +0.296 ns, WHS +0.059 ns, WPWS +0.027 ns, 0 failing endpoints; "All user specified timing constraints are met" |
| Worst setup path | `vga_out` `hcnt` register → drawcon → `vga_g[3]` pad: 11.69 ns of the 11.982 ns output budget (combinational outputs, as the handout specifies). Internal `clk_pix` to `clk_pix` WNS is +2.44 ns (1610 endpoints). With the default implementation strategy this path failed once (−0.361 ns), hence `Performance_Explore` |
| `check_timing` | `no_clock` 0, unconstrained internal endpoints 0, `no_output_delay` 0. `no_input_delay` 10 = the ten asynchronous pins, each false-pathed only to its first `ASYNC_REG` stage. The build script checks that, and `evidence/tron-cdc-endpoints.txt` lists the endpoints |
| `report_cdc` | **Critical, `clk_pix` to `clk_juego`, 21 endpoints, Unknown.** These are exactly the mailbox and batch capture registers (`rsp_seq` 4, `rsp_code` 2 × 4, `batch_axes` 2 × 4, `batch_start` 1). Their safety rests on the quiet-window protocol above; that is the open ADR 0003 item 2 decision. Warning, `clk_juego` to `clk_pix`, 151 endpoints, **all Safe**. Every other row is Info: synchronized pins and the reset |
| Methodology / DRC | TIMING-9 (Unknown CDC: the same 21 endpoints); SYNTH-6 (Arena BRAM output not registered). DRC: no violations |
| Utilization | 1052 LUTs (1.66 %), 973 registers (0.77 %), 2.5 Block RAM tiles (Arena RAMB36 + three RAMB18 sprite ROMs), 2 MMCMs, 5 BUFGs |

## 4. What the evidence shows, and what it does not

- The composed HDL reproduces the model's 12 M2 Step logs exactly, at
  several clock phases and game periods. That covers both clock domains, the
  stable-payload mailbox, the Arena service with the model's Reward search,
  and the input batch with arrival gating and the UART decoder. The Step
  transaction of ADR 0003 item 1 holds the agreed 6-tick Step with the
  model's 2-tick-per-command timing.
- Through the board pins, in simulation: debounce, serial receive, Decision B
  alignment for the Arena and the sprite ROMs, sprite rotation, and the
  7-segment scan.
- The design fits easily (1.62 % of the LUTs) and meets routed timing with
  `clk_pix` as the fast clock (ADR 0003 item 3).
- It does **not** prove CDC safety of the fast-to-game buses. That rests on the
  quiet-window protocol, and Vivado reports them as an unknown CDC. A 2-FF
  synchronizer there would add one game tick per command, and READ2 + COMMIT
  would then fill the 6-tick Step with no slack (`datapath/FINDINGS.md`).
- No board run yet: monitor lock and image, button feel, UART from the web
  page, and repeated reset and Pause still need section 5.

## 5. Board check (to run on `alan-legion`)

`alan-legion` did not answer SSH from the desktop on 29 October, so this
remains to be done with the board attached.

1. Copy `tron_top.bit` from the final build folder in section 3 to the laptop
   and check its SHA-256 against `evidence/bitstream.sha256`.
2. Program from Vivado Lab's Tcl console:
   `vivado_lab -mode batch -source program_board.tcl -tclargs /absolute/path/tron_top.bit`
   (`../board/program_board.tcl`).
3. Open `p2_controller.html` in Chrome or Edge, click **Connect** and choose
   the board's USB serial port. Any 115200 8N1 terminal also works.

Expected:

- [ ] Stable 1280 × 800 image: 10 px white border, pink neon Wall ring, dark
  HUD band on top, near-black Arena. LED 15 blinks about once per second (the
  game clock runs). The Scoreboard reads `P2 00  P1 00` / `L2 03  L1 03`.
- [ ] LEDs 2..0 show the phase: 000 idle, 001 play, 010 Crash, 011 ready,
  100 Match over, 101 preparing.
- [ ] BTNC (or Space on the page) starts: the cyan P1 Bike sprite on the left
  points right, the orange P2 Bike on the right points left. They move one
  Cell about every 0.1 s and leave Trails. Three Reward sprites appear: two
  gems (+1) and one star (+3).
- [ ] Direction buttons turn P1 and W A S D turn P2; each Bike sprite turns
  with its Step. Reversals are ignored.
- [ ] Collecting a Reward grows that Player's HUD bar; a new Reward appears.
- [ ] A Crash blinks the crashed Bike for about 2 s, a HUD Life square
  disappears, and the survivor gains 3. Then both Bikes are back on their
  start Cells, waiting for Start.
- [ ] Display: `P2 nn  P1 nn` and `L2 nn  L1 nn` alternate every ~3 s, with no
  decimal points lit.
- [ ] SW0 up freezes the game (LED 3 on, HUD band goes black); down resumes.
- [ ] `{SW15, SW14}` at Start sets the goal (10, 20, 30, 40). Reaching it ends
  the Match (phase 100); Start begins a new one.
- [ ] `CPU_RESETN` returns to the idle screen, repeatedly. LED 4 (late publish)
  stays off throughout.
- [ ] Look for colour fringes at sprite and Cell edges: the combinational VGA
  outputs use 11.78 of 11.98 ns. If they appear, that supports Roman's
  registered-output variant (section 1).

## 6. Update, 29 October 2026 (evening): crossing variants and ADR 0007

The crossing experiment in [`../crossing/`](../crossing/FINDINGS.md) changed
these sources. The defaults are unchanged: mailbox crossing, 6 ticks per Step.

- `game_core`, `fast_core`, `tron_system` and `tron_top` take `QUALIFIED`,
  `RSP_REG` and `STEP_TICKS`. `QUALIFIED = 1` with `RSP_REG = 1` is the
  "captured" crossing. At `STEP_TICKS = 8`, the low end of the range ADR 0007
  set, it routes with no unknown CDC. `run_tron.sh [mailbox|qualified|captured]
  [STEP_TICKS]` builds any variant.
- **Deferred launch** (all variants): a launch that finds the last COMMIT open
  now waits and sets `overrun`, instead of launching over it (ADR 0007).
- `phase` on a Step outcome is written, not held; `resolve` carries
  `DIRECT_ENABLE`.
- `run_tron.tcl` uses the `Performance_Explore` implementation strategy.
- `tron_system_tb` follows `STEP_TICKS`, and `pause(1)` waits for a frame
  start before sprite checks.
- `run_xsim.sh` passes `--override_timeprecision`.

None of this changes the mailbox's behaviour. All 12 scenarios still match
`.model.log` (3261 lines); `tron_system_tb` passes 43 checks; the 13 block
benches and Roman's `vga_out_tb` pass. The mailbox build has the same CDC
picture as before: 21 Critical Unknown fast-to-game endpoints and 151 Safe in
the other direction. Section 3 above has its timing. `evidence/` holds this
build's reports, its bitstream hash and the regenerated `sha256sum.txt`.

For the board check in section 5, program this build's `tron_top.bit`
(SHA-256 in `evidence/bitstream.sha256`). To try the captured crossing on the
board, use the `tron-captured-s8-…` bitstream from `../crossing/FINDINGS.md`;
its LED 8 is the input-FIFO overflow flag and should stay off.

## 7. Update, 2 November 2026: crash code in the model, whole-Arena check

- **The model now writes CELL_CRASH** (ADR 0003 item 4), in `arena_svc`'s
  write order (P1 old head, P1 target if it survives, P2 old head, P2 target).
  The deviation "the model keeps the head code" in section 1 no longer holds.
  The Step logs are unchanged, as predicted; three model test expectations
  changed, and the PC viewer colours a crash Cell from the snapshot.
- **Arena logs.** `make_events.py` writes `<name>.<ref>.arena.log` beside
  every reference Step log: one line per Step-log line with the CRC-32
  (`zlib.crc32`) of all 8192 Arena words after that edge's command.
  `game_tb.sv` computes the same CRC from `arena_map`'s memory (simulation
  only) into `<name>.arena.hdl.log`, and `run_game.sh` diffs both logs.
- **The model rejects an impossible Step interval** for its crossing at
  construction (mailbox 4, qualified 6, captured 8 ticks), instead of
  failing later with a cadence overrun.

| Run | Step logs | Arena logs | Host artifact |
|---|---|---|---|
| Captured, 8 ticks, before these changes (old check only) | 12/12 MATCH, 1597 lines | — | `core-game_tb-20261102-124145-3476214` |
| Mailbox, 6 ticks | 12/12 MATCH, 3261 lines | **12/12 MATCH** | `core-game_tb-20261102-124735-3483103` |
| Captured, 8 ticks | 12/12 MATCH, 1597 lines | **12/12 MATCH** | `core-game_tb-20261102-124737-3483350` |

Negative check: arena logs generated from the model *without* the crash-code
write differ from the mailbox run's HDL arena logs in all 12 scenarios, each
at its first Crash, although their Step logs match. The Step-log comparison
alone could not see that difference.

After these runs the only source change was a comment in `arena_svc.sv`.
The qualified variant and the 10-tick intervals were not rerun with the
arena check.

## 8. Update, 12 November 2026: ported onto main with one Clocking Wizard

The branch was ported onto `main` after ADR 0006 (one Clocking Wizard,
`clk_juego` from a counter on `clk_pix`). Its own ADR on the Step interval is
now ADR 0007.

- **`tron_top.sv`:** `tron_base_clock` is removed. `game_clk_div` divides
  `clk_pix` with `GAME_HALF_CYCLES = 695,466`, the N of `game_top.sv`
  (59.99997 Hz), and `reset_stretch` runs on `clk_pix`, holding six game
  periods. `run_tron.tcl` generates only `tron_pixel_clock` and takes
  `-divide_by` as 2 × `GAME_HALF_CYCLES`.
- **`vga_out`:** main keeps Roman's registered `proyecto_final/vga_out.sv`,
  which `game_top` was tested with on the board. The combinational version
  this build was designed for (section 1) is now the prototype copy
  `video/vga_out.sv`, used by `run_tron.tcl`, `run_system.sh` and
  `vga_out_check_tb`. Which one the game keeps is open for Roman
  (`docs/design/CS-256 VGA Output Timing Findings.md`).

Results with Vivado 2025.2 in the `alan-desktop` container:

| Check | Result | Host artifact |
|---|---|---|
| `run_all.sh` | 13/13 PASS, including `game_clk_div_tb` and `vga_out_check_tb` | `core-*-20261112-1705*` |
| `run_system.sh` | PASS `tron_system_tb` | `core-tron_system_tb-20261112-170558-272584` |
| `run_game.sh`, mailbox, 6 ticks | 12/12 Step logs and 12/12 arena logs MATCH, 3261 lines | — |
| `run_game.sh`, captured, 8 ticks | 12/12 Step logs and 12/12 arena logs MATCH, 1597 lines | — |
| Python model (`prototipos/tron_fpga`) | 80 tests OK; regenerated `.events` files unchanged | — |
| `run_tron.sh mailbox` | Bitstream written; one `MMCME2_ADV`; `clk_pix` 83,455,882 Hz | `tron-20261112-170534-268322` |

Routed timing is met: WNS +0.126 ns, WHS +0.038 ns, WPWS +3.000 ns, 0 failing
endpoints. The margin is smaller than the +0.296 ns of section 3 and is still
the combinational VGA pad path. `report_cdc` is as in section 3: `clk_pix` to
`clk_juego` 21 Unknown endpoints (the mailbox, ADR 0003 item 2) plus 1 Safe;
`clk_juego` to `clk_pix` 151 Safe. Methodology: `TIMING-9` and `SYNTH-6`.
DRC: no violations. `tron_top.bit` SHA-256
`bcf6e754bb2a3680c9631fd3c6d5ecd93691df43a0f4093841c0fbdb0d731561`.

No bench instantiates `tron_top`, so the clock change itself is covered only
by synthesis, the generated-clock check in `run_tron.tcl` and a board check
(section 9).

## 9. Board check, 12 November 2026

Nexys A7 serial `210292B1820D` on `alan-desktop`, programmed by JTAG (DONE
high), observed by Alan on his monitor. P2 used `p2_controller.html` in Chrome
over `/dev/ttyUSB1`.

**First build** (`tron-20261112-170534-268322`, SHA-256 `bcf6e754…`, section 8):

| Section 5 check | Result |
|---|---|
| Stable image, Wall ring, HUD band; LED 15 blinks; idle Scoreboard | Pass |
| LEDs 2..0 show the phase | Pass |
| Start (BTNC or Space); Bikes, Trails, three Rewards | Pass |
| Turns from the buttons and W A S D; reversals ignored | Pass |
| Collecting a Reward grows the HUD bar; a new Reward appears | Pass |
| Crash: blink, Life lost, +3 to the survivor, back to the start Cells | Pass |
| 7-segment pages alternate every ~3 s | Pass |
| SW0 Pause | Pass |
| `{SW15, SW14}` goal | Could not be seen: nothing showed the selected goal. This led to the Goal page below |

**Second build, with the Goal page** (`tron-20261112-184340-376672`, SHA-256
`d5242e21d44eca9173e874d077a0b99e18d98da68adf4bd2a0c2dcc07102f7c2`). While
waiting for a new Match (`G_IDLE`, `G_MATCH`) the Scoreboard cycles
Points → Lives → Goal (`GOAL  nn`), and a change of `{SW15, SW14}` jumps to the
Goal page. This goes beyond the locked Scoreboard rule (Points and Lives only)
and needs an ADR before it is accepted. Routed timing met (WNS +0.181 ns, WHS
+0.122 ns); the three new game-to-fast signals are Safe in `report_cdc`; the
21 Unknown endpoints of section 3 are unchanged.

| Check | Result |
|---|---|
| Idle cycles Points → Lives → `GOAL  10` | Pass |
| SW15/SW14 jump to `GOAL  20/30/40` | Pass |
| No Goal page during play | Pass |
| `CPU_RESETN`, repeatedly: back to idle, Start works, LED 4 off | Pass |

Not yet confirmed on the board: reaching the goal ends the Match (phase 100)
and the Goal page returns; colour fringes at sprite edges. After one reset Alan
saw a grey bar left of the P1 Bike; it was not investigated, because the
background design is being replaced.
