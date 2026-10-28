---
schema_version: 1
id: cs256-adr-0003-step-transaction-mailbox-20261027
title: CS-256 Step Transaction, Mailbox Crossing and Render Codes
type: note
subject: CS-256
status: proposed
created_at: "2026-10-27T12:00:00"
sources:
  - "[[0002-follow-ta-divided-game-clock]]"
  - "[[CS-256 Tron Game Model Hardware Map]]"
  - "[[CS-256 Tron Opus 5.5 Architecture and Integration Review]]"
  - "[[CS-256 Tron SystemVerilog Readiness Research]]"
review_status: unreviewed
---

# Step transaction, mailbox crossing and render codes

On 27 October 2026 Roman reviewed the interface choices in [[CS-256 Tron Game Model Hardware Map#Choices the model makes (proposals)]] (PR #4) and accepted the items below. **Status: proposed** until Alan confirms the remaining choices; then record the accepted scope in the interface contract. Item 6 was separately confirmed on 28 October in [ADR 0004](0004-shared-headless-model-base.md); that confirmation does not accept the remaining items.

## Proposed decisions

1. **Step transaction (review D2-A).** A Step reads both target Cells (READ2), resolves the outcome in the game clock domain with a combinational `step_resolve`, then writes the result (COMMIT). Both targets are read before either is written, so the Bikes move simultaneously and Head-on Crashes (same Cell or swap) are detected without priority.
2. **Mailbox crossing (review D3-A, as adjusted in the Hardware Map).** The proposed game/fast-domain interface uses a stable-payload mailbox with one command outstanding and a `seq` number per command. The current Python model captures every fast-to-slow bus once and assumes 2 game ticks per command and 2 ticks for inputs; under those assumptions, its shortest Step is 4 ticks. These are model timings and hardware design targets, not established CDC safety or measured hardware latency. A held payload and a single capture register alone do not prove a safe transfer. The physical protocol must establish coherent capture, payload hold times, reset recovery and rearming; its composed service and render-publication schedule must sustain the agreed 6-tick Step cadence. Any slack must be derived from that evidence.
3. **Fast clock is `clk_pix`.** The Arena BRAM (both ports), `arena_ctrl` and the fast side of the mailbox run on `clk_pix` (review §5.2). `drawcon` reads Arena port B with no further clock crossing.
4. **Crash code 6 is written (review E6).** COMMIT writes code 6 at a crashed Bike's last valid head Cell. This reverses the model's current choice (Hardware Map, "Crash code 6"); the model, `params.py` and the scenario logs must be updated to match.
5. **Displayed Heading (review §5.7).** Sprites show the Heading of the last committed Step, so a Bike's sprite turns when it moves, not when the Turn is pressed.
6. **Prototype folders — accepted separately in ADR 0004.** `prototipos/tron/fpga/` stays preserved; `prototipos/tron_fpga/model/` is the selected shared rules-model base. Viewer adapters remain to be completed.

## Left open

- `G_PREP` (Hardware Map, decision 2): Alan's Round/Match area.
- LFSR, seed capture and placement schedule (E1).
- Start behaviour while the mailbox is busy.
- Render coherence when Arena writes land mid-frame while the sprite snapshot changes in vertical blanking ([[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]], item 2).
- Who writes the official `cmd_mailbox` testbench (the Hardware Map assigns it to Roman).

## Consequences

- If adopted, Roman's `turn_unit` and `step_unit` preserve the READ2/COMMIT sequence. The edge timing in [[CS-256 Tron Game Model Hardware Map#Tick timing]] remains the model reference and a candidate hardware target until the complete hardware schedule is demonstrated.
- If adopted, `drawcon` draws the Crash from Arena code 6 and the blink from the render snapshot. The current model has not yet been changed to write code 6.
- The review's adoption limit 1 still applies to D3: the mailbox is not yet backed by HDL, routed timing or CDC evidence. Roman's selected direction remains proposed pending Alan's confirmation; this note records no team-approved waiver of the separate prototype gate. Select the physical protocol and freeze crossing ports only after an isolated implementation demonstrates safe behavior and the agreed cadence, including reset, Pause, rearming and coherent publication. Integration must also check timing and CDC reports.
- After confirmation, update the contract: fix the fast clock to `clk_pix` (§1), and add the selected mailbox, Step transaction and crash-code rules (§4, §6), retaining explicit status and evidence requirements for unresolved details.
