---
schema_version: 1
id: cs256-uart-input-prototype-findings-20261027
title: CS-256 UART Input Prototype Findings
type: note
subject: CS-256
status: active
created_at: "2026-10-27T14:30:00+03:00"
updated_at: "2026-10-27T15:10:00+03:00"
term: 2026-fall
sources:
  - "[[CS-256 UART Input Path Research]]"
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[0002-follow-ta-divided-game-clock]]"
review_status: unreviewed
tags:
  - tron
  - uart
  - prototype
  - verification
---

# CS-256 UART Input Prototype Findings

Experiment date: **27 October 2026**. The throwaway SystemVerilog experiment is
in [`proyecto_final/prototypes/uart_input/`](../../proyecto_final/prototypes/uart_input/README.md).
It tests the proposed transport; it is not an accepted input-interface revision
or a completed game feature. The locked records and interface contract were not
changed. These are experiment tests, not Roman's official independent tests.

**Verified result:** all four Icarus runs and all four Vivado/XSim runs pass.
The Nexys A7 LED bring-up wrapper routes, meets its timing/skew constraints and
generates a bitstream. Native Vivado IP Catalog inspection is complete. The
approved unattended launcher works without a cached sudo password. Physical
board/browser testing and game eligibility integration remain unverified.

## Installed UART IP: qualified confirmation

**Observed installed files.** Vivado 2025.2's installed IP-XACT components at
`/home/alan/.local/share/cs256-vivado/tools/2025.2/Vivado/data/ip/xilinx/`
contain:

| Installed core | Register interface | Other exposed interfaces |
|---|---|---|
| `axi_uartlite_v2_0` | `S_AXI`, `xilinx.com:interface:aximm:1.0`, slave | Clock, reset, interrupt, UART |
| `axi_uart16550_v2_0` | `S_AXI`, `xilinx.com:interface:aximm:1.0`, slave | Clock, reset, interrupt, UART |

Both `component.xml` files explicitly contain `spirit:slave` with an `S_AXI`
memory-map reference. The actual Vivado 2025.2 IP Catalog was opened and searched
for `uart`; UART Lite and UART 16550 both display AXI interfaces, version 2.0
(Rev. 39). Their block-diagram symbols expose `S_AXI`. Screenshots of both
catalog selections and the interface diagram are retained in the
[evidence directory](../../prototipos/fpga/I2-uart-input-prototype/README.md). The search
also returned LTPI; the conclusion here specifically concerns the two inspected
UART cores. The batch flow also queried registered definitions for the target
part and exported their templates and metadata.

**Engineering inference.** The two inspected UART IPs require an AXI master to
read their RX registers. A custom RTL AXI master is sufficient; a processor is
not required. A small RX FSM fits the proposed byte/valid interface directly
and avoids that extra register-bus controller. Thus “a hand-written receiver is
likely” is supported as a project-fit judgment; “all AMD UARTs require a
processor” is not supported. This inspection does not exclude legacy UART6
reference macros or establish that no other UART exists in any distribution.

## Portable HDL observations

Icarus Verilog **12.0-3** was downloaded and unpacked into `/tmp`, without a
system installation. The test clock is **83,333,333 Hz**, with a simulated
12 ns period at 1 ps resolution. It is an experiment setting, **not a measured
or generated Wizard frequency**. The independent transmitter uses 115200 baud
and its specified offsets, rather than copying the RX integer counter.

| Check actually run | Observation |
|---|---|
| Receiver/decoder | PASS: 5,132 bytes, 211 recognized commands, 33 checkpoints; every byte at -3%, -2%, 0%, +2%, +3% transmitter-rate offsets, four initial phases each; back-to-back frames; aliases and unknown-byte rejection |
| Receiver faults | False-start rejection, invalid-stop suppression, break recovery and frame/reset interruption pass; one centered data-bit glitch changes `00` to `01`, demonstrating the single-sample receiver's noise limit |
| FIFO | PASS: 64 accepted before full, next 16 rejected, ordered drain; 6,212 accepted and 5,956 read across the complete randomized/reset experiment, with 256 intentionally discarded by four full-queue resets; 3,165 full writes rejected |
| Accelerated complete path | PASS: ordered commands and ignored bytes, full/overflow, ordered drain, reset recovery; first command's registered read latency was 382,631 ns at the accelerated ~10 kHz game clock |
| Real fast:60-Hz complete path | PASS: ordered commands, full/overflow and full-queue reset recovery; first command's registered read latency was 66,649,287 ns |
| Portable parser check | slang 12.1.0: zero errors, 20 numeric-conversion warnings in testbench stimulus/reference code; board syntax check has zero diagnostics. The later Vivado run separately elaborated and implemented the vendor clock/buffer modules. |

