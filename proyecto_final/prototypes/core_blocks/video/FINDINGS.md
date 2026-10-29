# Video timing and divided game clock feasibility evidence

29 October 2026. **Provisional evidence, not team agreement or an official
contract §7 testbench.** Owner: Roman for `vga_out`, both Clocking Wizards and
the divider. Alan owns integration/top-level reset/XDC. Only this `video/`
folder was authored; existing HDL, shared runners/package and Git were not edited.

## 1. Built scope, authority and interfaces

Read root AGENTS, docs README/architecture map/glossary, the agreed specification,
contract §§1–6 and ownership §7, accepted ADR 0002, proposed ADRs 0003/0005,
course handout (including Drawing Logic steps 10–12), VGA raster design note,
UART findings and its board/run Tcl, and Tron HDL skill §§1–3/6.

- `vga_out_check_tb.sv` drives the unchanged contract §4 ports: inputs
  `clk_pix`, synchronous active-high `rst`, RGB444 `draw_r/g/b`; outputs
  11-bit `curr_x/y`, RGB444 `pix_r/g/b`, `hsync/vsync`, and `tick_60hz`.
  Raster is 1680 × 828, visible h=336..1615, v=27..826, HS low h=0..135,
  VS high v=0..2. Contract §3 requires output-aligned coordinates.
- `game_clk_div.sv` has **provisional** ports `clk_base`, synchronous active-high
  `rst` (base domain), `clk_juego` (generated clock). Parameters `input_hz`,
  `target_hz`, `half_cycles` permit rounding to a whole half-period; defaults
  4,687,500 Hz, 60 Hz, 39,063 cycles. Six game ticks per Step is unchanged.
  `game_clk_div_tb.sv` tests nominal and accelerated divisors, including a
  half-period of one cycle. No Python model files apply to raster/division.
- `clock_feasibility.tcl` and `run_clocks.sh` generate two clk_wiz 6.0 IPs for
  xc7a100tcsg324-1 with nominal 100 MHz input, no reset and no locked port.
  Both request `No_buffer` input, as the UART experiment does: integration must
  supply a shared board IBUF. This experiment generates IP, not a board top.
- Working baseline is accepted ADR 0002's second Wizard plus toggle divider;
  proposed ADR 0003's fast service uses `clk_pix`. No mailbox, display coherence
  or CDC protocol is selected here. Divider reset/startup policy and its ports,
  Wizard lock-loss recovery, and the fate of `tick_60hz` remain open.

The second Wizard requests **4.6875 MHz**, rather than copying the UART
experiment's 5 MHz. For the -1 MMCM, the 600 MHz VCO floor and maximum output
division 128 give 600/128 = 4.6875 MHz, fitting the handout's lowest-frequency
instruction. Generated primitive parameters independently confirm this choice.

### BUFG and reset choice

Vivado synthesis's `SYNTHESIS` branch instantiates `BUFG u_game_buf`; normal
simulation uses a continuous wire. This keeps ordinary `iverilog -g2012`
compilation independent of vendor libraries (Icarus is unavailable here), while
actual synthesis confirms one BUFG, not an unbuffered fabric clock. Vendor
buffer timing is not simulated by the behavioral branch. Do not define
`SYNTHESIS` in portable simulation without supplying vendor primitive models.

The counter and toggle have configuration initial values of zero. Explicit
`rst` clears both synchronously; after release the first rise is exactly
39,063 base edges later. Reset while high truncates that high half; it does
not promise a normal period spanning reset. **Do not wire CPU reset or Pause
to divider rst:** normal clock operation must continue while consumer resets
are synchronized. Hold it low in normal operation; reset game consumers
separately. The bench tests the optional divider phase reset only. Integration
must design reset synchronization/hold time; declaration initialization does
not demonstrate safe startup while the MMCM settles.

Integration constraint proposal (not run by the shared OOC runner), after
synthesis with the actual divider instance name substituted:

```tcl
set toggle_c [get_pins u_div/game_toggle_reg/C]
set buffered_o [get_pins u_div/u_game_buf/O]
# Assert both queries resolve to exactly one pin before applying this.
create_generated_clock -name clk_juego -source $toggle_c -divide_by 78126 $buffered_o
```

Define it at BUFG/O, not toggle Q: Q also feeds the toggle's D feedback, which
must remain timed in the base domain. No clock-group/false-path exceptions are
proposed. Placement/routing of the fabric-to-BUFG source remains to be checked.

## 2. Source state and tool version

Exact SHA-256 values for every authored `.sv`, Tcl/shell script, and the
unchanged DUT dependencies/shared runners/package are in
[evidence/source-hashes.sha256](evidence/source-hashes.sha256). From repository
root verify with `sha256sum -c proyecto_final/prototypes/core_blocks/video/evidence/source-hashes.sha256`.
Vivado/XSim **2025.2**, SW build **6299465**, IP build **6300035**;
Clocking Wizard `xilinx.com:ip:clk_wiz:6.0`. Full IP property reports and the
actual generated MMCME2_ADV parameter excerpts are retained as text in
`evidence/`. Generated vendor HDL remains solely in build artifacts.

