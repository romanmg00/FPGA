---
title: P2's keys over UART, with Enter as CR and one command in flight at a time
status: proposed
created_at: "2026-11-23"
---

# P2's keys over UART, with Enter as CR and one command in flight at a time

> Proposed by Alan on 23 November 2026, who chose the crossing on 17 November.
> Waiting for Roman's acceptance, because it departs from a line of the
> specification.

The [Agreed Specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md)
says P2 steers with W A S D from a browser page over the USB-UART at 115200
baud, 8N1, that Space and Enter are Start for either Player, and that "the
controller/decoder wire encoding for Enter remains a documented implementation
task". It also says: "Preserve ordered keyboard/UART requests." The
[UART research](../design/CS-256%20UART%20Input%20Path%20Research.md)
proposed an ordered asynchronous FIFO from `clk_pix` to `clk_juego` for that.

## Decision

- **One byte per key.** The page (`proyecto_final/web/p2_controller.html`)
  sends `w`, `a`, `s`, `d`, Space (`0x20`) and Enter as **one CR byte
  (`0x0D`)**, and no byte for a key's auto-repeat. `uart_decode` also accepts
  W A S D in upper case. Every other byte, LF included, is ignored, so a
  terminal that sends CR LF for Enter gives one Start.
- **Receiver on `clk_pix`.** `uart_rx` counts 724 cycles of `clk_pix` per bit
  (83,455,882 / 115,200 = 724.4) and reads each bit once, in its middle.
- **One command in flight.** `uart_link` carries a command to `clk_juego` with
  a toggle and an answer, like `arena_link`: `cmd_tgl` crosses through
  `sync_2ff`, `clk_juego` copies the command and flips `ack_tgl` back. Until
  the answer reaches `clk_pix`, 2 to 3 ticks after the command (up to 50 ms), a
  new command is **dropped**.
- **Two ticks on `clk_juego`.** Each command reaches `position_logic`
  (`turn_req2`) and `match_fsm` (Start, OR-ed with BTNC) for 2 ticks.
  `bike_move` ignores a Turn in the tick of a Step, and Steps are never in
  consecutive ticks, so one of the two ticks always counts. A Start counts once,
  on its rising edge, as BTNC does.

This supersedes only "Preserve ordered keyboard/UART requests", for P2's UART
input: the commands that go through keep their order, but a command sent less
than about 50 ms after the previous one can be lost. The locked records are not
edited.

## Why it is enough

A Bike takes at most one Turn per Step, 8 ticks (133 ms, ADR 0010), and a
Turn is judged against the Heading at that moment, so a second key within
50 ms of the first would only replace the Pending Turn. A person playing does
not press two keys that close on purpose. The page sends no auto-repeats.

## Options considered

| Option | Why not |
|---|---|
| Ordered asynchronous FIFO (Gray pointers, the research's proposal; tested in `proyecto_final/prototypes/uart_input/`) | Keeps every command, but adds a 64-entry memory, two Gray pointer buses with their own constraints and a reset protocol for both domains. More to verify and to explain at the demo, for key presses a person cannot produce |
| FIFO Generator or `xpm_fifo_async` IP | Same behaviour as the FIFO, but vendor CDC blocks with their own reset rules and a separate simulation model |
| AXI UART Lite or UART 16550 IP | They need an AXI master to read their registers, and still leave the crossing to `clk_juego` |
| Keep the latest command and overwrite it while one is in flight | Avoids the drop, but the second key can overwrite a Start, and the receiving side can read a command while it changes |
| **One command in flight; a new one is dropped** (chosen) | Loses a second key within 50 ms |

## Consequences

- `uart_rx`, `uart_decode` and `uart_link` are in `proyecto_final/src/`, wired
  in `game_top` section 2. `uart_link`'s two toggles and the command bits have
  `set_max_delay -datapath_only` of one `clk_pix` period in
  `game_top_timing.xdc`, and `build_game_top.tcl` counts every bit they must
  cover.
- The contract's open item "Código de Enter en la UART y el búfer de eventos"
  is answered here; Roman updates the contract.
- Testbenches: `uart_rx_tb` (all bytes, ±2 % and ±3 % baud, glitches,
  framing errors, break, reset), `uart_decode_tb` (all 256 bytes),
  `uart_link_tb` (order, 2 ticks, drops, reset, real clock ratio) and
  `game_top_tb`'s `uart` scenario (Enter starts a Round, W and D turn P2 from
  the pin, a reversal is ignored).
- The shared model's input batch (`prototipos/tron_fpga/model/input_batch.py`)
  keeps the last key on each axis in each tick and never drops a key for
  following another, so a scenario with two P2 keys less than 3 ticks apart can
  differ from the HDL.
