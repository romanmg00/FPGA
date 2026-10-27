---
schema_version: 1
id: cs256-tron-architecture-document-map-20261020
title: CS-256 Tron Architecture and Documentation Map
type: note
subject: CS-256
status: active
created_at: "2026-10-20T14:38:28"
updated_at: "2026-10-20T19:33:29"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
  - "[[0002-follow-ta-divided-game-clock]]"
review_status: verified
tags:
  - tron
  - architecture
  - documentation
---

# CS-256 Tron Architecture and Documentation Map

This note identifies which document owns each kind of project fact, how the current architecture is divided, and where agreement-to-implementation work is tracked. It does not add architecture decisions.

**Prototype comparison, 27 October 2026:** `prototipos/tron/fpga/` preserves the
PR #2 game and its historical rules. `prototipos/tron_fpga/` contains the newer
PR #4 model; its proposed interfaces are described in
[[CS-256 Tron Game Model Hardware Map]]. See [launch instructions](../prototipos/README.md).
The legacy implementation references below describe the PR #2 baseline, now at
`prototipos/tron/fpga/`; they are not a verification report for the newer model.

## Authority and status

1. **Course requirements and TA instructions** govern the assignment and architecture. The course repository is read-only reference material for this project.
2. **[[CS-256 Tron Agreed Specification 2026-10-20]]** is the current team baseline for behavior and agreed design. Its `decision_status: agreed` records that the team discussion was closed and locked.
3. **[[CS-256 Tron Team Decisions 2026-10-20#Live decision record]]** is the provenance record. Its pre-meeting comparison and recommendations below the live record are historical.
4. **The interface contract in `proyecto_final/Contrato de interfaces game_top (CS 256).md`** becomes the implementation-interface authority after it is reconciled with course requirements and the locked specification. The decision record reviewed it at commit `f5cb82c901e33a453fcaea2720a80702fda54718` from 15 October. The 20 October update adopts the agreed rules and marks the open interfaces (game/memory service and CDC, Reward generator, UART Enter, `tick_60hz`, shared-model location) as *Pendiente*; the earlier version is kept in `proyecto_final/deprecated/`.
5. **Code describes present implementation behavior.** It does not override the selected design. Plans describe intended work; passing tests for a legacy implementation do not establish target behavior.

These status fields answer different questions: `decision_status: agreed` means a team decision was locked; `review_status` describes review of the note's content; neither means implementation is complete or verified. Implementation and verification status must come from the actual source and objective-linked evidence.

## Read path

Start with the project [README](README.md), then read the agreed specification and live decision record. Use [[CS-256 Tron Game Mechanics]] as a topic index and [[CS-256 Tron Glossary]] for vocabulary. Next read ADR 0002 and the relevant design notes. Check the local prototype guide and actual code for current behavior, then use the development plan and recorded evidence to assess implementation. Internal dates in the plan are tentative; course assessment dates are fixed.

## Architecture and ownership

| Area | Current agreed responsibility | Owner | Status and open boundary |
|---|---|---|---|
| Game-state clock | Second Clocking Wizard plus divider counter produces an approximately 60 Hz clock for game-state logic | Roman owns movement/Turns/collisions; Alan owns Round/Match, Lives, and scoring | Accepted by [[0002-follow-ta-divided-game-clock]]. Pixel clock and frame refresh are distinct. |
| Video | Requested 83.46 MHz pixel clock produces the 1280 × 800 raster; frame refresh is approximately 60 Hz. Keep output-aligned coordinates and read sprite memory early by its actual latency. | Roman | Course baseline and team agreement; generated clock, actual ROM latency, edge alignment, and board timing still need evidence. |
| Arena and memory service | Fast controller is the Arena write owner; it services slow-game requests and returns results. Both Bike targets are read before either move is committed. | Alan | Service boundary is selected. Exact fast clock, arbitration, coherent transfer protocol, bounds, reset/Pause behavior, and render snapshots remain unverified engineering work. `pixclk` is not locked as the Arena service clock. |
| Inputs | P1 uses board direction buttons; P2 uses browser WASD over 115200-baud, 8N1 USB-UART. Preserve keyboard/UART order and sampled board-event order. | Alan | Input choice is agreed. Enter's wire encoding, receiver clock, debounce policy, and CDC implementation remain to be completed. |
| Shared rules model | One headless rules model in the team repository serves both PC viewers and HDL scenarios. | Alan coordinates; both members integrate and cross-test | Model migration location/base and adapters are not selected; existing local and remote models remain legacy inputs. |
| Physical Scoreboard | Eight digits show synchronized P2-left and P1-right Points/Lives banks continuously | Alan | Mapping and 3-second view timing are agreed. P/L glyphs, integration, and board visibility need verification. |
| Cross-cutting contract | Both members define game/service/render interfaces, review timing/CDC, and test the other member's blocks | Roman and Alan | Ownership is agreed; register ownership and transaction fields must be captured in the reconciled team contract. |

## Document register

“Status” says what kind of authority a document has. “Update when” identifies its owner-maintenance trigger; derived notes should link to the canonical owner instead of copying its rule tables.

| Document | Status and owner | Owns / purpose | Source and update trigger |
|---|---|---|---|
| [Project README](README.md) | Entry point and folder policy; team-maintained | Authority path, reading sequence, layout, project boundaries | Course policy and locked agreement; update when authority, layout, or navigation changes. |
| [AGENTS.md](../AGENTS.md) and [CLAUDE.md](../CLAUDE.md) | Process pointers; project-maintained | Agent reading order and folder guidance | Must mirror this map and README; update when those sources or agent workflow change. |
| [Domain docs](agents/domain.md) | Process pointer; project-maintained | Domain reading order and conflict handling | This map, glossary, specification, and ADR statuses; update when document authority changes. |
| [Issue tracker](agents/issue-tracker.md) and [triage labels](agents/triage-labels.md) | Process references; project-maintained | GitHub issue and label conventions | Tracker configuration; update only when the workflow or actual labels change. These do not decide game behavior. |
| [[CS-256 Tron Agreed Specification 2026-10-20]] | **Locked team-rule authority**; team-owned | Selected game rules, hardware baseline, work division, and tentative scope/schedule | Course requirements plus the live decision record. **Never edited** (SHA-256 in [decisions/README.md](decisions/README.md)). When the team formally reopens a decision or course/TA direction requires a change, record it in a new ADR or a dated successor record. |
| [[CS-256 Tron Team Decisions 2026-10-20]] | Decision provenance; team-owned | Q1–Q40 and source-backed context | Live discussion. **Never edited**, including its historical comparison. Record a formal correction or reopened decision in a new ADR or a dated successor record. |
| [[CS-256 Tron Game Mechanics]] | **Derived index**; project-maintained | Links from rule topics to the specification | Specification headings; update links when the specification changes. It is not a second rule source. |
| [[CS-256 Tron Glossary]] | Vocabulary authority; project-maintained | Canonical meanings of game terms | Domain language; update when a term is resolved or changes, without duplicating implementation details. |
| [ADR 0002](adr/0002-follow-ta-divided-game-clock.md) | **Accepted architecture decision**; team-owned | Strict handout divided game-state clock and consequences | TA instruction and course handout. Revisit only if course/TA direction or a formally reopened architecture decision changes. |
| [ADR 0001](adr/0001-pixel-clock-with-frame-enable.md) | Superseded historical proposal; preserved | Rationale and calculations for the former pixel-clock/frame-enable path | Superseded by ADR 0002; retain as research, not a pending alternative for this build. |
| [[CS-256 VGA and Sprite Design Plan]] | Design plan; Roman leads video, team reviews | Raster, output-aligned pixels, sprite prefetch, test plan, and design work packages | Course handout, sprite tips, agreed spec. Update accepted design links and add evidence only after actual checks. |
| [[CS-256 Official FPGA Coding Practices]] | Source-backed engineering guidance; team-maintained | AMD/vendor constraints, proposed interfaces, implementation checks | Official manuals and product guides. Distinguish sourced guidance, project arithmetic, selected decisions, and unverified proposals. |
| [[CS-256 Tron Development Plan]] | Tentative work plan; Alan coordinates | Existing objective IDs, owners, proposed sequencing, and evidence checks | Specification and progress evidence. Update staging as work changes; keep 15/23 November targets flexible and course dates fixed. |
| [Prototype README](../prototipos/tron_fpga/README.md) | Current local-implementation guide; local code owner | How to run and inspect the legacy local viewer/model | `prototipos/tron_fpga/` source. Update when that code changes; keep its behavior separate from the selected contract until migration. |
| `prototipos/tron_fpga/model/` | Current local implementation; code owner per repository | Actual local Python model behavior | Source code is authoritative only for this implementation. Reconcile during migration; its tests do not verify the agreed target. |
| [Prototype metrics](../prototipos/tron_fpga/metrics/latest.md) | Historical generated evidence, 17 October; code-generated | PC viewer measurements and hardware estimates for the local prototype | Metrics script and CSV; regenerate only for a new measurement run. Not HDL or board evidence. |
| [[CS-256 Tron Integration Comparison]] | Archived snapshot; team-maintained history | Pre-meeting comparison against remote commit `f5cb82c…` | Meeting preparation. Do not treat its recommendations or “Already agreed” labels as current. A current remote review must be recorded separately. |
| [[CS-256 TA Email - Game Clock]] | Archived superseded draft; preserved | Historical frame-enable approval request | Closed by the reported strict-architecture instruction and ADR 0002; no TA permission is pending. |
| [[CS-256 Tron Game Overview]] | Historical whiteboard record; preserved | Original concept and grading-rubric context | Source photograph. Keep early Master/menu/input ideas labeled historical. |
| [[Nexys_A7_Game_Research_Report]] | General hardware research; team-maintained | Board capabilities and broad FPGA game examples | Board/vendor evidence. Its generic 640 × 480 suggestions do not set this project's mode. |
| [Official documentation bundle](references/Nexys_A7_100T_Official_Docs/README.md) | Vendor-source index; preserved | Links to board, FPGA, and sensor documentation | Vendor publications; follow course project requirements for this game's design. |
| [[CS-256 Tron Documentation Control Review 2026-10-20]] | Audit record; project-maintained | Reviewed scope, discrepancies, changes, unresolved work, and validation | This documentation review; update when its findings are reconciled or validation status changes. |
| [[CS-256 Tron Opus 5.5 Architecture and Integration Review]] | Independent review; proposals, not accepted ADRs | Pinned main-repository findings and architecture/integration options | Reviewed main SHA and locked agreement; read the Parent review section before selecting a proposed interface. Update as findings are resolved. |
| [Locked records index](decisions/README.md) | Integrity record; team-owned | SHA-256 values, tags and the old-to-new path map for the two locked records | Update only if a further dated record is added; the locked records themselves never change. |
| [[CS-256 Tron Repository Merge Plan]] | Migration procedure, import prepared 20 October 2026; Alan | Import method, file mapping, history and working-copy options | Steps A–D ran on branch `integrate/game-research`, with the corrections recorded in its execution note; the push, pull request and merge (step E) are pending, and the vault folder has not been converted (step F). |

## Traceability

The objective identifiers below already exist in [[CS-256 Tron Development Plan#Work list]]. They connect accepted rules to implementation areas and evidence checks without creating a second ticket system.

| Agreed area | Existing work IDs | Current implementation / evidence | Remaining work |
|---|---|---|---|
| Turns, movement, simultaneous collision, Trails | G1/G2 | Local `prototipos/tron_fpga/model/step.py` and `steering.py` are legacy implementation; local tests exercise that behavior only | Migrate one model; implement Roman's assigned HDL blocks; cross-test agreed edge cases and record Step-log evidence. |
| Match/Round lifecycle, Lives, scoring, Rewards | G3/G4/G5 | Local model remains incompatible in its Points goal, cap, Reward values, Survival Bonus, timing, and PRNG choices | Implement the locked order and full legal final-Step total; choose and verify PRNG, seed advancement, and bounded placement service. |
| Arena storage and service boundary | A1/A2/X1 | No Arena HDL or agreed service implementation exists in this repository yet; plan and guidance contain proposals | Reconcile the contract; establish one write owner, coherent requests/results/snapshots, and measured service/reset/Pause behavior. |
| Video and sprite memory | V1–V4/P2/P3 | VGA plan and local viewer are design/PC references; no target HDL evidence is recorded here | Verify generated clocks, actual ROM latency, early reads, boundaries, RGB/sync alignment, synthesis, and board lock. |
| Inputs and physical Scoreboard | I1–I4/X2 | The plan specifies intended checks; local GUI controls are not the target board/UART implementation | Finish Enter encoding, ordered command transfer, P/L glyphs, board checks, and timing/CDC evidence. |
| Scenario and integration verification | M2/Z1/Z2/Z3/Z4/Z5 | Local prototype tests/metrics exist for the legacy implementation; `proyecto_final/` holds only the VGA counter skeleton and its testbenches, and no `evidence/` folder exists yet | Record target model/HDL comparisons, playtests, routed timing/CDC/DRC, and report evidence against the existing IDs. |

## Schedule status

The pre-demo build around **15 November** and demo-code freeze around **23 November** are flexible team targets, not hard core-completion dates. Course assessments remain **19 November** (pre-demo), **30 November** (demo), and **10 December** (report). See [[CS-256 Tron Development Plan#Calendar and freezes]] for context.

## Integration review follow-up

The independent review confirms agreement fidelity and identifies contract reconciliation, shared-model migration and the X1 slow-game/fast-service interface as the main integration blockers. Its custom mailbox, input batching and render-update policy are proposed implementations requiring proof; they are not additional accepted architecture decisions. See [[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]]. The repository merge plan was approved by the team, and the import was prepared on 20 October 2026 on branch `integrate/game-research`. Pushing it, Roman's pull-request review and the merge are still pending; converting the vault folder into a working clone is a separate, later step.
