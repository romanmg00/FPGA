---
schema_version: 1
id: cs256-ta-email-game-clock-20261015
title: CS-256 TA Email - Game Clock
type: note
subject: CS-256
status: draft
created_at: "2026-10-15T17:30:00"
term: 2026-fall
sources:
  - "[[CS-256 Official FPGA Coding Practices]]"
  - "[[CS-256 VGA and Sprite Design Plan]]"
  - "[[CS-256 Tron Development Plan]]"
review_status: unreviewed
tags:
  - tron
  - fpga
---

# CS-256 TA Email - Game Clock

> [!warning] Superseded draft, 20 October 2026
> The team reported that the TAs recommended following the handout architecture strictly. The final game uses the divided approximately 60 Hz game clock under [[0002-follow-ta-divided-game-clock]]. The email below is retained as historical drafting; it is not a pending request to approve the frame-enable alternative.

Draft email to the TAs asking them to confirm the game-clock decision (pixel clock with a `frame_tick` enable instead of the handout's ~60 Hz divided clock). Send before the Tue 20 Oct meeting; the answer is needed by Tue 27 Oct, before W3 is planned. The earlier second TA question (pixel alignment with sprites) is no longer needed: the design now follows the sprite tips as written.

---

**Subject:** CS-256 class project: question about the game-logic clock (Drawing Logic Module, step 10)

Dear [TA name],

We are Alan Flores, Kevin Maldonado Dominguez and Roman Mandujano Gonzalez, and we are building a two-player Tron light-cycle game for the class project. Before we start on the game logic, we would like to check one design choice with you, because it differs from step 10 of the *Drawing Logic Module* section.

**What the handout asks**

Step 10 asks for a second clock divider plus a counter, giving a clock of about 60 Hz for the game logic in `game_top`.

**What we propose**

- We will build step 10 exactly as written for the lab exercise (the block moving ±4 pixels with the border check) and keep it as tested evidence.
- For the game itself, we would like to run all logic on the 83.46 MHz pixel clock. `vga_out` would output a one-cycle enable pulse, `frame_tick`, once per frame at the start of vertical blanking (59.998 Hz). Game state updates only on that pulse, so the update rate is the same as the handout's ~60 Hz clock; only the mechanism is different.

**Why**

Our game stores every light-cycle trail in a grid in block RAM (160 × 100 cells of 8 × 8 pixels). That is where a 60 Hz clock becomes a problem:

1. **Memory speed.** Moving both bikes one cell needs about 8 memory cycles: read the cell ahead of each bike (2-cycle BRAM latency), check it, write it. On a 60 Hz clock that is about 133 ms per move, so at most about 7 moves per second. Clearing the grid between rounds (32,768 writes) would take about 9 minutes. The memory logic therefore has to run on the fast clock anyway.
2. **Clock-domain crossings.** With two clocks, bike positions, crash results and memory commands must cross between the 60 Hz and 83.46 MHz domains, in both directions. A multi-bit value crossed without a proper synchronizer can be read half-updated, for example a bike drawn at a position that never existed. AMD's synchronizer macros are slow at 60 Hz: a 4-stage handshake takes about 67 ms by itself, and the pulse synchronizer needs about 33 ms between pulses, which is longer than one 16.7 ms period [4], [5].
3. **Vendor guidance.** AMD's design methodology guide (UG949) recommends clock enables over clocks gated or generated in logic, and advises avoiding locally routed clocks [1], [2], [3]. The 7-series clocking guide (UG472, Table 1-1, p. 25) marks driving a global clock buffer from general interconnect as "not recommended" [6].
4. **No tearing.** With the enable, the game state changes only during vertical blanking, so a frame is never drawn half from the old state and half from the new one. With a separate 60 Hz clock, updates can land in the middle of a frame.

With the enable, a move takes a few nanoseconds, clearing the grid (about 0.39 ms) fits inside one vertical blanking interval (about 0.56 ms), and the only synchronizers left are on the buttons and the UART input.

**Our questions**

1. What is the purpose of the 60 Hz clock in step 10? Is the requirement a separate clock signal, or that the game logic updates once per frame?
2. Is 60 Hz itself required? We plan to move the bikes once every K frames, with K tuned for playability, so the movement rate will be below 60 Hz.
3. Is a once-per-frame enable on the pixel clock an acceptable replacement for the divided clock in the game, given that step 10 is still built and tested for the lab exercise? Would it affect marking in the pre-demo or the report?
4. If a divided clock must appear in the game, would it be acceptable for it only to trigger moves, with the memory and game state on the pixel clock?

We would be grateful for an answer by Tuesday 27 October, when we plan this part of the design. We are happy to explain it in person if that is easier.

Kind regards,
Alan Flores, Kevin Maldonado Dominguez and Roman Mandujano Gonzalez
CS-256, Fall 2026

**References**

1. AMD, *UltraFast Design Methodology Guide for FPGAs and SoCs* (UG949), "Using Gated Clocks". https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Gated-Clocks
2. AMD, UG949, "Creating Clock Enables". https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Creating-Clock-Enables
3. AMD, UG949, "Avoiding Local Clocks". https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Avoiding-Local-Clocks
4. AMD, *Vivado Design Suite 7 Series FPGA and Zynq 7000 SoC Libraries Guide* (UG953), "XPM_CDC_HANDSHAKE". https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_HANDSHAKE
5. AMD, UG953, "XPM_CDC_PULSE". https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_PULSE
6. AMD, *7 Series FPGAs Clocking Resources User Guide* (UG472) v1.14, Table 1-1 (p. 25) and "Global Clock Buffers" (p. 36). https://docs.amd.com/api/khub/documents/1kFbRqzm2fhwGy~cLQG2yA/content
