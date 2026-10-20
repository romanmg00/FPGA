---
schema_version: 1
id: cs256-official-fpga-coding-practices-20261015
title: CS-256 Official FPGA Coding Practices
type: note
subject: CS-256
status: active
created_at: "2026-10-15T15:34:02"
updated_at: "2026-10-20T14:53:11"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
  - "[[CS-256 VGA and Sprite Design Plan]]"
  - "[[CS-256 Tron Glossary]]"
  - "[[CS-256 Tron Game Mechanics]]"
review_status: unreviewed
tags:
  - fpga
  - systemverilog
  - vga
  - tron
---

# CS-256 Official FPGA Coding Practices

**Current baseline (confirmed 2026-10-20, [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md)):** follow the TAs’ strict handout instruction: the final game uses a second Clocking Wizard plus counter divider to produce an approximately 60 Hz **game-state clock**. ADR 0001's pixel-clock/frame-enable proposal is superseded. Output-aligned `curr_x`/`curr_y` and early sprite reads follow the [sprite tips](../cs256-fall-2026/classproject/sprites/README.md). The old clock-path comparison is retained below as history, not as a live choice.

Research checked on **2026-10-15**. Paragraphs marked **AMD guidance** describe vendor documentation. **Project application** identifies our engineering interpretation. Manufacturer guidance supports implementation choices; it does not establish course acceptance or prove this game works.

The 20 October documentation pass checked consistency with the locked agreement. It did not independently revalidate every vendor-source claim; the note's source-review status remains unchanged.

## Sources behind the historical pixel-clock proposal

The [superseded clock ADR](docs/adr/0001-pixel-clock-with-frame-enable.md) contains claim-level citations. The following map preserves that proposal’s reasoning; it does not override the selected divided-clock baseline in ADR 0002:

