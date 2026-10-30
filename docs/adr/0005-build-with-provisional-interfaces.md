---
title: Build the first HDL with provisional interfaces
status: proposed
created_at: "2026-10-28"
---

# Build the first HDL with provisional interfaces

On 28 October 2026 Alan asked for a working prototype to develop on, with
ADRs that can adapt to hardware and testing evidence. This proposes that the
team build functional SystemVerilog blocks and small integration experiments
before every engineering choice is settled, accepting temporary adapters and
some rework. Roman's agreement has not yet been recorded.

## What stays fixed

- Course requirements and TA instructions, including ADR 0002's divided
  game clock.
- The locked agreed specification, including the flexibility it already
  allows.
- Accepted ADRs keep their scope. Only unresolved choices named as working
  defaults are provisional.
- The owner split and independent verification. The reconciled contract owns
  selected shared interfaces.

## Working defaults

Each unresolved implementation choice gets a researched working default that
states what evidence would change it. Building against a default does not
establish timing, CDC safety or board behavior.

- Owner-local details, such as internal FSMs, registers and memory
  scheduling, change freely; note why beside the code or design note.
- For shared boundaries, such as ports, timing or handshake meaning, visible
  behavior and register ownership, record the change in the contract and
  notify both owners before changing code (§6). This proposal requires both
  owners' acknowledgement in an issue or PR, consistent with their shared
  responsibility under §7.
- Material architecture or rule changes need an ADR. Locked records are never
  edited.

When a working default changes, update the affected tests and the contract
or design record.

## The crossing stays open

ADR 0003 item 2 remains fully open. The Python mailbox stays as a replaceable
model mechanism; it selects no HDL protocol, ports, outstanding-command limit
or latency. HDL tests use a bridge with controllable delay until a crossing
candidate is chosen against the composed service and display schedule.

## Verify while building

ADR 0002's timing and CDC obligations remain; this ADR changes their order,
not their content. Its "reconcile before implementation" applies to treating
a shared interface as selected, not to isolated experiments or functional
blocks labelled provisional.

Evidence names what was run and its result: a scenario or simulation, routed
timing and CDC reports, or a repeatable board check. A passing Python model
alone does not prove a physical crossing. The 12 M2 scenarios and Step logs
compare model and HDL, with independent checks beside them. Review intentional
expectation changes; do not regenerate logs only to remove a difference.

## Consequences

HDL work can start before the crossing is selected. Evidence can replace a
working default without reopening unrelated decisions. Agreement and
verification stay separate: agreement does not prove hardware behavior, and a
passing experiment does not establish team agreement.
