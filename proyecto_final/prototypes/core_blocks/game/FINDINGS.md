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
and is proposed in [ADR 0008](../../../../docs/adr/0008-scoreboard-goal-page-before-a-match.md). Routed timing met (WNS +0.181 ns, WHS
+0.122 ns); the three new game-to-fast signals are Safe in `report_cdc`; the
21 Unknown endpoints of section 3 are unchanged.

| Check | Result |
|---|---|
| Idle cycles Points → Lives → `GOAL  10` | Pass |
| SW15/SW14 jump to `GOAL  20/30/40` | Pass |
| No Goal page during play | Pass |
| `CPU_RESETN`, repeatedly: back to idle, Start works, LED 4 off | Pass |
| Reaching the goal (10) ends the Match; the Goal page returns | Pass |
| Colour fringes at sprite and Cell edges (combinational VGA outputs) | None seen |

After one reset Alan
saw a grey bar left of the P1 Bike; it was not investigated, because the
background design is being replaced.

## 10. Update, 12 November 2026 (evening): the synthwave HUD

Branch `hdl/synthwave-look`, from `hdl/core-blocks-on-main` at `fc8190a`. The
placeholder HUD (Points bars, Lives squares, band black while paused) is
replaced by the Scoreboard of the Python viewer's synthwave design
(`prototipos/tron_fpga/juego/hud.py`, font `neon`), at its pixel positions.
This supersedes the HUD items of the section 5 checklist (Points bar, Life
square, "HUD band goes black" on Pause) and the section 1 note that the
on-screen score is not built. Still PROVISIONAL (ADR 0005).

**What was built**

- `drawcon_game.sv`: per Player two 16 × 32 seven-segment Points digits
  (the 8 × 16 glyph of `juego/font.py` at scale 2) whose unlit segments glow
  at a quarter of the Player colour (`033`, `320`), and three 16 × 16 Life
  diamonds, hollow once lost; P2 is mirrored. Digits at x 24, 44 (P1) and
  1220, 1240 (P2), y 21; Lives at x 68 + 20k and 1156 + 20k, y 29; the state
  icon at (632, 29): "play" blinking while waiting for Start (`G_IDLE`,
  `G_READY`), a crown after the Match in the winner's colour, white for a
  Draw. A crashed Player's digits blink during the Crash display. Band
  background `000`. The digits are segment-rectangle comparators; the icons
  are a 64 × 16-bit LUT ROM, `sprites/hud-icons-16.mem`, written by
  `tools/make_hud_icons.py` from the viewer's bitmaps. The HUD colour is
  computed for the Arena look-ahead pixel and registered (`hud_rgb`), so it
  adds no logic between `curr_x`/`curr_y` and the VGA pins. HUD values are
  latched once per frame with the Bikes; the new synchronous `rst` (`rst_pix`)
  resets them to the idle HUD and hides the Bikes at once.
- Blinks follow `BLINK_TICKS = 16` of the viewer (`hud.py`, `render.py`):
  bit 4 of `blink_ticks`, a new `game_core` output that counts with
  `phase_ticks` but wraps instead of holding at 255, so the play icon keeps
  blinking in a long wait as the model's unbounded `phase_ticks` does. The
  crashed Bike now blinks on the same bit (bit 3 before, twice as fast as
  the viewer).
