# Board integration feasibility evidence — 29 October 2026

**Provisional board test pattern, not the game, team agreement or the official
cross-owner contract §7 benches. Board check remains TO RUN on alan-legion.**

## 1. Built scope and governing interfaces

Owner Alan: integration, reset, constraints; Roman owns VGA/drawing/clocks.
Follows contract §§1–6, accepted ADR 0002, proposed ADRs 0003/0005 and Official
FPGA Coding Practices. Read course project handout and sibling block findings.
No Python game model applies to this board-only pattern. No game logic,
Step, scoring, reward placement, game↔Arena transfer or coherent render
publication is selected. The separate datapath experiment is not a dependency.

- `core_board_top.sv`: contract §2 signal names/widths for clk, cpu_resetn,
  btn, sw, VGA, seg/an and led. UART is deliberately omitted because this
  pattern has no serial behavior. Existing Roman VGA/counters are unchanged.
- Shared input IBUF drives two catalog Clocking Wizards, no reset/locked ports
  (handout baseline). Second Wizard feeds unchanged sibling `game_clk_div`,
  permanently rst=0. A generated clock at its BUFG/O has divide_by=78126;
  feedback remains timed in the base clock domain.
- CPU reset inverted once, two initialized flops in each consuming domain,
  synchronous active-high consumers. Hold CPU_RESETN low at least **100 ms**
  on the board (covers three slow edges). Short pulses can be missed by the
  game domain. MMCM settling/lock-loss robustness is not established.
- Five buttons use io/btn_debounce including its io/sync_2ff. All 16 switches
  independently synchronize in clk_pix. SW0 pauses admission of test writes;
  it does not stop clocks, clear, an accepted COMMIT, or the tick display.
- CLEAR starts after every pixel reset; rendering hides RAM until CLEAR and
  seed COMMIT finish. A P1 cyan head starts at Cell (20,27); P2 yellow marker
  stays at (59,27). Any debounced button moves P1 one Cell right, leaves blue
  trail, stops at cx=78. This is test behavior, not Tron movement. P2 is
  rewritten at its fixed Cell by each COMMIT, exploiting old=target and the
  controller's documented head-last ordering. No sibling interface changed.
- `drawcon_arena.sv`: all ports/timing provisional, combinational drawing and
  one-cycle early B address. Full raster wrap reconstructed from curr_x/y,
  with harmless address zero in blanking. RAM read data matches current draw
  coordinates before unchanged VGA registers consume both on the next edge.
  Thus physical Cell boundaries remain multiples of 16 despite VGA's known
  one-cycle coordinate lead. White 10 px border takes priority, including
  during CLEAR. Black outside active image; EMPTY black, WALL gray 444,
  P1 trail/head 08f/0ff, P2 trail/head f80/ff0, CRASH f00, rewards 0f0/80f/f0f,
  reserved/undefined 888. Palette is provisional, codes are contract §5.
- **Test-pattern crossing only:** six-bit modulo-64 game tick counter, Gray
  encoded into source registers, two ASYNC_REG flops per bit at clk_pix,
  decoded only after second stage. Max delay and bus skew to first stage
  bounded to 11.982 ns. No clock groups or broad interclock false paths.
  Gray transitions have one bit per tick including 63→0. Synchronous reset
  may change several Gray bits at once; transient display values during reset
  settling are allowed, no control action consumes this counter. Display
  reads P1=00..63, P2=00. LED0 is game counter bit5 (~0.94 Hz square wave).
  LED1=ready, LED2=SW0 synchronized, LED3=XOR SW1..3, LED15..4=SW15..4.

External pin exceptions terminate exclusively on first-stage input/reset
synchronizers; the second stages and their fanout remain timed. VGA/seg/an
use an **internal register-to-pad engineering budget** of 11.982 ns, LEDs
1000 ns. These max-delay bounds are not fabricated monitor setup/hold delays;
there is no external capture clock. Board electrical quality/monitor lock
still require observation. Full-game crossing ADR 0003 item 2 stays open.

## 2. Source state and tool version

SHA-256 of all authored HDL/scripts/XDC and actual dependency HDL is retained
in `evidence/source-hashes.sha256`. Generated IP and source snapshots live in
the fresh build folder, not this repository. Vivado/XSim 2025.2, Clocking Wizard
6.0; exact version and IP properties retained in evidence. Git read-only.

## 3. Commands, results and artifact paths

From repository root, with sandbox escalation for the fixed sudo launcher:

```bash
proyecto_final/prototypes/core_blocks/board/run_board.sh
```

Runner creates a fresh `/builds/core-board-<timestamp>-<pid>`, copies
`proyecto_final/` under src, generates IP, checks PASS markers and fatal/error
messages, synthesizes and implements through bitstream, then emits full reports.

