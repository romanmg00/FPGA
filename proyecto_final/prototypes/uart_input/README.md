# UART input experiment (throwaway prototype)

This experiment answers whether a small 115200-baud 8N1 receiver and a portable,
ordered FIFO can implement the transport proposed in
[the research note](../../../docs/design/CS-256%20UART%20Input%20Path%20Research.md).
It is separate from `game_top` and does not settle the team's pending interface
or gameplay decisions. The existing Python viewers are unchanged.

The experiment uses a two-FF idle-high RX synchronizer, half-bit start
confirmation, eight LSB-first data samples, stop validation, and idle-high
recovery after a bad stop. A two-clock settling interval prevents synchronizer
reset values from rearming RX on a held-low wire. The decoder accepts W/A/S/D
in either case, Space,
and CR; LF is ignored. Prototype command values are UP=0, RIGHT=1, DOWN=2,
LEFT=3, START=4. They are local encodings, not new `game_pkg` constants.

A 64-entry Gray-pointer FIFO transfers one command per game clock. Its read
data and `rd_valid` are registered on an accepted read; a connected synchronous
consumer observes them at the following edge. Full rejects the newest write
and raises sticky overflow. There is no claim of loss-free unrestricted input.
Both clocks must run. Assert both synchronous resets together, holding each
across at least three edges of the slower clock. Release may be skewed; local
readiness plus synchronized peer readiness inhibits access until both domains
have left reset. Resetting only one domain during traffic is unsupported.

`uart_input_path.sv` is the transport. The board wrapper uses two Clocking
Wizards and a buffered counter-divided game clock, following ADR 0002. E3
feeds one shared IBUF, then the two Wizard inputs; no game logic uses it directly.
The build records achieved pixel frequency and recalculates
the UART divisor. The board wrapper deliberately has no gameplay state: LEDs
show commands and diagnostics. `led[2:0]` is the last dequeued command,
`led[3]` toggles per command, `led[4]` is sticky FIFO overflow, `led[5]` is
sticky framing error, `led[6]` is transport-ready, and `led[7]` indicates full.
The held reset/startup interval is at least five complete game-clock periods.
No TX, CTS, button debounce, or phase/epoch protocol is implemented.

## Run

With full Vivado on PATH:

```bash
bash proyecto_final/prototypes/uart_input/run.sh /tmp/cs256-uart-run
```

On Alan's installed Docker toolchain:

```bash
bash proyecto_final/prototypes/uart_input/run.sh --docker
```

The Docker command uses the existing container and a fresh `/builds/uart-*`
directory. It copies this prototype into that directory; it does not rebuild
the installation or modify the course repository. On the configured desktop it
uses the [approved unattended launcher](../../../tools/vivado/README.md), with
no password prompt. Use `--sim-only` after either invocation to omit routing.
The run saves XSim self-check logs/waves, IP catalog/interface reports, a Vivado
project, and (for the full run) routed timing/CDC/skew/DRC reports and a bitstream.
A failing bench or implementation command must make the runner fail.

**Verified status, 27 October 2026:** all four Icarus runs and all four XSim runs
pass. Vivado 2025.2 generated 83.455882 MHz and 59.999520 Hz clocks, routed the
wrapper, met setup/hold/pulse-width and both Gray-bus skew bounds, and produced
a bitstream with zero DRC/methodology findings. Native IP Catalog inspection is
complete. Five expected structural CDC warnings are documented in the findings;
this is not a physical-board or game-integration certification.

For the portable receiver/FIFO checks with Icarus 12:

```bash
bash proyecto_final/prototypes/uart_input/run_iverilog.sh /tmp/cs256-uart-icarus
python3 proyecto_final/prototypes/uart_input/analyze.py
```

The Icarus runner expects `iverilog`, `vvp`, and standard shell utilities. A
temporary unpacked installation can be selected with `UART_IVERILOG`,
`UART_IVL_BASE`, and `UART_VVP`. Its tests use 83,333,333 Hz as an experimental
clock value; this is **not** an observed Clocking Wizard result. Vivado's runner
instead recalculates the clock parameter from the IP it actually generates.
See [the findings](../../../docs/design/CS-256%20UART%20Input%20Prototype%20Findings.md)
for results, retained evidence and the remaining integration/board limits.

Open the generated `project/uart_input.xpr` with the same Vivado version. In
**IP Catalog**, search `uart`: inspect AXI UART Lite and AXI UART 16550. The
script also creates each IP and reads its elaborated IP-XACT bus interfaces,
so the report is based on the installed catalog rather than an online guess.
The `catalog` directory retains their `.xci`, XML, and instantiation templates.

## Experiment plan and limits

1. Test bytes, aliases, adjacent frames, independent transmitter timing at
   ±2% and ±3%, several start phases, false starts, stop errors, break, and
   reset interruption. A data glitch is deliberately demonstrated as a limit
   of single-sample reception.
2. Scoreboard accepted FIFO writes against reads through full, empty, wraps,
   randomized service and reset. Exercise delayed release of both domains.
3. Test complete serial-to-game delivery at an accelerated ratio and selected
   real ~83 MHz:60 Hz cases, including full/overflow and recovery.
4. Generate and inspect actual Clocking Wizard outputs and installed UART IP.
   Synthesize and route the board wrapper, then inspect CDC and timing coverage.

FIFO delay does not solve capture-versus-consumption eligibility. The experiment
does not certify Pause/Crash/Ready freshness or Step-edge arbitration. Those
need an agreed epoch/boundary protocol before integrating transport with the
game. P1 debounce/queues and physical browser/USB/board tests remain separate.
RTL simulation does not establish metastability MTBF. These are Alan's
experiment tests, not Roman's independent official module testbenches.