The FIFO test initially failed because this Icarus build evaluates
`$onehot0(a ^ b)` as zero for two zero-valued 7-bit variables, while both
`$onehot0(7'b0)` and `$onehot0(c)` for `c=a^b` return one. A small isolated
reproduction confirmed that discrepancy. The bench now checks zero-or-one-bit
changes using `delta & (delta - 1)` and rejects unknowns. The FIFO RTL did not
need to change for that failure.

The reset diagnostic count also exposed an RX startup bug: resetting the input
synchronizer high let the receiver rearm on that artificial high value while
the physical wire remained low. A focused `+reset_only` regression failed on
that behavior. A two-clock settling interval in the receiver's reset recovery
fixed it; the focused regression then passed with exactly one intended framing
error. **All four portable runs passed again after that change.** The complete
RX run also reported exactly one intended framing error.

The retained [portable logs and metadata](../../prototipos/fpga/I2-uart-input-prototype/README.md)
include the final receiver, FIFO, accelerated-path and real-ratio runs, tool
version, static installed-IP inspection and Python counterexamples. The complete
portable runner exited zero and wrote `All four Icarus runs passed.`

These tests establish digital behavior for the exercised cases only. They do
not establish routed pointer skew, metastability MTBF, analog noise immunity,
browser/USB behavior, or board operation.

## Analysis against the existing Python model

[`analyze.py`](../../proyecto_final/prototypes/uart_input/analyze.py) imports
the existing `prototipos/tron_fpga/model/` code rather than making another rules
implementation. That model remains a local implementation, not the selected
shared reference. Its 49 existing tests passed using the documented virtual
environment and dummy SDL audio/video drivers. The first system-Python run
failed to import `test_look_limits` because system Python lacked NumPy; the
documented environment resolved that dependency. An audio-enabled attempt
stalled and was interrupted; the dummy-driver run completed successfully.

After integrating PR #4's hardware-block model, `analyze.py` uses `InputBatch`,
`TurnUnit` and `BoardInputs`, and waits for the model's mailbox/phase transitions.
The counterexamples remain the same. The 49-test result and retained model-analysis
file above describe the earlier model snapshot; the script's current source hash
differs from the historical experiment manifest. No UART RTL changed for this adaptation.

- Heading RIGHT, requests UP then LEFT: preserving order retains UP; collapsing
  to the latest raw request retains RIGHT and loses the valid UP.
- A Start delivered during Crash is ignored and leaves the model waiting in
  Ready. Delaying that same event until Ready starts Play. The transport alone
  cannot enforce the fresh-Start rule across phase boundaries.
- At 115200 8N1, offered traffic can reach 11,520 commands/s. With a 60/s
  consumer, 64 entries fill in approximately **5.585 ms** in the idealized
  steady-service calculation. Servicing 64 queued commands takes approximately
  **1.067 seconds**, before initial flag/consumer latency.

The prototype preserves command order and reports dropped-newest overflow. It
does not implement capture-time phase/epoch metadata, ACK/credits, CTS, or P1
debounce/queues. It must not be integrated with the game under a claim of
loss-free or phase-correct delivery until those boundaries are agreed and
tested. Keep both transport clocks running during Pause.

## Vivado/XSim and routed implementation

Final run: `/builds/uart-20261027-150541-280860` in the existing Ubuntu container;
host output is
`/home/alan/.local/share/cs256-vivado/builds/uart-20261027-150541-280860`.
Vivado **2025.2, build 6299465**, part **xc7a100tcsg324-1**. This full run exited
zero and its prototype source snapshot matches `source-sha256.txt` in the retained
evidence. It is separate from the earlier failed build directories.