## 3. Commands and results

Run commands from repository root with sandbox escalation, using the fixed
`sudo -n /usr/local/sbin/cs256-vivado` launcher internally. No source mutation
or baseline VGA synthesis is needed. Host artifact paths below are under
`/home/alan/.local/share/cs256-vivado/builds/`; each name denotes a full run
directory there. Host timestamps and container log dates use different zones.

### Existing bench, unchanged — runner FAIL

```bash
proyecto_final/prototypes/core_blocks/run_xsim.sh vga_out_tb vga_out_tb.sv vga_out.sv counters.sv
```

Artifact: `core-vga_out_tb-20261029-000327-600358`.
Log prints `PRUEBAS OK`, no reported mismatches, but **no `PASS vga_out_tb`**;
runner exits 1 (`RESULT: missing PASS vga_out_tb`). This is a bench signalling
finding, not evidence of a failed pulse measurement. Original sim log retained
as `evidence/vga-original-sim.txt`. Its delayed `it_was_visible` check accepts
the current output latency and does not independently verify output coordinates.

### Independent two-frame bench — FAIL, documented DUT finding

```bash
proyecto_final/prototypes/core_blocks/run_xsim.sh vga_out_check_tb prototypes/core_blocks/video/vga_out_check_tb.sv vga_out.sv counters.sv
```

Artifact: `core-vga_out_check_tb-20261029-000430-601571`.
Ran **2,782,080 cycles**, two complete frames after reset, covering
**2,048,000 visible output pixels**. Bench uses an independent raster, not
hierarchical reads of DUT counters. It checks every output sample against
both the current contract raster and the preceding raster to isolate latency.

```text
sync_mismatches=3312
blank_mismatches=1600
coordinate_mismatches=2048000
delayed_raster_mismatches=0
Fatal: vga_out violates output coordinate/raster alignment
```

No PASS marker; runner exits 1 as expected. `evidence/vga-check-run.txt` keeps
the full short result. **All mismatches share one cause:** sync and RGB are
registered from the old raster while coordinates are combinational from the
incremented raster. Output pixel (0,0) has coordinates (1,0); each line's last
output visible pixel has curr_x=1280. Against current coordinates, each row
has a nonzero colour sample at x=1280 outside the visible area (800 × 2).
The zero delayed-raster mismatch count verifies the pulse polarity/duration,
136 active HS samples, 1680 cycles per line, three VS lines, 828 lines per
frame, visible colour and black blanking **in the delayed output raster**.
Sync mismatch count combines HS and VS differences at the same sample.

**Proposed fix for Roman, not applied:** follow the handout's combinational
output baseline: derive hsync, vsync and blanked RGB combinationally from the
same current counters as `curr_x/y`. For example, move these assignments into
an `always_comb` with blocking assignments on all branches and remove their
sequential drivers. Keep counters synchronous. This removes the extra cycle
and restores current-pixel drawcon alignment, including sprite prefetch work.
Rerun both benches after the owner applies the change. Registering coordinates
alone would also require a deliberate draw-input timing contract and therefore
is not the proposed baseline fix.

### Divider bench — PASS

```bash
proyecto_final/prototypes/core_blocks/run_xsim.sh game_clk_div_tb prototypes/core_blocks/video/game_clk_div_tb.sv prototypes/core_blocks/video/game_clk_div.sv
```

Artifact: `core-game_clk_div_tb-20261029-000507-602896`.
`PASS game_clk_div_tb half_cycles=39063 period_cycles=78126 rises=6 falls=5 resets=5`.
Checks every base edge: exact high/low durations and rise periods, no output
change from reset assertion between edges, reset while low with partial count,
reset while high, deterministic restart, plus independently expected divisions
of 10 and 2. The simulation uses 10 ns base periods for speed; assertions and
reported divider timing are in **input cycles**, not claimed nominal seconds.

An initial invocation of this same command failed compilation because the
bench instance was named `small` (a reserved keyword). Renamed it `u_small`;
no DUT change. Failed artifact: `core-game_clk_div_tb-20261029-000431-601815`,
with its source copy; compiler log retained in `evidence/divider-initial-compile.txt`.
All XSim runs warn XSIM 43-3431 about the installed C-compiler environment;
final divider elaboration/simulation succeeds.

### Clocking Wizard generation — PASS

```bash
proyecto_final/prototypes/core_blocks/video/run_clocks.sh
```

Artifact: `core-video-clocks-20261029-000432-602140`.
`clock_feasibility.tcl` uses generated IP properties and generates all targets;
`evidence/generated-mmcm-excerpt.txt` also confirms actual primitive M/D/O.

