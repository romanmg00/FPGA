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
review_status: unreviewed
---

# Step transaction, mailbox crossing and render codes

On 27 October 2026 Roman reviewed the interface choices in [[CS-256 Tron Game Model Hardware Map#Choices the model makes (proposals)]] (PR #4) and accepted the items below. **Status: proposed** until Alan confirms them; then set `status: accepted` and record the outcome in the interface contract.

## Decisions

1. **Step transaction (review D2-A).** A Step reads both target Cells (READ2), resolves the outcome in the game clock domain with a combinational `step_resolve`, then writes the result (COMMIT). Both targets are read before either is written, so the Bikes move simultaneously and Head-on Crashes (same Cell or swap) are detected without priority.
2. **Mailbox crossing (review D3-A, as adjusted in the Hardware Map).** The game and fast domains exchange commands and responses through a stable-payload mailbox: one command outstanding, a `seq` number per command, and every fast-to-slow bus captured once in the game domain. A payload is never changed while the other domain may read it. The resulting latency is 2 game ticks per command and 2 ticks for inputs, so the shortest Step is 4 ticks; the agreed 6 leaves 2 ticks of slack.
3. **Fast clock is `clk_pix`.** The Arena BRAM (both ports), `arena_ctrl` and the fast side of the mailbox run on `clk_pix` (review §5.2). `drawcon` reads Arena port B with no further clock crossing.
4. **Crash code 6 is written (review E6).** COMMIT writes code 6 at a crashed Bike's last valid head Cell. This reverses the model's current choice (Hardware Map, "Crash code 6"); the model, `params.py` and the scenario logs must be updated to match.
5. **Displayed Heading (review §5.7).** Sprites show the Heading of the last committed Step, so a Bike's sprite turns when it moves, not when the Turn is pressed.
6. **Prototype folders.** `prototipos/tron/fpga/` may stay; Alan's `prototipos/tron_fpga/` is the prototype the team will use going forward.

## Left open

- `G_PREP` (Hardware Map, decision 2): Alan's Round/Match area.
- LFSR, seed capture and placement schedule (E1).
- Start behaviour while the mailbox is busy.
- Render coherence when Arena writes land mid-frame while the sprite snapshot changes in vertical blanking ([[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]], item 2).
- Who writes the official `cmd_mailbox` testbench (the Hardware Map assigns it to Roman).

## Consequences

- Roman's `turn_unit` and `step_unit` follow the READ2/COMMIT sequence and edge timing in [[CS-256 Tron Game Model Hardware Map#Tick timing]].
- `drawcon` draws the Crash from Arena code 6 and the blink from the render snapshot.
- The review's adoption limit 1 still applies to D3: the mailbox is not yet backed by HDL, routed timing or CDC evidence. The team accepted it without a separate prototype gate; the first integration build must check its timing and CDC reports.
- Update the contract: fix the fast clock to `clk_pix` (§1), and add the mailbox, Step transaction and crash-code rules (§4, §6).
