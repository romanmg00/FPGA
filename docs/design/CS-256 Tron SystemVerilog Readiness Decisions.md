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

[ADR 0003](../adr/0003-step-transaction-mailbox-and-render-codes.md) records
Roman's selected READ2/COMMIT, mailbox, fast-clock, Crash-code, shown-Heading
and prototype directions. Its remaining choices are **proposed pending Alan's confirmation**;
the shared-model base was separately accepted in [ADR 0004](../adr/0004-shared-headless-model-base.md).
The interview must account for that recorded position rather than treating
Roman's position as unknown. The mailbox's two-tick timing remains a model
assumption and design target, subject to the stated evidence gate.

## Appearance integration evidence

On 28 October, commit `443555e` brought the previously reviewed synthwave
startup change (`9a8a1f6`) onto `docs/systemverilog-readiness` and was pushed
to origin before these documentation corrections. The full Python suite
passed **72 tests**, including the scenario replays. A dummy-SDL smoke check
rendered startup, running synthwave and core frames and exercised Start,
preset/HUD changes, reset and clean exit through the desktop loop. Native
sprite sizes, 16 px Cells, 64 px HUD band, six-tick cadence and absence of
budget flags were checked. These are PC-model/viewer results, not hardware
verification. The integration changed no model, scenarios, preserved PR2
files or existing documentation under `docs/`.

## Decision tree

The initial round separates an outstanding model choice from staging already
settled by the specification. Later questions depend on answers and research;
do not silently settle them.

- Q1, confirmed: adopt `prototipos/tron_fpga/model/` as the shared rules-model
  base for both viewers and SystemVerilog verification, retaining the freedom
  to revise unverified hardware timing assumptions. See ADR 0004. Adapting
  the other viewer remains implementation work.
  - Then establish which model behavior is normative and which timing details
    remain proposals that may change with hardware evidence.
- Q2, settled by existing authority: implement the agreed core first, then the
  HUD and visual extras, as specified in the locked specification's Scope and
  tentative schedule section. The PC synthwave default does not revise FPGA
  scope. Reopen this only if the user explicitly requests a staging change.
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

Alan confirmed Q1 on 28 October 2026: this headless model is the shared base;
unverified hardware timing assumptions may change. Other interface questions
remain open. The user also requested welcome and pause screens before further
HDL design. These are desktop-viewer additions driven by existing model state,
not a new Start press, countdown, game phase, or accepted FPGA screen design.
Their text is desktop playtest text only: it names PC keys (Enter, Space, P,
WASD, arrows) and the desktop's swapped Player keys. It must not be copied into
the HDL. Board screen text, if any, still needs to be designed against the
agreed controls: BTNC or UART Space/Enter for Start, SW0 for Pause, board
direction buttons for P1 and UART WASD for P2.

Also on 28 October, Alan asked that the ADRs give a working prototype to
develop on and adapt to hardware and testing evidence, rather than act as
strict gates. He kept ADR 0003 item 2, the crossing, fully open, and asked for
research on the other ADR 0003 items instead of a vote. Three research notes
followed: [Step transaction and displayed Heading](CS-256%20Step%20Transaction%20and%20Displayed%20Heading%20Research.md),
[fast clock](CS-256%20Fast%20Clock%20Domain%20Research.md) and
[Crash code and Start while busy](CS-256%20Crash%20Code%20and%20Start%20While%20Busy%20Research.md).
Their recommendations are recorded in ADR 0003 as proposed working defaults,
and the workflow in the proposed [ADR 0005](../adr/0005-build-with-provisional-interfaces.md).
Roman's agreement to both has not been recorded. How the display gets a
consistent view of the Arena remains undecided; the board video prototype in
`proyecto_final/` does not yet include Arena memory.

The user did
authorize appearance integration, verification and push, followed by the ADR
wording corrections and resumption of the interview. That work authorization
does not accept ADR 0003 or its proposed hardware choices. Record design answers
here as they arrive and distinguish individual positions from team acceptance.

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
readiness. Production HDL implementation remains outside this interview. The
user separately authorized committing and pushing the appearance integration
before the documentation corrections and further interview questions.