- `fast_core.sv`: two snapshot fields, `g_result` → `snap_result` (crown
  colour) and `g_blink_ticks` → `snap_blink_ticks`, latched on `tick_seen`
  like the other `g_*` buses. A first version counted past 255 in
  `fast_core` itself; its enable used game-domain data and `report_cdc`
  flagged 5 Unknown endpoints (CDC-1 into the counter's CE), so the counter
  moved to `game_core`.
- Benches: `drawcon_hud_tb.sv` (new, in `run_all.sh`) compares every pixel of
  the 1280 × 64 band against a reference written from `hud.py` and `font.py`
  (positions derived from their constants, Python's exclusive segment ends)
  in 13 states: reset straight into the idle HUD, Points 0..63 with carries,
  Lives 0..3, the digits' crash blink, the play icon's blink, the P1, P2 and
  Draw crowns and no crown outside the Match end. A mutant with the reset
  removed and P2's ghost colour off by one fails from the first state on;
  the first band after reset differs in 890 pixels.
  `tron_system_tb` adds HUD pixel checks through the pins, a wait of 260
  ticks with the play icon following the blink, and plays on until P2 has no
  Lives: Match over, P1 wins, cyan crown, P2's Lives hollow. With
  `-g DUMP_FRAMES=1` it writes whole frames, which
  `tools/hdl_frame_to_png.py` turns into PNGs. Owner and domain lines were
  added to the bench headers; the new bench code avoids task `return` and
  `inside` (Icarus).

**Not built, and deliberate differences from the viewer**: the viewer's final
stage (`fx.finish`: scanlines, crash flash), the crash rings, the
Welcome/Pause screens and the neon Wall, grid, sky and Trail effects. With the
band now opaque, a later crash ring would be hidden under empty HUD pixels;
when rings are added, overlay only the lit HUD pixels. Nothing on screen marks
Pause until the Pause screen exists (LED 3 does).

**Source state** (SHA-256)

| File | SHA-256 |
|---|---|
| `game/drawcon_game.sv` | `de8921e5db157dd4de89ab3faee10992aee333dd21cfaf34859abba55e8f4747` |
| `game/drawcon_hud_tb.sv` | `f9323daf0642a6027fd25f4e53d0d26bdafb341f9c1c130d332c96f7066d9ebe` |
| `game/game_core.sv` | `614a48b039701b871a8f00b12526f0b8a21a2d5b224f5601ac25e93cb4e00bd2` |
| `game/fast_core.sv` | `4ac9d745473c6666b8425a6788653233b35f402efdbe459b8f95699e373ebd17` |
| `game/tron_system.sv` | `f20c12b909ba4ab80d966565ed12d6bf3b9c103920edac11e5c924ec27a1d83a` |
| `game/tron_system_tb.sv` | `2f8754c23c11fd555d2c21e9b961ec9ba46bb7e4de1aab4153f552ffea50cdda` |
| `game/game_tb.sv` | `4e0194969364ec4f7cf6dfb8a91619fcf12c40f13e1980c6087d7c19bbf3d787` |
| `game/sprites/hud-icons-16.mem` | `a1f60447a579d830c397e59a785e205d3eb1e0fe3db4e3a001906bbf20c1b486` |
| `crossing/handshake_tb.sv` | `88976cea24434ec2c9e4b553d6359ec31cf309785f045d6b5df6b7a952a22670` |
| `run_all.sh` | `789f82cdce418f792ade06e04eeca2f997d445d950fcc2bf63bb8bf08a1c1bdc` |
| `tools/make_hud_icons.py` | `376cba50e890b164591b2e63325e0e05fcaba196cdf5a3d6f6bc8ca6419cb2c1` |
| `tools/hdl_frame_to_png.py` | `44c5cc9f1f54e7b180ab745250561093f9b8580b9b53e291da1aa369fa1bad9e` |

**Results** (Vivado 2025.2, `alan-desktop` container)

| Check | Result | Host artifact |
|---|---|---|
| `run_all.sh` | 14/14 PASS, `drawcon_hud_tb` included (13 HUD states) | `core-*-20261112-2012*` (`core-drawcon_hud_tb-20261112-201250-686147`) |
| `run_system.sh` | PASS `tron_system_tb`, HUD, blink and crown checks included | `core-tron_system_tb-20261112-200447-610054` |
| `run_game.sh`, mailbox, 6 ticks | 12/12 Step logs and 12/12 arena logs MATCH | — |
| `run_game.sh -g QUALIFIED=1 -g RSP_REG=1 -g STEP_TICKS=8` | 12/12 and 12/12 MATCH | — |
| `crossing/run_crossing.sh` | PASS `handshake_tb`, both modes | `core-handshake_tb-20261112-201224-*` |
| `run_tron.sh mailbox` | Bitstream written; sources identical to the table above | `tron-20261112-200447-610064` |

Routed timing is met: WNS +0.143 ns, WHS +0.062 ns, WPWS +3.000 ns, 0
failing endpoints. `report_cdc`: `clk_pix` to `clk_juego` 21 Unknown plus 1
Safe, as in section 3; `clk_juego` to `clk_pix` 156 Safe, 0 Unknown.
Methodology: `SYNTH-6` and `TIMING-9`, as before. DRC: no violations. 1,164
Slice LUTs, 2.5 Block RAM tiles. `tron_top.bit` SHA-256
`312b2e6cb25c13c68030797cb0e12a606b17957a9a56d554f37e6fa9296e26a7`.

**Board check to run**: idle shows `00` and three full diamonds per Player
and a blinking play icon, still blinking after a minute; Points count up in
decimal past 9; a Crash blinks the crashed Player's digits and Bike about
twice a second and hollows one diamond; the end of a Match shows a crown in
the winner's colour (white for a Draw); `CPU_RESETN` after a Match shows the
idle HUD at once.

### 10.1 Board feedback and the second build (12 November, night)

Alan programmed `tron-20261112-200447-610064` (SHA-256 `312b2e6c…6e26a7`)
and found the HUD working as expected, with two visual flaws, both inherited
from the Python art. The viewer stays the guideline; such flaws are fixed in
the viewer too, so viewer and HDL stay pixel-identical:

- **Hollow Life diamond thicker on one side.** `juego/font.py` `_life_lost`
  put the hole's edge (0.25) exactly on pixel centres; the even-odd test
  rasterized the left side 3 px and the right side 4 px. The hole now reaches
  0.26: a 3 px ring on every side. `sprites/hud-icons-16.mem` was
  regenerated; `drawcon_hud_tb` now also fails if either Life diamond stops
  being mirror-symmetric both ways.
- **A bar across every 0.** The neon "ghost" (unlit segments at a quarter of
  the Player colour) read as a hollow bar on the monitor. At Alan's choice it
  is removed in both: synthwave uses font `seg`, `hud.py` no longer draws a
  ghost, `fx.py` drops its "neon digits" cost line, and `drawcon_game.sv`
  draws only lit segments. Above, read "Points digits" without the glow; the
  mutant result above predates this change.

| File | SHA-256 |
|---|---|
| `game/drawcon_game.sv` | `a815c7b5a5751cdafb4d227b5fdddaafc2f9b8ca1cc93655f754e1f4278e27d4` |
| `game/drawcon_hud_tb.sv` | `1ac11ecbdde637350eb14fed9027d6761a319edc58d5183259dd94329d979b24` |
| `game/tron_system_tb.sv` | `6e5ec7732f22b1e1c7442788a1d85bb688a4729f41baafc207e915da0607dbd9` |
| `game/sprites/hud-icons-16.mem` | `c1d6267794bf9d541143ec08c61b6f82cf361f220220d972e76481211e141f80` |
| `prototipos/tron_fpga/juego/font.py` | `70f0b174c160d5cea27cad385a25397308570e793898666602d23df37c1be668` |
| `prototipos/tron_fpga/juego/hud.py` | `a7a1a6b9c35a26a949c8cd822ac203c1267315dcad2bcecfdf86c05116fac57d` |
| `prototipos/tron_fpga/juego/fx.py` | `6bec26c8668b2db407aca8387598c62af039e7a9ee14d197c201172310d09f6e` |
| `prototipos/tron_fpga/juego/candidates.py` | `1d49e524c0ed4f7abc9d07b84cbe652f6b66fba8aa0d51170c76f1156711d7fd` |

Other sources as in the table of section 10.

| Check | Result | Host artifact |
|---|---|---|
| Python tests (`prototipos/tron_fpga`) | OK | — |
| `drawcon_hud_tb` | PASS, 13 states plus the symmetry check | `core-drawcon_hud_tb-20261112-*` |
| `run_system.sh -g DUMP_FRAMES=1` | PASS `tron_system_tb` | `core-tron_system_tb-20261112-205914-695554` |
| `run_tron.sh mailbox` | Bitstream written; sources identical to the files above | `tron-20261112-205914-695534` |

Routed timing met: WNS +0.255 ns, WHS +0.062 ns, 0 failing endpoints.
`report_cdc` as in section 10 (`clk_juego` to `clk_pix` 156 Safe, 0
Unknown); DRC no violations. `tron_top.bit` SHA-256
`3c1c7a094da6020b2550cbc67da02047828fe0415a8dc0488dd56b4a5318056d`,
programmed by JTAG (DONE high). Alan checked the image on the board the
same night: plain digits with no bar across the 0, and hollow Life diamonds
with an even ring. All good.

## 11. Update, 12 November 2026 (night): the synthwave background and neon Wall

Inside the Arena `drawcon_game.sv` now draws the background of the viewer's
synthwave design (`juego/fx.py` `build_base`): a sky, a striped sun of radius
160 centred on the Arena at (640, 432), 2 × 2 px stars from `fx._star_hash`
that twinkle a quarter per animation phase, and a neon grid every 32 px (a
1 px line pulsing over 4 phases, `818 a2c d2e a2c`, with a `304` glow on each
side). Around the Arena is the neon Wall (`fx._neon_wall`): 2 px tube `F4D`
just outside it, 2 px glow `726` outside the tube, and a 1 px `726` glow on
the Arena's own edge, under Trails, Rewards and Bikes. The phase is
`frame[4:3]` of a video-frame counter, as `fx.phase`.

- **Tables**: `sprites/synthwave-sky.mem` (64 × 12 bit, index `y[9:4]`),
  `synthwave-sun.mem` (321 × 21 bit, `{lit, half width, colour}` per row,
  0 for a cut stripe), `synthwave-grid.mem` (4 pulse colours), written by
  `tools/make_bg_luts.py` from `fx.py` and the synthwave palette.
- **Pipeline**: the background colour is computed from the position 7 pixels
  ahead through seven registers (`bg_rgb`); the Wall colour from the Arena
  look-ahead through one (`wall_rgb`). Neither adds logic between
  `curr_x`/`curr_y` and the VGA pins. The star hash's three constant
  multiplies are DSP48s with their multiplier and output registers (MREG,
  PREG); a first version without them met timing but DRC reported DPOP-1/2
  on each.
- **Board feedback, applied to the viewer and the HDL alike** (the viewer
  stays the guideline; visible flaws are fixed in both): the sky gradient
  `001 → 205` showed as bands on the monitor, so the sky is one colour, the
  gradient's zenith `001` (`bg = sky_low = 001` in `juego/candidates.py`);
  the Wall Cells' `101` read as a magenta band between the HUD and the tube,
  so the synthwave Wall is black (`wall = 000`). An intermediate build that
  dropped the tube instead was rejected on the board.
- **Not yet like the viewer**: the Trails are still flat Cells
  (`0AA`/`A50`), where the viewer draws the Player colour with moving shine
  stripes; the final scanline/flash stage, crash rings and Welcome/Pause
  screens are not built.

| File | SHA-256 |
|---|---|
| `game/drawcon_game.sv` | `77571a25a6a3fd56542f861efe930c652d4ef6002bf3e789c7775889eac26008` |
| `game/tron_system_tb.sv` | `308c099e64de010826185bae4c371a80a95772063d975645dad7215bd56b4063` |
| `game/sprites/synthwave-sky.mem` | `4c4752e8d0f8eaea205a6c6c2ebc6a91cccddf20b4216a4c19276aae38d1d078` |
| `game/sprites/synthwave-sun.mem` | `15884bdd67b4880b65b5918023a9924ea216c123e8ff89430acaeae63650e370` |
| `game/sprites/synthwave-grid.mem` | `c5942b8120707978ba42f90dfdedb2c2071573409599a2e26ea0c00db5a74bbb` |
| `prototipos/tron_fpga/juego/candidates.py` | `1042427868b4a7978516f30060a772a6360e72e9640e26ef728b7ef40b3738c1` |
| `tools/make_bg_luts.py` | `f7001065466903f57d5e52765dd5aafce71ef59e610ab3b2e69925952b4bae47` |

| Check | Result |
|---|---|
| Python tests (`prototipos/tron_fpga`) | OK |
| `tron_system_tb` | PASS, including 16 neon-Wall pixels and 12 background pixels against a reference written from `fx.py` (`bg_at`) at the frame's phase |
| Whole-frame comparison, gradient-sky version | Two dumped frames against `fx.build_base` at the best of the 4 phases: every differing pixel lies in a Cell holding a Trail, a Bike or a Reward; the Wall area (20,034 even-row pixels) matched exactly |
| `run_tron.sh mailbox` (`tron-20261112-221905-1255133`) | Bitstream written. WNS +0.283 ns, WHS +0.122 ns; `report_cdc` as in section 10; DRC no violations; 1,328 Slice LUTs, 3 Block RAM tiles, 3 DSPs |

`tron_top.bit` SHA-256
`c8a3d7d303aec3f25080c181b9db3bfa731f65541571696dc64ba539b48bffd0`,
programmed by JTAG (DONE high); Alan checked it on the monitor and kept it.

## 12. Update, 12 November 2026 (late): Trails, quick look loop, flash, diagrams

**Trails** (`juego/render.py`, trail "pulse"): a Trail or head Cell is drawn in
the Player colour (`0FF`, `F80`); a pixel with `(x + y - 2 frame) mod 64 < 6`
takes the shine colour `c/4 + CCC` (`CFF`, `FEC`), so diagonal stripes 64 px
apart slide along the Trails by 2 px per video frame. A crashed head Cell is
drawn as its Player's Trail. The stripe test is computed on the Arena
look-ahead pixel and registered (`stripe`). This replaces the flat `0AA`/`A50`
Cells. The flat-versus-tile choice was discussed with Alan: the formula is the
viewer's, needs no ROM and moves, so it was chosen over two 16 × 16 tiles per
Player.

**Quick look loop** (`look_loop.sh`, `drawcon_frame_tb.sv`,
`tools/look_frame.py`): one command regenerates the tables, exports a scene
from the model and the viewer's frame of it, renders the scene in XSim (one
frame, ~1 min) and diffs it pixel by pixel, while the bitstream builds; it
programs the board only if routed timing is met. With the Trails, the frame of
the default scene (tick 150, both Bikes turning) differs from the viewer's in
264 pixels, all in the 3 Reward Cells: the viewer pulses the Rewards' tint,
which Alan judged close enough. HUD band, Wall and every Trail pixel match.

**Flash**: `tron_top.xdc` now asks for SPI x4 at 33 MHz, and `run_tron.tcl`
writes `tron_top.bin` (`write_cfgmem`, 16 MB, SPIx4). `program_flash.tcl`
(host) writes it to the board's QSPI flash (read as Mfg ID 1, capacity 18:
the S25FL128S), erases, programs and verifies, then reboots the FPGA from the
flash as PROG does.

