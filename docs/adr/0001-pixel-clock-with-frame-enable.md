---
status: superseded by ADR-0002
---

# Game logic runs on the pixel clock with a frame enable, not on a divided clock

> [!warning] Superseded on 20 October 2026
> The team confirmed that the TAs instructed it to follow the handout architecture strictly. The final game uses the divided approximately 60 Hz game clock. See [[0002-follow-ta-divided-game-clock]]. The reasoning below is historical research, not the active build decision or a pending TA-approval request.

The handout (*Drawing Logic Module* step 10) asks for a second clock divider giving a ~60 Hz game clock. We build that step literally for the lab exercise (milestone V4: the ±4 moving block), but the Tron game itself runs all logic, including the UART receiver, on `pixclk` (83.46 MHz) and starts each update with a one-cycle `frame_tick` enable at the start of vertical blanking (59.998 Hz); Steps happen every K ticks. Decided 2026-10-15, pending TA confirmation (status becomes `accepted` once they agree; see [[CS-256 TA Email - Game Clock]]).

**Why.** We choose `pixclk` for the game and memory controller while retaining a frame-rate update cadence. The source-backed reasoning is:

- **Clock enables and routing.** AMD recommends coding clock enables instead of HDL clock gating, describes how a synchronous conditional infers an enable, and advises avoiding local clocks, including counter-divided clocks routed in ordinary fabric.[^amd-gating][^amd-enables][^amd-local] This supports the clock-enable implementation; it is not a blanket prohibition on properly implemented divided clocks.
- **Fewer internal clock crossings.** AMD recommends limiting synchronous clock-domain crossing paths even when their skew is acceptable.[^amd-crossings] Running the game, memory controller and renderer on the same `pixclk` removes the crossings between those blocks. External buttons and UART RX still need synchronization. This is our application of the guidance, not an AMD prescription for this game.
- **Memory-cycle budget.** The current controller estimate is about 8 cycles per Step; that count is an unverified project estimate, not a vendor specification. At 60 Hz, `8 / 60 ≈ 133 ms` (at most about 7.5 Steps/s), and `32,768 / 60 ≈ 546 s` (9.1 minutes) to clear one word per cycle. At 83.46 MHz, the same idealized operations take about 95.9 ns and 392.6 µs. The generated BRAM configuration determines the actual read latency and the controller determines the final cycle count.[^amd-memory] A fast controller is needed for the intended rates; a divided-clock request interface remains possible, but adds transfer work.
- **Handshake latency.** AMD's full bus-handshake macro must finish acknowledging and rearming before the next transfer; its default source synchronizer has four stages.[^amd-handshake] With a 60 Hz source, four source-clock periods are about 66.7 ms, before accounting for the rest of the protocol. This is a configuration-specific throughput concern, not the cost of every possible crossing.
- **Blanking budget.** The handout timing gives `28 × 1680 / 83.46 MHz ≈ 563.6 µs` for 28 complete blank lines.[^course-timing] The idealized 392.6 µs clear fits that budget before controller overhead. A frame enable can start work in blanking, but a consistent frame still requires the update to finish before active rendering resumes. That completion bound needs simulation.

Here, using the full pixel clock does **not** mean moving the Bikes 83.46 million times per second. `frame_tick` and the K-frame cadence decide when to start a Step; its read/wait/check/write FSM then advances on successive `pixclk` edges until complete. AMD does not explicitly say “use 83.46 MHz instead of 60 Hz”; that is our design conclusion from the guidance, timing calculations and game requirements above. The detailed source discussion and both alternatives remain in [[CS-256 Official FPGA Coding Practices]].

## Considered Options

- **Divided game clock for everything (handout as written).** Rejected for the game for the reasons above; it stays in V4.
- **Divided clock that only issues Step requests into the pixel domain.** Nominally keeps a game clock, but the logic is the same as the enable plus a crossing; kept only as a fallback if the TAs require a divided clock in the game.

## Consequences

- Objective X1 (game → render transfer) is dropped; X2 reduces to input synchronizers.
- If the TAs reject this, revert before W3 (Tue 27 Oct) and design X1 so that the fast controller executes the whole Step.
- Sprite reads still start early with output-aligned `curr_x`/`curr_y` (VGA plan Decision B is unchanged).

## References

Official sources checked on 2026-10-15. The linked UG949/UG953 online pages are 2026.1; PG058 is v8.4 (2021-08-06). Check options against the team's installed Vivado/IP version. No simulation or implementation result is implied by these citations.

[^amd-gating]: AMD, *UltraFast Design Methodology Guide for FPGAs and SoCs* (UG949), [Using Gated Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Gated-Clocks): recommends inferring clock enables instead of coding clock gating into the clock path.
[^amd-enables]: AMD, UG949, [Creating Clock Enables](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Creating-Clock-Enables): explains synchronous conditional enable inference and control-set tradeoffs.
[^amd-local]: AMD, UG949, [Avoiding Local Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Avoiding-Local-Clocks): identifies fabric counter division as a source of local clocks and describes skew/routing concerns.
[^amd-crossings]: AMD, UG949, [Limiting Synchronous Clock Domain Crossing Paths](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Limiting-Synchronous-Clock-Domain-Crossing-Paths): recommends limiting these paths even when skew is acceptable.
[^amd-memory]: AMD, [Block Memory Generator Product Guide (PG058), v8.4](https://docs.amd.com/v/u/en-US/pg058-blk-mem-gen), Summary Tab p. 88 and output register/pipeline discussion pp. 53–58. The core's read latency must be taken from its actual configuration; the estimated 8-cycle Step is our controller assumption.
[^amd-handshake]: AMD, *Vivado Design Suite 7 Series FPGA and Zynq 7000 SoC Libraries Guide* (UG953), [XPM_CDC_HANDSHAKE](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_HANDSHAKE): full-handshake protocol and `SRC_SYNC_FF` configuration. The millisecond values above are our calculations for a 60 Hz source.
[^course-timing]: Course [class project README](../../../cs256-fall-2026/classproject/README.md), VGA Sync Signals, Outputing Pixels and Creating the Clock; [sprite tips](../../../cs256-fall-2026/classproject/sprites/README.md), Potential timing issues. The raster budget and clear-time comparison are our arithmetic from those inputs.