| Observation | Final result |
|---|---|
| Pixel Wizard | Requested 83.460 MHz; generated 83.45588235294117 MHz, assuming a nominal 100 MHz board oscillator |
| Receiver divisor | 724 clocks/bit; derived 115270.555736 baud, +0.061246% versus 115200 |
| Game Wizard/divider | 5 MHz, toggle every 41667 cycles: 59.99952000384 Hz |
| XSim | Four runs pass; logs confirm `clk_hz=83455882` and distinct `real_ratio=0` / `real_ratio=1` |
| RX/decoder | 5132 bytes, 211 recognized commands, 33 checkpoints, one intentional framing error |
| FIFO | Same randomized/full/reset scoreboard counts as Icarus |
| Complete-path latency | 382630 ns with accelerated game clock; 66649293 ns with nominal 60 Hz game clock, to registered read output; a synchronous consumer sees that output on its next edge |
| Routed setup / hold / pulse width | WNS **+7.344 ns**, WHS **+0.119 ns**, WPWS **+3.000 ns**; zero failing endpoints |
| Timing coverage | Zero unclocked register pins, unconstrained internal endpoints, multiple-clock pins or disconnected generated clocks |
| External timing exclusions | Two asynchronous inputs are false-pathed only to their first synchronizer stages; eight human-visible LED outputs have no synchronous external capture requirement |
| Gray-bus routing | Seven endpoints in each direction; actual skew **0.847 / 0.875 ns**, against **11.982 ns** bounds; positive slack in both directions |
| DRC / methodology | Zero findings in each final report |
| Resources | 100 LUTs, including four distributed-RAM LUTs; 156 FFs; FIFO inferred as one RAM64M, transformed into RAMD64E primitives |
| Bitstream | 3,825,917 bytes; SHA-256 `68d24330b6f2c59e1f1c7fe093c3129262ef2d5afe9eff437e17fc104db9d56f` |

These frequencies are generated-IP calculations, not measurements of board
oscillator tolerance. The testbench rounds time to 1 ps. Its real-ratio game
clock is nominal 60 Hz; the hardware divider's generated rate is the value
above. The board has not been programmed or physically tested.

### CDC review and constraints

`report_cdc -details` retains **two CDC-6 warnings** for the Gray buses and
**three CDC-15 warnings** for the FIFO payload. There are no critical findings;
these five structural warnings are documented, not waived or hidden:

- Each locally registered Gray pointer crosses two `ASYNC_REG` stages. The
  accepted-write/read scoreboard covers ordering and wrapping. Max-delay and
  bus-skew bounds apply to all seven physical bits in each direction. Synthesis
  merges the read Gray MSB into `rd_bin_reg[6]`; the script traces actual drivers
  instead of forcing a register count with `DONT_TOUCH`.
- Each memory payload bit is captured only on a read allowed by the locally
  registered empty flag, which uses the synchronized write pointer. Unread
  storage cannot be overwritten until the synchronized read pointer makes room.
  Its actual RAMD64E clock launch pin to read-register path is bounded by
  11.982 ns. This reasoning depends on coordinated reset, continuously running
  clocks and the FIFO protocol; it is not an arbitrary synchronized bus.

Following the Official FPGA Coding Practices note, no blanket asynchronous
clock-group exception is used. Both Wizards share one board IBUF and use
`No_buffer` inputs, eliminating duplicate input buffers and clock definitions.
The game clock is defined **once at BUFG/O**, derived from the divider register's
C pin. This keeps its Q-to-D divider feedback in the 5 MHz data domain. The
counter-divided game clock remains the accepted architecture.

The first build exposed unsupported XDC `for`, ignored parameters because the
requested simulation set was not active, and synthesized pointer aliasing.
Focused Vivado probes reproduced those cases. The final runner activates each
simulation set and checks the values printed by the actual bench. Constraints
use registered **cells**, avoiding Q-pin path segmentation. Its completion gate
requires passing timing, seven real skew endpoints on each bus, and no critical
methodology findings; a bitstream alone cannot satisfy it.

The reset/locked-disabled Wizard configuration follows the handout. The reset
hold interval does not establish lock-aware recovery from clock loss. Physical
MTBF, browser/USB behavior, and unrestricted loss-free input are not certified.

## Reproduce without interactive authentication

The user-approved fixed-container launcher is installed and verified. Fresh
`sudo -n -k` calls work as UID/GID 1000 with `NoNewPrivs: 1`; in-container
privilege escalation is denied. The one-use administrator credential was
removed. See [the toolchain instructions](../../tools/vivado/README.md) for
operation and revocation. General Docker daemon access was not granted.

```bash
bash proyecto_final/prototypes/uart_input/run.sh --docker
```

It creates a fresh output directory and retains logs on failure. The original
Vivado project, bitstream and checkpoints stay outside Git; compact reports,
test output, source hashes, IP GUI screenshots and a machine-readable summary
are in the evidence directory. The GUI inspection used an isolated Xvfb display;
both Vivado GUI and that display were closed afterward.
