# Core blocks: provisional SystemVerilog feasibility experiments

Started 29 October 2026. These are the most basic blocks of the Tron game, each
built against the contract and the working defaults of
[ADR 0003](../../../docs/adr/0003-step-transaction-mailbox-and-render-codes.md),
then simulated and synthesized to test whether the prototype's design choices
hold in hardware. Under [ADR 0005](../../../docs/adr/0005-build-with-provisional-interfaces.md)
(proposed) every port, timing and handshake here that the contract does not
already state is **provisional**. Passing these benches is **evidence**, not team
agreement; the testbenches here are the builder's own checks, not the
**official** testbenches of contract §7, which the other owner writes.

## Layout

| Path | Contents |
|---|---|
| `game_pkg.sv` | Contract §5 package, copied verbatim. Change the contract first |
| `game_pkg_tb.sv` | Checks the package's derived constants |
| `run_xsim.sh` | One self-checking XSim bench in the Vivado 2025.2 container |
| `run_synth.sh` | Out-of-context synthesis: utilization, latches, RAM inference, timing |
| `run_all.sh` | Reruns every block bench in parallel and summarizes |
| `video/`, `arena/`, `step/`, `score/`, `io/` | Round one: one folder per block set, with modules, benches, `FINDINGS.md` and `evidence/` |
| `datapath/` | Round two: the Step transaction across two clocks, driven by a model trace |
| `board/` | Round two: board test-pattern bitstream (clocks, Arena, drawcon) |
| `game/` | The playable core: `tron_top` bitstream, M2 replay of the full HDL game, end-to-end pins bench, P2 web page and the board checklist |
| `crossing/` | The game-fast crossing experiment (ADR 0003 item 2, ADR 0006): req/ack responses, `batch_fifo`, protocol benches, routed CDC comparison; also the research note's clock probe |

## Writing a block

- SystemVerilog `.sv` only. Contract §1: `logic`, `snake_case`, one module per
  file named after the module, one signal per Player (`_p1`, `_p2`) and no array
  ports, synchronous active-high `rst`. `import game_pkg::*;` for constants.
- `always_ff` with `<=`; `always_comb` with `=`, assigning every output on every
  branch.
- The header comment names the owner (contract §4/§7), the clock domain, every
  crossing, and each **provisional** port or timing.
- Keep the code Icarus-compatible (`iverilog -g2012`), although Icarus is not
  installed here.

## Testing a block

Benches are self-checking. They print `PASS <bench_top>` only after every check
passed, and use `$fatal`/`$error` on failure. Derive expected values from the
agreed specification and the contract: those are the **independent** checks.
Comparing against the Python model (`prototipos/tron_fpga/model/`, headless,
`python3` run from `prototipos/tron_fpga/`) is useful but not independent proof.
Generated vector files live in the block folder with the script that made them.

```bash
# From anywhere; paths after the bench name are relative to proyecto_final/.
proyecto_final/prototypes/core_blocks/run_xsim.sh [-g NAME=VALUE]... BENCH_TOP FILE.sv...
proyecto_final/prototypes/core_blocks/run_synth.sh [-g NAME=VALUE]... [-c CLK_PORT PERIOD_NS]... TOP FILE.sv...
```

Both run through `sudo -n /usr/local/sbin/cs256-vivado`, so run them outside the
sandbox (request escalation). Each run copies `proyecto_final/` to a fresh
`/builds/core-*` folder; the host path is printed at the end. A bench that reads
a vector file opens it relative to the run folder: use
`src/prototypes/core_blocks/<block>/<file>`. `clk_pix` is 83.46 MHz, so
`-c clk_pix 11.982`. Synthesis is out of context, so it shows resources, latches,
RAM inference and logic depth; it is not routed sign-off.

## Recording findings

Each block folder has a `FINDINGS.md` that another agent can rerun from alone:

1. What was built, and which contract ports, working defaults and model files it
   follows; every deviation, with its reason.
2. Source state: `sha256sum` of each `.sv` and script, and Vivado 2025.2 from the
   container.
3. Each command run and its result (PASS markers, utilization, WNS/WHS, latch
   and RAM counts), with the host artifact path.
4. What the evidence shows, and what it does not show.
5. Limitations, risks to the design choice under test, and open questions for
   Roman and Alan.

Copy short logs worth keeping into `<block>/evidence/` (text only).

## Findings at a glance (29 October 2026)

Each folder's `FINDINGS.md` holds the commands, artifacts and limits.

- **Playable core** ([game/](game/FINDINGS.md)): the full HDL game, with Bike and
  Reward sprites from ROM (the synthwave art), reproduces the model's 12 M2
  Step logs exactly, `tick` included, at several clock phases and game
  periods. An end-to-end bench through the board pins passes 43 checks,
  including texel-exact sprite rows in all four Headings. `tron_top.bit` meets
  routed timing (WNS +0.202 ns on a VGA pad path, internal +2.30 ns;
  WHS +0.028 ns) using 1.62 % of the LUTs. **Not yet run on the board**: the
  checklist is in its section 5.
- **Crossing** ([crossing/](crossing/FINDINGS.md)): the model's stable-payload
  mailbox works, but its 21 fast-to-game capture registers are an unknown CDC
  in Vivado. Under ADR 0006 (8–10 ticks per Step), the "captured" variant
  replaces them with a req/ack response captured on a synchronized toggle and
  a Gray FIFO for input batches. It needs READ2 + COMMIT = 8 ticks, matches the
  model at 8 and 10 ticks, and routes with **0 unknown CDC and no waiver**.
  Inputs arrive 2 ticks later than with the mailbox. A 6-tick variant also
  works but needs a 5-endpoint waiver. Input for ADR 0003 item 2.
- **Fast clock** ([arena/](arena/FINDINGS.md)): `clk_pix` serves the Arena with large
  margin. CLEAR takes 8192 cycles, READ2 3 and COMMIT 2–4, against about
  1.39 M cycles per game tick; the 8192 × 4 Arena maps to one RAMB36E1.
- **Clocks** ([video/](video/FINDINGS.md)): 83.455882 MHz pixel clock;
  4.6875 MHz / 78126 gives 59.999 Hz `clk_juego` (−12.8 ppm). Frames and game
  ticks drift past each other about every 4.3 minutes.
- **`vga_out`** ([video/](video/FINDINGS.md)): Roman's registered outputs put the pins
  one cycle behind `curr_x`/`curr_y`. Fixed on 29 October to the handout's
  combinational outputs (Decision B); `vga_out_tb` and the independent
  `vga_out_check_tb` both pass. The cost is a long combinational path to the
  VGA pins (11.78 of 11.98 ns); Roman decides whether to keep it.
- **Contract gaps found**: CLEAR content of the HUD rows and padding;
  `score_unit` idle Lives (fixed to 03, as the model); `seg7_page` during Pause;
  `G_PREP`; the crossing; the Reward generator (the model's candidate LFSR is
  used, not yet selected).
