---
title: CS-256 Tron SystemVerilog Readiness Decisions
status: draft
created_at: "2026-10-28"
decision_status: open
---

# CS-256 Tron SystemVerilog Readiness Decisions

Working interview record requested by Alan on 28 October 2026, before creating
the game's SystemVerilog blocks. This note records questions and proposals;
it does not establish team agreement or authorize HDL implementation.
All FPGA modules and testbenches use `.sv`.

## Authority and evidence

Follow [the documentation authority path](../README.md), the locked
[agreed specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md),
and accepted [ADR 0002](../adr/0002-follow-ta-divided-game-clock.md).
The [model hardware map](CS-256%20Tron%20Game%20Model%20Hardware%20Map.md)
describes the current Python implementation and its proposed interfaces.
The [team interface contract](../../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md)
still marks several interfaces as pending. Existing model behavior is evidence,
not acceptance of those interfaces. Never edit `docs/decisions/`.

The [readiness research](CS-256%20Tron%20SystemVerilog%20Readiness%20Research.md)
is now available. It reports 57 model tests and 4 scenario tests passing, with
source-fetch limits and document versions stated. It does not include new
Vivado builds, physical board tests, or measured X1/game service timing.

The parent checked the research against the current mailbox and game-edge
implementation: Python executes the fast service after a game edge and captures
its response at later simulated edges. That ordering does not prove physical
bus stability, synchronizer safety, or a feasible hardware handshake schedule.
Keep the research's bridge, input, rendering and placement recommendations as
proposals until the user selects their semantics and the relevant experiments
provide evidence.

## Decision tree

The first round contains independent scope choices. Later questions depend on
these answers and on the primary-source research; do not silently settle them.

- Q1, open: adopt `prototipos/tron_fpga/model/` as the shared rules-model base,
  with both PC viewers consuming it, or select another base.
  - Then establish which model behavior is normative and which timing details
    remain proposals that may change with hardware evidence.
- Q2, open: first HDL milestone implements the agreed core, with HUD and
  synthwave extras staged later, or includes specified visual extras from the
  start. The agreed final core scope remains unchanged.
  - Then define the required render inputs, sprite assets, and milestone checks.
- Research prerequisite, open: assess slow/fast command and response transfer,
  input transfer, reset/Pause handling, and service bounds.
  - Then choose transaction fields, handshakes, register ownership, latency
    expectations, and the circumstances under which a Step may wait.
- Research prerequisite, open: assess Arena/video coherence with independent
  game and pixel clocks and real BRAM/ROM latency.
  - Then choose snapshot publication and memory-update policy together.
- Research prerequisite, open: assess PRNG/seed capture and Reward-search
  scheduling against the agreed continuing-play requirement.
  - Then choose the exact sequence, replacement order and candidate validation.
- After the above: settle preparation state, Crash encoding, UART Start
  encoding/buffering, module ports, and model/HDL comparison criteria.

## Confirmed answers

None yet. Record the user's answers here as they arrive. Distinguish Alan's
chosen direction from team acceptance; do not infer Roman's agreement.

## Evidence needed after the interview

Documentation can settle intended behavior and candidate interfaces. Freezing
cross-domain ports also requires evidence for the composed clock/handshake,
memory-service and display-publication schedule. The research proposes isolated
experiments for those boundaries. No such experiment or production HDL block
has been created in this interview. If the selected direction needs an
experiment before a final interface decision, make that dependency explicit.

## Completion criteria

Close the decision frontier with the user, then obtain confirmation of the
shared design. Record material architectural choices in ADR 0003 onward and
reconcile the implementation contract. Keep any remaining proposal explicit.
Define independent `.sv` testbenches, model/HDL scenario comparisons, and
timing/CDC/DRC and board checks. Python tests alone cannot establish FPGA
readiness. No HDL implementation or Git commit is part of this interview.
