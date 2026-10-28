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
  - "[[0005-build-with-provisional-interfaces]]"
  - "[[CS-256 Tron Game Model Hardware Map]]"
  - "[[CS-256 Tron Opus 5.5 Architecture and Integration Review]]"
  - "[[CS-256 Tron SystemVerilog Readiness Research]]"
  - "[[CS-256 Step Transaction and Displayed Heading Research]]"
  - "[[CS-256 Fast Clock Domain Research]]"
  - "[[CS-256 Crash Code and Start While Busy Research]]"
review_status: unreviewed
---

# Step transaction, mailbox crossing and render codes

On 27 October 2026 Roman reviewed the interface choices in [[CS-256 Tron Game Model Hardware Map#Choices the model makes (proposals)]] (PR #4) and accepted items 1–6 below. Item 6 was confirmed separately in [ADR 0004](0004-shared-headless-model-base.md).

On 28 October Alan asked for the technical items to be researched rather than decided by vote, and for the ADRs to give a working prototype that adapts to hardware and testing evidence. He kept item 2 fully open. Three research notes followed, and the workflow is proposed in [ADR 0005](0005-build-with-provisional-interfaces.md). The items below are therefore **proposed working defaults**: build against them, and change them when the evidence named for each says so. Item 7 and the Crash orientation in item 5 come from that research, not from Roman's 27 October review. Roman's agreement to recording the items this way has not yet been recorded.

## Working defaults

1. **Step transaction.** A Step reads both target Cells (READ2), resolves the outcome in the game clock domain with a combinational `step_resolve`, then writes the result (COMMIT). Both targets are read before either is written, so the Bikes move simultaneously and Head-on Crashes (same Cell or swap) need no priority. The resolver does not depend on the crossing; HDL tests drive it through a bridge with controllable delay.
   *Change if* a phase-swept service test shows that READ2 and COMMIT cannot finish and rearm within the agreed 6-tick Step. First improve the scheduling; then try one atomic Step in the fast domain that keeps the same resolver and game-domain scoring. Player priority is never the fix. Research: [[CS-256 Step Transaction and Displayed Heading Research#Item 1 — Step transaction]].
2. **Mailbox crossing: fully open.** No protocol, port set, capture scheme, outstanding-command limit or response latency is selected. The Python model's stable-payload mailbox (one command outstanding, a `seq` number per command, 2 game ticks per command and for inputs, so a shortest Step of 4 ticks) stays as a replaceable model mechanism. These are model timings, not CDC safety or measured latency. Choose a crossing against the composed service and display schedule; it must sustain the agreed 6-tick Step, including reset, Pause, rearming and coherent publication.
3. **Fast clock is `clk_pix`.** Both Arena BRAM ports, `arena_ctrl` (clear, READ2, COMMIT and Reward search) and the fast side of the crossing run on the same buffered `clk_pix` net. UART receive, button debounce and the 7-segment scan use it too. `drawcon` reads port B with no further clock crossing. Service work has large margin at this clock: the worst Round preparation fits about 35 times into one game tick.
   *Change if* a representative routed design fails timing in service logic after the FSM is staged or the BRAM output is registered. Then move port A to a slower Clocking Wizard output and keep port B on `clk_pix`; this costs dual-clock BRAM collision rules and another crossing. Research: [[CS-256 Fast Clock Domain Research#Working default]].
4. **Crash code 6 is written.** COMMIT writes code 6 at each crashed Bike's last valid head Cell, and code 6 counts as occupied. The Player's colour and the blink come from the render snapshot, by matching the crashed head Cell, not from the code. In the model this keeps all 12 Step logs identical and changes three test expectations; the PC viewer must also draw code-6 Cells.
   *Change if* renderer tests show that code 6 adds avoidable identity or coherence complexity. Reverting is cheap: remove the write and restore the three expectations. Research: [[CS-256 Crash Code and Start While Busy Research#A. Crash code in COMMIT]].
5. **Displayed Heading.** A sprite shows the resolved Step's Heading together with that Step's resulting head Cell, published as one pair. It does not turn on a Pending Turn or at launch; the control Heading still updates at launch. A crashed Bike shows the Heading it attempted, at its last valid Cell, as the model does now.
   *Change if* board playtests show that the delay of up to one Step confuses Players. Research: [[CS-256 Step Transaction and Displayed Heading Research#Item 5 — Displayed Heading]].
6. **Prototype folders: accepted separately in ADR 0004.** `prototipos/tron/fpga/` stays preserved; `prototipos/tron_fpga/model/` is the selected shared rules-model base. Viewer adapters remain to be completed.
7. **Start while the mailbox is busy.** Hold one pending Start that arrived while Start was eligible, until the mailbox is idle, within the same eligible wait. The first Start wins and keeps its seed tick and Points Goal. Pause, reset, consumption or leaving the wait clears it. A Start during the Crash display is never held. With the model's 2-tick timing no Start is lost today; the pending Start covers longer hardware latencies.
   *Change if* measured timing shows that no eligible Start can arrive while the mailbox is busy, and the extra state complicates verification; removing it is cheap. Research: [[CS-256 Crash Code and Start While Busy Research#B. Start while the mailbox is busy]].

## Left open

- Item 2, the crossing.
- How the display gets a consistent view of the Arena when Arena writes land mid-frame while the sprite snapshot changes in vertical blanking ([[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]], item 2). **Undecided.** Starting points: the board video prototype in `proyecto_final/` (`clk_wiz_0`, `vga_out` and a switch-driven `drawcon`, without Arena memory yet), and the candidate in [[CS-256 Official FPGA Coding Practices#Transfer complete state and account for throughput]], where pending registers become the active render snapshot in vertical blanking. That candidate is proposed, not implemented.
- What the display shows when Pause arrives between a Step's outcome and its publication. The research's working reading is to publish the already-resolved Step without advancing another; decide it together with render publication.
- `G_PREP` (Hardware Map, decision 2): Alan's Round/Match area.
- LFSR, seed capture and placement schedule (E1).
- Use of the Clocking Wizard's `locked` and `reset` ports. The course handout disables them; using them for lock-loss recovery needs TA confirmation.
- Who writes the official `cmd_mailbox` testbench (the Hardware Map assigns it to Roman).

## Consequences

- Roman's `turn_unit` and `step_unit` keep the READ2/COMMIT sequence. The resolver and scoring can be built and tested now against a delayed bridge.
- The model does not yet follow defaults 4 and 7. Following them means writing code 6 in COMMIT, updating the `params.py` comment, the three test expectations and the PC viewer, and adding the pending Start.
- The edge timing in [[CS-256 Tron Game Model Hardware Map#Tick timing]] is the current model timing. The HDL may differ with evidence, reviewed through the Step logs and independent checks.
- No HDL, routed timing, CDC or board result backs these defaults yet; the review's adoption limits still describe the evidence a selected crossing needs. When a default becomes a selected shared interface, record it in the contract (fast clock in §1; Step transaction and crash code in §4 and §6) after both owners agree, as ADR 0005 proposes.