| Conclusion | Supporting reference | What comes from the source, and what we conclude |
|---|---|---|
| Use a synchronous enable to control updates | [UG949: Using Gated Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Gated-Clocks), [Creating Clock Enables](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Creating-Clock-Enables) | AMD recommends enables instead of HDL clock gating and describes their inference. Selecting `pixclk` for this game's controller is our application. |
| Avoid an unnecessary fabric-derived game clock | [UG949: Avoiding Local Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Avoiding-Local-Clocks) | AMD identifies counter-divided local clocks and their skew/routing challenges. This does not ban every divided clock. |
| Sharing `pixclk` simplifies the game/render boundary | [UG949: Limiting Synchronous Clock Domain Crossing Paths](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Limiting-Synchronous-Clock-Domain-Crossing-Paths) | AMD recommends limiting these crossings. Removing our extra game domain removes its crossings; external-input synchronization remains necessary. |
| The controller needs enough fast cycles between game updates | [PG058 v8.4, read latency and Summary](https://docs.amd.com/v/u/en-US/pg058-blk-mem-gen), [course sprite tips](../cs256-fall-2026/classproject/sprites/README.md) | The sources establish synchronous/configurable memory latency. The estimated 8-cycle Step and its execution times are project assumptions/calculations. |
| A full handshake through a 60 Hz source has a throughput cost | [UG953: XPM_CDC_HANDSHAKE](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_HANDSHAKE) | The macro specifies full acknowledgement/rearm and source synchronization stages. Millisecond estimates follow from our 60 Hz source assumption; other transfer designs differ. |
| The update rate can remain about 60 Hz while the controller uses the pixel clock | [Course raster and clock settings](../cs256-fall-2026/classproject/README.md), [UG949: Creating Clock Enables](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Creating-Clock-Enables) | The course supplies the timing; the enable supplies conditional state updates. `83.46 MHz / (1680 × 828) ≈ 59.998 Hz` and the K-frame Step cadence are project arithmetic/design. |

**Scope of the conclusion:** AMD does not specify “83.46 MHz rather than 60 Hz” for this project. The superseded proposal chose a fast common clock for controller execution and a slow enable cadence for launching Steps. Completing the whole transaction inside blanking remains a simulation requirement, not a consequence guaranteed by the enable alone.

## Target and source scope

Target: **Digilent Nexys A7-100T**, **Artix-7 XC7A100T-1CSG324C**, Vivado part **`xc7a100tcsg324-1`**. Digilent identifies the 100T as functionally identical to the Nexys 4 DDR named in the handout. Its oscillator is 100 MHz on E3. VGA uses RGB444, two sync signals and a resistor-divider DAC for a 75 Ω termination and approximately 0–0.7 V. The manual's 640 × 480 example does not certify the course's 1280 × 800 timing. [Digilent manual, revised 2019-07-10, physical pp. 6, 13, 18–21](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf), [official board definition](https://raw.githubusercontent.com/Digilent/vivado-boards/master/new/board_files/nexys-a7-100t/D.0/1.3/board.xml).

This investigation uses AMD's 7-series architecture guides **UG472 v1.14** and **UG473 v1.14**, **PG058 v8.4 (2021-08-06)** for Block Memory Generator, and linked Vivado methodology/library pages. Most online pages are 2026.1; explicitly versioned older pages are identified where used. Match the shared workstation's Vivado/IP version before adopting options or templates. Keep the [project toolchain policy](README.md).

## Game clock and Decision A

### Distinguish three different circuits

| Circuit | Meaning | Manufacturer guidance and project treatment |
|---|---|---|
| Fabric clock gating | A LUT computes something such as `clk & enable` and drives clock pins | AMD advises against this HDL pattern and recommends inferring register enables. An enable transition can alter the clock waveform. Do not use it for either path. |
| Registered clock division | A counter clocks a flip-flop whose output changes at a lower rate and drives a clock distribution resource | This is the handout path. It creates a generated clock and requires routing, waveform and crossing analysis. It is different from an AND gate on the clock. |
| Register clock enable | Registers use `posedge pixclk`; a synchronous condition controls which state updates occur | This is the superseded game proposal in ADR 0001; ADR 0002 selects the divided-clock architecture. The event is data/control, not a clock. A game FSM can execute at pixel-clock speed after an update starts. |

**AMD guidance:** UG949 recommends clock enables instead of HDL clock gating and generally avoiding fabric-routed local clocks. UG472 permits general interconnect as a BUFG input, but its connectivity table labels that route **not recommended**. Thus a divider flip-flop feeding a BUFG is device-supported, while retaining a fabric segment before the buffer; it is not equivalent to an all-dedicated MMCM clock path. [UG949: Using Gated Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Gated-Clocks), [Avoiding Local Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Avoiding-Local-Clocks), [UG472, Table 1-1 p. 25 and Global Clock Buffers p. 36](https://docs.amd.com/api/khub/documents/1kFbRqzm2fhwGy~cLQG2yA/content).

### Path A — selected handout divided-clock implementation

**Project application:** retain `100 MHz → second Clocking Wizard → divider counter → registered game-clock output → clock buffer → game logic`. Use a registered output rather than a combinational terminal-count decode as the clock. Inspect the implemented BUFG and its loads; a signal named `game_clk` does not establish its routing. Keep the clock running during a game pause; pause game state rather than placing an AND gate in the clock path.

For a symmetric clock that toggles every `N` input cycles:

$$f_{game}=\frac{f_{divider\ input}}{2N}.$$

Choose `N` from the Wizard's **achieved** frequency and record the resulting rate. The counter has to count `0…N-1`; handle `N=1` when deriving a width with `$clog2`. This equation and the width rule are our arithmetic/RTL deductions. A one-cycle terminal-count pulse has a different duty cycle and must not be constrained as the symmetric toggle waveform.

**AMD guidance:** define generated clocks from their masters. UG903's divider example attaches the generated clock to the divider register's Q and uses its clock pin as one valid `-source`. MMCM/PLL output clocks are normally auto-derived after defining the input clock. [UG903: Simple Division by 2](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Example-One-Simple-Division-by-2), [Automatically Derived Clocks](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Automatically-Derived-Clocks).

For the symmetric-toggle circuit only, this is a **constraint template**, not a ready-to-run project XDC. `u_game_div` and `game_clk_reg` are illustrative names, and `DIVIDE_RATIO` must equal the actual `2N`:

```tcl
create_generated_clock -name game_clk \
    -source [get_pins u_game_div/game_clk_reg/C] \
    -divide_by $DIVIDE_RATIO \
    [get_pins u_game_div/game_clk_reg/Q]
```

Check each query resolves to exactly one intended pin in the synthesized netlist. Do not create an unrelated primary clock on the divider output or define duplicate clocks at both Q and BUFG/O. Verify propagation, period, waveform and clock ancestry in the reports.

### Path B — historical pixel-clock-enable alternative

**AMD guidance:** an edge-triggered block with a condition that retains the old register value describes enable behavior. Enables can affect control sets, so they are not resource-free. [UG949: Creating Clock Enables](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Creating-Clock-Enables).

**Historical rationale from superseded ADR 0001:** AMD recommends enables rather than HDL clock gating, warns about fabric-routed counter clocks, and recommends reducing synchronous crossings. The former proposal applied those principles to one `pixclk` for game/controller/render logic and a frame-rate enable for launching work. This was a project-specific proposal, not AMD's prescription and not the accepted clock architecture. [Using Gated Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Gated-Clocks), [Avoiding Local Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Avoiding-Local-Clocks), [Limiting Synchronous Clock Domain Crossing Paths](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Limiting-Synchronous-Clock-Domain-Crossing-Paths).

> **Historical project proposal, superseded by ADR 0002:** clock game logic, renderer and memory controllers with `pixclk`. A one-cycle `frame_tick` or counter enable would decide when to launch a Step, while the memory FSM advances on each `pixclk` edge. This path is not the selected build architecture.

A frame-derived enable gives approximately 59.998 Hz with the handout timing; a separate synchronous counter enable can target a different update rate. State changes must be scheduled or snapshotted coherently; one shared clock alone does not ensure a consistent frame. ADR 0001 proposed this path, but ADR 0002 supersedes it after the TAs’ strict-architecture instruction. Path A is selected for the final game; Path B is historical material.

## Clock-domain transfers for Path A

### Establish the actual relationship first

**AMD guidance:** predictable-phase clocks can be timed synchronously. However, clocks from the same primary oscillator can be **unexpandable**: Vivado cannot establish a common period within 1,000 cycles and may report slack that does not cover the true worst case. AMD says to treat those crossings like asynchronous ones. [UG903: Synchronous Clocks](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Synchronous-Clocks), [Unexpandable Clocks](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Unexpandable-Clocks).

**Project application:** inspect the actual pixel Wizard, game Wizard and divider clocks. Use direct timed transfers only when the relationship and both setup/hold directions are covered. Otherwise use a deliberate CDC interface. Neither “same 100 MHz input” nor “different frequencies” settles this classification.

### Transfer complete state and account for throughput

**AMD guidance:** `XPM_CDC_HANDSHAKE` transfers a bus with a full receive/acknowledge/rearm sequence before another transfer starts. Its source synchronizer defaults to four stages. [UG953: XPM_CDC_HANDSHAKE](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_HANDSHAKE).

**Project application:** a full handshake with a 60 Hz source spends several 16.67 ms source cycles returning acknowledgement and rearming. Four return synchronization stages alone represent roughly 66.7 ms of clock periods, before allowing for the whole protocol. Do not assume that interface can publish a new state every game tick. Simulate actual latency and backpressure. Reducing synchronizer stages is not a substitute for a throughput design.

| Transfer option | Appropriate use | Required evidence |
|---|---|---|
| Direct related-clock registers | The clocks are safely timed together | Covered setup/hold paths in both directions, coherent capture and no blanket false paths |
| Full handshake bus | Updates are infrequent enough to await complete acknowledgement | Source holds payload for the documented protocol; measured round-trip rate meets demand |
| Asynchronous FIFO | A command/snapshot stream needs buffering between clocks | Width/depth, sustained service rate, full/empty handling, reset-busy handling and loss-free backpressure |

**AMD guidance:** `XPM_FIFO_ASYNC` writes on eligible write-clock edges and reads on eligible read-clock edges. Flag/data latency depends on configuration, and access must be inhibited during reset/busy. This can decouple transfers without a per-word full handshake. [UG953 2024.2: XPM_FIFO_ASYNC](https://docs.amd.com/r/2024.2-English/ug953-vivado-7series-libraries/XPM_FIFO_ASYNC).

**Engineering guidance:** if a measured producer rate and crossing classification require buffering, evaluate a FIFO and size it for pending commands, synchronization delays and the longest renderer/controller stall. A FIFO does not solve an average consumer rate lower than the producer rate. Keep grid commands ordered; only coalesce display snapshots if discarding intermediate snapshots is an explicitly acceptable behavior. The target transfer protocol remains unselected.

For isolated events, do not assume a pulse synchronizer has unlimited rate. `XPM_CDC_PULSE` requires a gap of at least `2 × max(source period, destination period)` from the current source pulse's falling edge to the next source pulse's rising edge. With a 60 Hz domain, that gap is about **33.3 ms**; a new event every 16.7 ms is outside this macro contract. Match the installed macro's contract to the actual event rate. [UG953: XPM_CDC_PULSE](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_PULSE).

Pack each render update coherently: both Bike positions/Headings and any mutually dependent visible state. Independently synchronizing bits can produce a combination that never existed. A transferred state can first enter pending registers, then become the active render snapshot in vertical blanking. That extra frame-commit policy is our proposed way to keep sprite state stable across prefetch and display; it is not mandated by AMD or yet implemented.

### Timing exceptions follow the interface

**AMD guidance:** `set_clock_groups` has higher priority than path exceptions and cannot be overridden by a later `set_max_delay`. [UG903: Exceptions Priority](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Exceptions-Priority), [Constraining Asynchronous Signals](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Constraining-Asynchronous-Signals).

**Project application:** do not mark every game/render path asynchronous just to remove timing failures. Preserve the constraints delivered with XPM/IP, and check their interaction with top-level exceptions. If a CDC structure requires a bounded datapath, a broad clock-group exception may defeat it. Verify the implemented endpoints and report ignored/overridden exceptions. False paths do not add synchronization hardware.

## Pixel alignment and Decision B

### Selected early-read pipeline

**AMD guidance:** Block Memory Generator reports each port's total read latency in its Summary; optional registers/pipeline stages change that latency. Memory enables and register enables also control advancement. Keep the course's **Single Port ROM** configuration and inspect its actual generated settings. [PG058 v8.4, Summary Tab p. 88 and output-flow control pp. 53–58](https://docs.amd.com/v/u/en-US/pg058-blk-mem-gen).

**Project application:** leave the handout's sync, visible flag and current coordinates unchanged. Issue sprite addresses early, using the configured end-to-end read lead. For latency `L`, conceptually advance the complete raster by `L` pixels, not merely the visible `x` coordinate. For `0≤L<1680`:

```text
sum_h = hcount + L
prefetch_h = sum_h if sum_h < 1680 else sum_h - 1680
prefetch_v = vcount if sum_h < 1680 else (vcount + 1) modulo 828
prefetch_visible = 336 <= prefetch_h <= 1615 and 27 <= prefetch_v <= 826
```

Use conditional wrap in RTL rather than assuming a general divider/modulo circuit is necessary. This is project pseudocode, not vendor code. Qualify future sprite bounds before truncating offsets to the ROM address. Compose the returned data using the corresponding **current** sprite mask and `curr_x`/`curr_y`.

| Current raster, `L=2` | Future raster | Future visible pixel |
|---|---|---|
| `h=334, v=27` | `h=336, v=27` | First pixel `(0,0)`; fetch begins in the porch |
| `h=1613, v=826` | `h=1615, v=826` | Last pixel `(1279,799)` |
| `h=1679, v=826` | `h=1, v=827` | Blanking after line wrap |
| `h=1679, v=827` | `h=1, v=0` | Blanking after frame wrap |

These calculations were checked in Python against the handout numbers. They do **not** establish an HDL edge convention: verify which edge accepts an address, when data appears after nonblocking updates, and how that matches the current counter state in the generated IP simulation model. An off-by-one error can survive a plausible diagram.

Keep ROMs always enabled as in the sprite tips initially. If reads are later gated, preserve every required internal advance; enabling only while the **current** sprite is visible can omit the first prefetched texels. A final RGB register, registered address calculation or other new stage changes the total early-read lead. Balance separate sprite/trail paths against the same output pixel. No new stage is free merely because the BRAM itself reports two cycles.

### Historical delayed-stream pipeline

**AMD guidance:** the rest of a design must account for added pipeline latency. [UG949: Pipelining Considerations](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Pipelining-Considerations).

**Historical alternative:** issue reads from request coordinates and delay sync/visible plus the matching pixel metadata until data is ready. Its request coordinates must be named separately from output coordinates. It can preserve the external video waveform's periods and relative alignment, but changes the handout's internal interface unless output-aligned `curr_x`/`curr_y` are retained. This sketch is separate from the clock choice: **clock enable does not require delayed sync**, and either clock path could technically be paired with either pipeline. The handout-aligned early-read pipeline remains selected.

## Arena memory and reset

**Selected project encoding:** use the 8192 × 4-bit Arena, 13-bit `{cy[5:0], cx[6:0]}` address and cell codes recorded in [[CS-256 Tron Agreed Specification 2026-10-20#Clocks, Arena encoding and service boundary]]. These are team choices, not AMD-prescribed. Synchronize them in the shared headless model and HDL package; the local implementation still needs migration from its incompatible three-bit table.

**Selected service architecture (Q28 clarified by Q32):** retain approximately 60 Hz game-state logic and fast video/memory service. The fast controller is the Arena write owner, executing validated game commands and returning results. Define coherent request/result payloads and render snapshots, occupancy revalidation for delayed Reward placement, reset/pause behavior during a transaction, and measured service/round-trip bounds. Do not infer those guarantees merely from dual-port memory or a common clock on its ports.

**AMD guidance:** UG473's BRAM **common-clock** collision rules require both ports to be driven by the same clock-buffer driver. Other CLKA/CLKB connections use the independent-clock rules. Two reads succeed; conflicting writes are nondeterministic; read-during-write results depend on the documented configuration. [UG473 v1.14, Conflict Avoidance, pp. 19–20](https://docs.amd.com/api/khub/documents/9gZGbqBxtlKXxBfkBt~lAg/content).

**Possible implementation option, not selected:** keep both grid ports on `pixclk`, with a fast controller servicing slow-game-clock commands through a defined transfer interface. This may simplify port arbitration, but it does not settle the port clocks or CDC design. Compare the actual clock-buffer drivers and apply the matching common-clock or independent-clock collision restrictions; dual-port BRAM alone is not a CDC protocol.

Use one defined write owner. Check both Bikes' candidate Cells before committing either Trail; handle same-Cell simultaneous Crashes in logic. These are game rules, not a BRAM write mode. During blanking, either disable rendering reads or give them harmless addresses and ignore the returned invalid/irrelevant pixels; blank RGB alone does not stop the RAM access. Do not depend on an unspecified read-during-write value.

**AMD guidance:** BRAM output reset does not clear the stored array, and a misplaced array reset can turn an inferred BRAM into many registers. Keep collision checking enabled in suitable simulation models; the 7-series RAMB36E1 documentation warns that disabling it can mask problems. [UG473, Set/Reset](https://docs.amd.com/api/khub/documents/9gZGbqBxtlKXxBfkBt~lAg/content), [UG949: Resets](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Resets), [UG953 2023.2: RAMB36E1](https://docs.amd.com/r/2023.2-English/ug953-vivado-7series-libraries/RAMB36E1).

**Project arithmetic:** clearing a power-of-two-padded grid with one write per pixel-clock cycle has the following lower bounds at 83.46 MHz. This assumes a full padded allocation, not just valid Arena Cells:

| Cell side | Visible grid | Padded allocation | Clear time |
|---|---|---|---|
| 16 px | 80 × 50 | 128 × 64 = 8,192 words | 98.2 µs |
| 8 px | 160 × 100 | 256 × 128 = 32,768 words | 392.6 µs |
| 4 px | 320 × 200 | 512 × 256 = 131,072 words | 1,570.5 µs |

The 28 complete blank lines provide 47,040 cycles, about **563.6 µs**. The selected **16 px** padded clear has an idealized **98.2 µs** lower bound. The older 8 px estimate is 392.6 µs; a full 4 px clear cannot fit that blanking interval at one write per cycle. Controller overhead, Walls/Rewards and competing operations still need a measured budget. During a multi-frame clear, keep gameplay/render validity in a defined state; do not promise immediate reset of the Arena array.

## RTL, inputs and startup

**AMD guidance:** Vivado supports `always_ff` and `always_comb`, and reports unintended latches often caused by incomplete branches. AMD recommends specifying initialization for synchronous elements; this becomes configuration state and reduces resets used solely for power-up initialization. [UG901: Always Procedures](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Always-Procedures), [Latches](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Latches), [UG949: Initialization](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Initialization-of-All-Inferred-Registers-SRLs-and-Memories).

**Project coding rules:** give each state register one owner; use nonblocking sequential updates and complete combinational defaults. Separate current/next state. Size counters, coordinates and intermediate subtraction explicitly; test bounds before interpreting a truncated offset. Keep `drawcon` combinational as required. Put memory/register stages outside it, with their latency reflected in prefetch timing. Avoid new whole-array resets or broad `DONT_TOUCH` attributes to force an expected resource count; inspect synthesis instead.

**AMD guidance:** a single-bit synchronizer needs the input stable long enough for multiple destination samples; it is not an event queue. [UG953 2022.2: XPM_CDC_SINGLE](https://docs.amd.com/r/2022.2-English/ug953-vivado-7series-libraries/XPM_CDC_SINGLE).

**Project application:** synchronize buttons/switches into a suitable fast input domain, then debounce buttons and generate events. UART RX also needs a fast receiver domain; do not try to sample serial bits on the 60 Hz game clock. Transfer decoded controls coherently to the game domain using the selected interface. Choose and test a debounce interval; AMD's clock-domain macro does not specify one for these switches. Do not feed an asynchronous reset switch into a clock gate.

The course's initial Clocking Wizard instructions uncheck reset/locked. Preserve that baseline and distinguish it from AMD's stronger startup guidance: synchronized `LOCKED`-aware control and reset handling are documented for robust clock startup. Explicit register initial values do not prove safe operation while an MMCM is settling or recovering from clock loss. Record this limitation and evaluate added startup control as a separate extension, rather than silently changing the lab steps. [UG949: Using Clock Modifying Blocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Clock-Modifying-Blocks-MMCM-and-PLL), [Controlling and Synchronizing Device Startup](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Controlling-and-Synchronizing-Device-Startup).

## Assets, pins and reproducible builds

**AMD guidance:** COE memory data uses the initialization radix/vector keywords and a terminating semicolon; COE/MIF files are associated IP sources. Preserve generated IP output-product structure for simulation and implementation. [UG896: COE File Syntax](https://docs.amd.com/r/en-US/ug896-vivado-ip/COE-File-Syntax), [Files Associated with IP](https://docs.amd.com/r/en-US/ug896-vivado-ip/Files-Associated-with-IP), [UG892: Generating IP Output Products](https://docs.amd.com/r/en-US/ug892-vivado-design-flows-overview/Generating-IP-Output-Products).

**Project application:** retain sprite PNG, converter, COE, IP customization and generated build evidence together. For a 32 × 32 RGB444 sprite, validate exactly 1,024 words, values within `000…FFF`, row order and the transparency/tint conventions in the plan. A COE syntax pass does not prove the image is oriented correctly or that an old IP build used the new file. Record hashes, regenerate affected products and simulate representative texels.

Use Digilent's per-pin package and voltage constraints. Clock E3 is LVCMOS33 with a 10 ns primary period; SW8/SW9 are LVCMOS18. UART pin names use the PC perspective: C4 is the FPGA receive input. Enable only used ports and rename them to the actual top-level names. [Digilent master XDC](https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Nexys-A7-100T-Master.xdc), [manual §6, physical p. 14](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf#page=14).

A package-pin assignment is not an external timing budget. AMD's output-delay constraints describe an external launch/capture relationship, with appropriate min/max values. Do not invent a monitor setup/hold specification or silence unconstrained VGA outputs with arbitrary numbers. Document the chosen video-output timing model, inspect paths through the final compositor to RGB/sync pins, and test the actual monitor. A purely combinational RGB path is not proven glitch-free just because the raster counters are registered. [UG903: Use of set_output_delay](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Use-of-set_output_delay-Command-Options).

## Implementation and verification evidence

**AMD guidance:** `report_cdc` checks synchronization structures, whereas clock interaction/timing reports address clock relationships and slack. Neither substitutes for the other. Clock-utilization reports expose clock buffers/routing and loads. Timing signoff uses the routed design. [UG906: CDC Terminology](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Terminology), [Report Clock Domain Crossings](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Clock-Domain-Crossings), [Report Clock Utilization](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Clock-Utilization), [Report Timing Summary](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Timing-Summary).

Run the applicable commands in the shared Vivado version, on the appropriate synthesized/routed checkpoint:

```tcl
report_clocks
report_clock_networks
report_clock_utilization
report_clock_interaction
report_cdc
check_timing
report_exceptions
report_methodology
report_drc
report_utilization -hierarchical
report_timing_summary -delay_type min_max -report_unconstrained
```

Our acceptance evidence should include:

- Exact part, Vivado/IP versions, achieved frequencies, clock topology and generated-clock coverage. No unexplained clock-routing or timing warnings.
- Setup/hold and pulse-width results; documented exceptions and external I/O coverage. No broad exception used to hide an unimplemented transfer.
- Transfer throughput, payload stability, sequence/order, reset behavior, overflow/underflow and worst-case stalls. For async macros, enable supported usage assertions in simulation.
- Sprite/trail read latencies and edge convention; first/last visible pixel, porch prefetch, line/frame wrap, all sprite rotations and state-update boundaries. Decode frame dumps from external syncs.
- Bounded memory operations and full Arena-clear timing; two simultaneous Bike moves checked against [[CS-256 Tron Agreed Specification 2026-10-20]].
- On-board monitor lock, controls and repeated reset/pause operation. Timing closure and a functional simulation are different evidence.

## Historical comparison of both clock paths

This comparison was written while the game-clock choice was open. ADR 0002 has since selected the divided game-state clock under the TAs’ strict handout instruction; the table records provenance and does not leave a live selection task. Reconsidering the clock architecture requires the team to formally reopen the accepted decision and follow any course/TA direction.

| Criterion | Path A — divided game clock, selected final game | Path B — historical pixel-clock-enable proposal |
|---|---|---|
| Course match | Directly follows the second-divider instruction | Needs teaching-staff acceptance if substituted for that instruction |
| Clock resources | Extra Wizard/divider and slow-clock distribution | Game uses the existing pixel-clock distribution |
| State transfer | Must time or synchronize coherent game/render data | No game/render clock crossing; external inputs still need synchronization |
| Memory controller | Fast service domain plus a defined game interface | Controller can share `pixclk` with game state |
| Update timing | Slow-clock events are not inherently aligned to blanking | A frame-enable event can align launch to blanking |
| Performance/power | Slow game-state clocking may reduce activity; extra clock resources also consume power | Enables can suppress state activity; fast clock distribution remains active |
| Main verification burden | Generated clocks, crossing classification, throughput and coherency | Enable cadence, FSM continuation and same-domain arbitration |
| Evidence needed | Routed timing/clock/CDC reports and transfer stress tests | Routed timing/control-set reports and frame-update stress tests |

Do not infer a power/resource winner from the historical table. The delayed-stream pipeline remains a separate historical alternative to the selected handout-aligned early-read pipeline; it is not an outstanding project decision.

No IP generation, HDL simulation, synthesis, routed implementation, power comparison or board test was performed for this research. Python arithmetic checks establish only the stated timing/grid calculations. Actual interface choice, divider factor, FIFO depth and output timing budget remain implementation decisions supported by the evidence above.
