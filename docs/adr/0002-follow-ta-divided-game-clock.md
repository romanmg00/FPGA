---
schema_version: 1
id: cs256-adr-0002-divided-game-clock-20261020
title: CS-256 Follow the TA Divided Game Clock Architecture
type: note
subject: CS-256
status: accepted
created_at: "2026-10-20T13:31:31"
sources:
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
  - "[[CS-256/cs256-fall-2026/classproject/README]]"
review_status: unreviewed
---

# Follow the TA divided game clock architecture

On 20 October 2026 the team confirmed that its TAs recommended following the course handout's architecture strictly. The final Tron game therefore uses the **second Clocking Wizard plus counter divider to produce an approximately 60 Hz game clock**, with game-state logic clocked by that clock, as in Drawing Logic Module steps 10–12. This supersedes [[0001-pixel-clock-with-frame-enable]]; the pixel-clock/frame-enable engine is retained only as historical research, not a pending alternative for this build.

## Consequences

- Pixel generation and sprite ROM reads still use the requested **83.46 MHz pixel clock**. Follow the handout's output-aligned coordinates, combinational drawing baseline and sprite guide's latency-aware early reads.
- Restore **X1**, the game/render state and Arena command/result interface. Q28/Q32 explicitly confirm a **fast memory service for the slow game-state domain**, alongside fast video. The exact service clock, coherent transfers, update scheduling and handshake throughput must be designed and tested; the architectural choice alone does not settle them.
- A slow game clock is not a once-per-frame enable on a pixel-clocked game engine. Do not silently replace one with the other or move the complete game engine into the pixel domain behind a trigger.
- A divided game clock is not inherently aligned with vertical blanking. Coherent game-state snapshots, BRAM access and input-event transfer need explicit timing/CDC treatment. Multi-cycle bulk memory work must have a demonstrated feasible schedule; Q32 approves the service boundary, not a specific handshake/FIFO circuit or a proven throughput bound.
- Reconcile the team repository's single-clock contract and old local Path B notes before implementation. The course repository remains reference-only. This decision changes documentation; no HDL or prototype behavior is claimed to have changed or been verified.