**Diagrams**: `diagrams/1-4` are block diagrams in the handout's style, drawn
by `tools/make_block_diagrams.py` from the module ports (board level,
`tron_system`, one Step across the clocks, `drawcon_game`).
`diagrams/vivado/` holds Vivado's own schematics of the synthesized netlist,
one page per level (`run_schematic.sh`, which runs `schematic.tcl` in the GUI
under `xvfb-run`). A first attempt from `synth_design -rtl` in project mode
failed to elaborate (Clocking Wizard module not found, `game_pkg` not
compiled first), so the netlist of a finished build is used.

| File | SHA-256 |
|---|---|
| `game/drawcon_game.sv` | `e1b213b1d57a7cd6c13e2df9338020a5ddd4bb3af6ec9e1073b579b436c832ba` |
| `game/tron_system_tb.sv` | `d5e3b20aeac0b5ea75175c2c980f8f8e4fcc04a59711a5ce2936834177d1138f` |
| `game/drawcon_frame_tb.sv` | `cbdc40d4d9d41d7fc2734e5d7c6a95f69d18ebbc70e98d22a07ee74dcd424810` |
| `game/tron_top.xdc` | `b9f52d2fb2d23776bba6e05e0c5cde21eb63a3676a06360f3b9977cc4e659025` |
| `game/run_tron.tcl` | `6564b902d1c9d7902e8279fee1efc2e352964f454eed16e84b8d2032bc039964` |
| `game/program_flash.tcl` | `b5ab454d039e1d52e24f1e85375be84c6012b91ef28807943c7ddf6b3dddb964` |
| `tools/look_frame.py` | `2d8fd34d1771a26a6d88feec27eb3f3d1cb07833c740d427f82e1d9d17931271` |
| `tools/make_block_diagrams.py` | `5cebfc3c78b204e0e1b5d82b14461cf46f5d8495ba5b87289fac43f178ea2b2d` |

| Check | Result | Host artifact |
|---|---|---|
| `tron_system_tb` | PASS; the Trail checks wait for a frame in which the start Cells hold a stripe pixel and see `CFF` and `FEC` there, `0FF` and `F80` off it | `core-tron_system_tb-20261112-231644-1507345` |
| `look_loop.sh` frame comparison | 264 differing pixels, all in the 3 Reward Cells | — |
| `run_tron.sh mailbox` | Bitstream and flash image written. WNS +0.066 ns, WHS +0.059 ns, 0 failing endpoints; `report_cdc` as in section 10; DRC no violations | `tron-20261112-232719-1511752` |
| `program_flash.tcl` | Erase, program and verify successful; DONE high after booting from the flash | — |

`tron_top.bit` SHA-256 `56a8d0e7e646d92b4d563e62d6e971930c30e431d5317bf784c480fab9f32b2c`,
`tron_top.bin` `25421aaa6cbaea3b16b10db903a99244cbe90e72918fb92a1bf6bbddf3e0ea15`.
The slack is small: the critical path is still the combinational VGA output
path of section 1 (Roman's open question in `docs/design/CS-256 VGA Output
Timing Findings.md`); registering `drawcon`'s output is the remedy if a later
change fails timing.