| Clock | Request MHz | M | D | O | Achieved Hz | VCO MHz | PFD MHz |
|---|---:|---:|---:|---:|---:|---:|---:|
| Pixel | 83.460 | 28.375 | 4 | 8.5 | 83,455,882.35294117 | 709.375 | 25 |
| Game base | 4.6875 | 6 | 1 | 128 | 4,687,500 | 600 | 100 |

Derived anew from `100,000,000 × M / D / O`:

- Half-period = round(4,687,500 / 120) = **39,063** base cycles.
- Game rate = 4,687,500 / 78,126 = **59.99923200983027 Hz**.
- Error from 60 Hz = **−0.000767990169727284 Hz**, **−12.7998361621 ppm**.
- Frame rate = 83,455,882.35294117 / (1680 × 828) = **59.995314550941146 Hz**.
- Game ticks per frame = **1.0000652960805099**. The clocks must not be treated
  as one tick per frame or as automatically blanking-aligned.

Both VCOs and PFDs are within the -1 limits cited in the raster design note.
Rates assume an exact nominal 100 MHz board oscillator; oscillator error scales
both. Generated IP is frequency feasibility evidence, not routed clock proof.

### Divider OOC synthesis — PASS

```bash
proyecto_final/prototypes/core_blocks/run_synth.sh -c clk_base 213.333333 game_clk_div prototypes/core_blocks/video/game_clk_div.sv
```

Artifact: `core-synth-game_clk_div-20261029-000431-601730`.
**7 LUTs, 17 FFs, 1 BUFG, 4 CARRY4, 0 latches, 0 BRAM, 0 LUT RAM, 0 DSP**.
**WNS +209.609 ns; WHS +0.338 ns; WPWS +106.166 ns**. Zero failing internal
setup/hold endpoints, zero unclocked registers or unconstrained internal
endpoints. One input (rst) has no delay, and one output (clk_juego) has no
output delay, as expected for the runner's OOC-only constraints. No game-clock
consumer is synthesized here. The runner rounds the input period to
213.333 ns and warns HD.CLK_SRC is unspecified, so skew cannot be estimated;
these are synthesized estimates, not physical timing closure. The no-latch
and empty-RAM query warnings are consistent with zero resources.

**Baseline `vga_out` synthesis is supplied by the orchestrator**, not rerun:
46 LUTs, 36 FFs, zero latches, WNS **+7.831 ns at 11.982 ns**. WHS/RAM details
and the artifact path were not supplied; no independent synthesis claim is made.

## 4. What the evidence establishes

The existing VGA pulse lengths and blanked colour stream are internally
consistent with one delayed raster, but the public coordinates violate the
output-alignment requirement. The independent bench deliberately remains
failing until Roman fixes it. The divider's deterministic digital behavior
and small synthesized resource footprint are demonstrated. Both requested
Wizard frequencies generate legal IP, and the achieved rates are derived
from actual generated configuration rather than copied UART figures.

## 5. Limitations, risks and requests to Roman/Alan

- Roman: apply/review the combinational VGA output fix; update his bench to
  print `PASS vga_out_tb` only on success and `$fatal` when errors are nonzero.
  The shared runner should retain its strict PASS rule. No shared-file edit
  is required by this experiment.
- Record accepted divider ports/rate/reset policy in the contract before
  dependent production blocks adopt them. Resolve the unused `tick_60hz`
  output separately; it is currently constant zero and is not the game clock.
- Alan/Roman: integrate shared IBUF, Wizard output buffers and divider BUFG,
  apply/verify the generated clock at BUFG/O with real hierarchy, and inspect
  placed/routed timing, pulse width, clock coverage, DRC and CDC. A BUFG does
  not establish safe source routing or coherent game/render transfers.
- Reset during a high half can shorten it, so the optional divider reset is
  a phase-reset experiment, not a safe system game-reset distribution scheme.
  Keep clocks running during Pause/CPU reset and test consumer reset separately.
- No board, monitor lock, full-game CDC, display publication, sprite pipeline,
  MMCM lock-loss recovery or Icarus execution was tested. Invalid parameters
  (nonpositive rates or half_cycles) are outside the candidate's supported
  domain. Official cross-owner verification is still required by contract §7.


## Update, 29 October 2026 (orchestrator)

Alan asked for Roman's code to be fixed. `proyecto_final/vga_out.sv` now
drives `hsync`, `vsync` and `pix_*` combinationally from the counters, as
the handout's assignments do, so `curr_x`/`curr_y` name the pixel on the
pins in the same cycle (Design Plan, Decision B). `vga_out_check_tb` mixed
two contradictory references: strict checks against the current raster, and
"delayed raster" checks that assumed the old registered outputs. It now
checks everything against the current raster, including the colour against
the current `draw_*`.

Roman's `vga_out_tb` now prints `PASS vga_out_tb` and calls `$fatal` on
errors. Its pixel check compares in the same cycle, at the falling edge.
`counters_tb` declares the 11-bit `vcnt` agreed on 26 October. Both benches
pass; see `game/FINDINGS.md` for the run artifacts.
