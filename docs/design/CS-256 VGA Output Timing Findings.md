# CS-256 VGA Output Timing Findings

**Status: open, for review.** Recorded 2 November 2026 from the routed builds of 29 October. Owner of the decision: Roman (`vga_out`, `drawcon`). Nothing here changes the code; it collects the evidence and the checks for the decision listed in `proyecto_final/prototypes/core_blocks/game/FINDINGS.md` section 1 ("Other choices and deviations").

## Question

`vga_out` drives the VGA pins combinationally, as the course handout's *VGA Sync Signals* and *Visible Pixel Counter* sections describe and as the [VGA and Sprite Design Plan](CS-256%20VGA%20and%20Sprite%20Design%20Plan.md), Decision B, selects: `curr_x`/`curr_y` name the pixel on the pins in the same cycle. The routed design meets timing, but the colour path from the raster counters through `drawcon_game` to the pads uses almost the whole pixel period. Should the outputs stay combinational, or be registered?

## Evidence

The build script constrains every path from a flip-flop or block RAM to the VGA, segment and anode pads to one `clk_pix` period: `set_max_delay -datapath_only 11.982` (`proyecto_final/prototypes/core_blocks/game/run_tron.tcl:131`). Host build folders are under `/home/alan/.local/share/cs256-vivado/builds/`.

| Build | Worst pad path | Data path | Slack | Logic levels |
|---|---|---|---|---|
| Mailbox, 6 ticks (`tron-20261029-233130-2009133`) | `u_vga/c_counter/hcnt_reg[6]` → drawcon → `vga_g[3]` | 11.686 ns | +0.296 ns | 9 (2 CARRY4, 6 LUT, OBUF) |
| Captured, 8 ticks (`tron-captured-s8-20261029-232239-1926071`) | `u_vga/c_counter/vcnt_reg[3]` → drawcon → `vga_r[0]` | 11.667 ns | +0.315 ns | 10 (2 CARRY4, 7 LUT, OBUF) |

- These pad paths are the design's worst setup paths. Internal `clk_pix` → `clk_pix` paths have about +2.4 ns of slack.
- The output buffer alone takes about 3.55 ns of each path (`OBUF (Prop_obuf_I_O)` in `timing_summary.rpt`). That leaves about 8.1 ns for the counter, the compare logic, the drawcon layer mux and routing.
- The next worst paths are close behind. In the mailbox build the ten worst VGA pads lie between +0.296 and +0.674 ns, starting from the `hcnt`/`vcnt` counters or from the Arena BRAM's port B clock (`u_ram/mem_reg/CLKBWRCLK`).
- With the default implementation strategy this path failed once at −0.361 ns. The build therefore uses `Performance_Explore` (`run_tron.tcl:141`). Its margin depends on placement, so small drawcon changes can break timing.
- `game/FINDINGS.md` quotes "11.78 of 11.98 ns". The routed reports listed above show 11.686 and 11.667 ns; the 11.78 figure appears to come from an earlier build.

### What the constraint means physically

The Nexys A7's VGA port is a resistor-ladder DAC with no forwarded clock, so the monitor does not sample the pins against `clk_pix`. The one-period budget is a proxy: each colour bit must settle within its pixel, with bit-to-bit skew well below a pixel. Missing it by a fraction of a nanosecond would shift colour edges by part of a pixel (fringes at sprite and Cell edges) rather than corrupt the game. That is why the board checklist in `game/FINDINGS.md` section 5 asks to look for colour fringes.

## Options

| Option | What changes | Contract impact | Cost |
|---|---|---|---|
| **A. Keep as is** | Nothing | None | Margin stays ~0.3 ns; every drawcon change risks a timing failure and needs `Performance_Explore` |
| **B. Register in `vga_out`** (Roman's original) | `vga_out` registers sync and colour, so the pins lag `curr_x`/`curr_y` by one cycle | Contract §3/§4 rows for `curr_x`/`curr_y` (output-aligned) change: coordinates lead the pins by one cycle. Departs from the handout's Decision B; would need to be recorded as a justified departure | Each drawcon look-ahead grows by one (Arena 1 → 2, sprite ROM 2 → 3); `vga_out_check_tb` and `vga_out_tb` change |
| **C. Register inside `drawcon_game`** | drawcon composes the pixel one position ahead (the existing `ahead()` function, lead 1) and registers `draw_r/g/b`; Arena lead 1 → 2, sprite lead 2 → 3 | None: `vga_out` and its ports are unchanged, and `draw_*` still describes the current `curr_x`/`curr_y` pixel | The pad path becomes `draw_*` register → `vga_out` blanking mux → OBUF. The blanking mux still depends on the `hcnt`/`vcnt` compares, so it does not shrink to a bare flop-to-pad path, but the drawcon layer logic leaves it. The per-frame Bike snapshot latch must still fall before the earliest look-ahead read |

Option C keeps the handout's interface and the contract as they are and removes drawcon's layer logic from the pad path. It is a proposal: it has not been built or simulated. Option B is what Roman first wrote. Moving all output logic into IOB flip-flops (`IOB TRUE`) needs registered outputs first, so it follows B or C rather than being a separate choice.

## Checks for the review

Run these before and after any change; all run in the Vivado container through the existing scripts (run outside the agent sandbox, since they need `sudo -n`).

1. **Board, current build.** Program the board and look for colour fringes at sprite and Cell edges, particularly on Bikes moving over Trails. Record the result in `game/FINDINGS.md` section 5. If there are no fringes, option A remains viable for the demo.
2. **Default-strategy margin.** Rebuild once with the default implementation strategy (comment out `run_tron.tcl:144`) and record the worst VGA pad slack. If it still fails, the design depends on `Performance_Explore`.
3. **Pad paths after a change.** In `timing_summary.rpt`, under "Path Group: \*\*default\*\*, From Clock: clk_out1_tron_pixel_clock", record the ten worst VGA pad slacks and their sources, as in the table above.
4. **Raster alignment.** `proyecto_final/prototypes/core_blocks/run_xsim.sh vga_out_check_tb prototypes/core_blocks/video/vga_out_check_tb.sv vga_out.sv counters.sv` must still pass. For option B it needs the new one-cycle lead; for option C it should pass unchanged.
5. **Picture content.** `game/run_system.sh` (`tron_system_tb`, 43 checks) must still pass. Its sprite checks catch an off-by-one look-ahead: a Bike or Reward shifted by one pixel fails them.
6. **No new CDC or methodology rows.** Compare `report_cdc_summary.rpt` and `report_methodology.rpt` with the current evidence in `game/evidence/` and `crossing/evidence/`.

## Related

- `proyecto_final/vga_out.sv`, `proyecto_final/prototypes/core_blocks/game/drawcon_game.sv` (look-ahead comments at the top).
- `proyecto_final/prototypes/core_blocks/video/FINDINGS.md`: the 29 October change from registered to combinational outputs.
- `proyecto_final/prototypes/core_blocks/game/FINDINGS.md`: section 1 (deviation), section 3 (worst setup path) and section 5 (board checklist).
- Interface contract, §3 and §4 (`curr_x`, `curr_y`, `draw_*` rows).
