---
title: Configure the Step interval from hardware timing and playtesting
status: accepted
created_at: "2026-10-29"
---

# Configure the Step interval from hardware timing and playtesting

> Numbered 0006 when it was written on branch `t3/basic-systemverilog-blocks`. Renumbered 0007 on 12 November 2026, because main's ADR 0006 is the one-Wizard decision.

On 29 October 2026 Alan accepted relaxing the six-tick movement cadence so
the game can accommodate a verified crossing and memory-service schedule.
This records his instruction in the project discussion; Roman's separate
acknowledgement has not been recorded. Acceptance of this timing policy does
not select a crossing or establish hardware verification.

## Decision

Bikes advance one Cell at a fixed, configurable interval measured in ticks
of the approximately 60 Hz game clock. Initially evaluate **eight to ten
game ticks per Step** (approximately 7.5 to 6 Cells/s). Select the final
interval through hardware timing verification and playtesting. Approximately
10 Cells/s remains a desirable target where feasible, rather than a mandatory
six-tick deadline.

The interval is a development configuration and stays fixed during running
play. Service completion does not trigger an immediate next move. A faster
setting, including six ticks, needs evidence that the complete transaction
and channel rearming sustain that cadence with appropriate scheduling margin
and acceptable input response. Eight to ten ticks is the initial evaluation
range, not a claim that either endpoint has already been validated.

This supersedes only the fixed six-tick / approximately 10 Cells/s requirement
in the locked specification's **Movement, Turns and Crashes** section, and
six-tick selection gates in ADR 0003 items 1 and 2 and derived design notes.
The locked records remain unchanged. Use the selected interval when judging
whether READ2 + COMMIT fits, before considering a change of transaction or
register ownership.

## Rationale and boundaries

A conservative qualified READ2 + COMMIT schedule is estimated at eight game
ticks; ten ticks could leave two additional ticks. These are scheduling
estimates, not guarantees or CDC sign-off. Relaxing the movement cadence lets
the team prefer explicit capture and processing stages over optimizing every
edge solely to fit six ticks. The trade-off is slower movement and a longer
wait before a Pending Turn takes effect, which need playtesting.

ADR 0002's separate divided game clock remains in force. VGA timing, Cell
size, simultaneous movement, collision rules, scoring and input eligibility
are unchanged. This decision neither moves collision computation to the
fast domain nor adopts the atomic fast-service Step fallback. CDC coherence,
metastability handling, reset, Pause and display publication still require
their own verified design.

If exceptional delay exceeds the selected interval, do not overlap an
unfinished transaction or consume an unqualified response to meet a movement
deadline. Defer the launch and expose the deadline miss for verification;
routine service-dependent movement timing is not the selected behavior.

## Implementation and verification consequences

This ADR changes documentation only. Existing model and HDL defaults still
use six ticks. When implementing the selected interval, reconcile the shared
contract, model configuration, HDL parameters and timing expectations. Review
intentional Step-log changes explicitly rather than regenerating logs only
to hide differences.

Verify sustained launch cadence, complete service and acknowledgement/rearm,
input latency and Turn eligibility, reset/Pause behavior, and routed timing
and CDC. Use board playtesting to select a usable speed. Keep acceptance of
this policy separate from the evidence for each implementation.

References: [locked specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md),
[ADR 0002](0002-follow-ta-divided-game-clock.md),
[ADR 0003](0003-step-transaction-mailbox-and-render-codes.md), and
[Game–Fast Crossing Research](../design/CS-256%20Game-Fast%20Crossing%20Research.md).