**Results (recorded by the orchestrator, 29 October 2026; the builder stopped
at its usage limit before writing them).** Final build:
`/home/alan/.local/share/cs256-vivado/builds/core-board-20261029-003328-660374/`,
Vivado 2025.2, `BUILD_COMPLETE.txt` present, bitstream `core_board_top.bit`.

- Benches: `PASS drawcon_arena_tb visible=2048000 all Cell edges, porches,
  frame wrap`; `PASS core_board_top_tb CLEAR press hold pause reset Gray tick`.
- Achieved clocks: pixel 83 455 882.35 Hz, base 4 687 500 Hz (divider 78126,
  so `clk_juego` is 59.999 Hz).
- Routed timing: WNS +2.140 ns, WHS +0.122 ns, WPWS +0.027 ns; "All user
  specified timing constraints are met"; `no_clock` 0, unconstrained internal
  endpoints 0.
- Utilization: 236 LUTs, 328 registers, 1 Block RAM tile.
- CDC: 24 CDC-3 (1-bit, ASYNC_REG) Info and one CDC-6 Warning. The warning is
  the 5-bit Gray tick bus into `gray_meta_reg`: multi-bit synchronized,
  bounded by `set_max_delay -datapath_only` and `set_bus_skew` at one pixel
  period. That is the intended Gray-code crossing of the test pattern.
- Methodology: one SYNTH-6 (no output register merged into the Arena BRAM;
  timing still meets). DRC: no violations listed.

The playable build in `game/` supersedes this test pattern for board use.

## 4. What the evidence shows and does not show

The two builder simulations check RAM-to-output-raster alignment and board
pattern sequencing. Routed evidence covers these composed basic blocks on
the actual target part; it does not establish whole-game operation, a selected
mailbox, six-tick Step throughput, sprites, reward/lifecycle/scoring integration,
coherent game publication, metastability MTBF, or official independent tests.
A bitstream and timing closure do not demonstrate a functioning physical board.

## 5. Limitations, risks, board procedure and requests

Board validation **TO RUN**, Alan, Nexys A7-100T attached to alan-legion.
Install/use Vivado Lab there, power board, connect programming USB and VGA to a
1280×800-capable monitor; select JTAG programming. Copy the final bitstream
from the host artifact path below to `/tmp/core_board_top.bit` on alan-legion,
and copy this folder's `program_board.tcl` to `/tmp/program_board.tcl`.
In a terminal with Vivado Lab available:

```bash
vivado_lab -mode batch -source /tmp/program_board.tcl -tclargs /tmp/core_board_top.bit
```

The script connects localhost hw_server, opens the target, requires exactly
one xc7a100t device, sets PROGRAM.FILE, programs and refreshes it. Alternatively
run these exact script statements in Vivado Lab's Tcl console after setting
`argv` to `[list /tmp/core_board_top.bit]`. No .ltx (no ILA). Programming is
volatile JTAG; this does not write board flash.

Checklist, record date/monitor and pass/fail for each:

- [ ] Monitor locks stably near 60 Hz, 1280×800. White border exactly 10 px.
- [ ] Gray HUD/wall Cells; black play area. Cyan P1 at pixel (320,432), yellow
      P2 at (944,432), both 16×16. LED1 comes on after initialization.
- [ ] Hold each button >10 ms: exactly one Cell right, blue trail at old Cell;
      no repeat while held; release >10 ms permits next press. Stop at cx=78.
- [ ] SW0 up: LED2 on; presses do not move P1. SW0 down: presses work again.
- [ ] LED0 visibly toggles about every 0.533 s; P1 decimal display counts
      00..63 about 60 times/s, wraps about 1.067 s; P2 remains 00. No scoreboard
      Lives page in this pattern. Check scan polarity, brightness/ghosting.
- [ ] SW4..15 mirror on LED4..15, SW1..3 XOR on LED3.
- [ ] Hold CPU reset >100 ms, release: P1/trail return to initial image,
      counter restarts; repeat several times including with SW0 up and a
      button held. A button held over reset qualifies a fresh press afterward.
- [ ] No edge smearing, flicker, 1 px shifted Cell, intermittent image or
      unexplained reset behavior. Photograph screen and note actual display.

Requests: Roman should reconcile VGA's public coordinate alignment as already
recorded in video/FINDINGS.md; this adapter is deliberately tied to current
registered outputs and must be retested after that change. Alan/Roman must
approve production interfaces separately. No shared source edits requested
for rerunning this experiment. Physical board checks and lock-loss policy
remain outstanding; game crossing remains unselected.
