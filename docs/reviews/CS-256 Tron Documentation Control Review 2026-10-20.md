---
schema_version: 1
id: cs256-tron-doc-control-review-20261020
title: CS-256 Tron Documentation Control Review 2026-10-20
type: audit
subject: CS-256
status: done
created_at: "2026-10-20T14:39:59"
updated_at: "2026-10-20T15:14:27"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
  - "[[CS-256 Tron Architecture and Documentation Map]]"
review_status: verified
tags:
  - tron
  - documentation
  - audit
---

# CS-256 Tron Documentation Control Review 2026-10-20

## Summary

The locked specification and live Q1–Q40 record agree on the selected behavior and architecture. The main documentation risk was that navigation and agent guidance still gave the unreconciled remote interface contract and the longer Mechanics note higher authority than the locked agreement. The local prototype README presented legacy code behavior as pending design choices; the coding and VGA plans also left portions of the superseded clock proposal or unimplemented HDL/IP work looking current or complete. The project now has one authority path, a document register, an architecture/ownership map, and traceability to the existing work-list IDs.

No gameplay or architecture decision was changed. The specification and decision record remain unchanged. The external team contract, local model, and remote implementation have not been updated or verified by this documentation task.

## Reviewed scope

The pre-edit inventory contained **22 Markdown files** under `CS-256/Game_research/`. I read all of them, including all project READMEs, project instructions, architecture notes, ADRs, the development/VGA plans, the prototype guide, the board research report, and the generated prototype metrics summary. The before hashes and initial worktree state are preserved in `/tmp/cs256-tron-docs-before-20261020.txt`, `/tmp/cs256-tron-docs-before-status-20261020.txt`, and a byte-for-byte Markdown snapshot under `/tmp/cs256-tron-docs-before-20261020/`.

I also read the read-only course class-project README and sprite tips because the accepted architecture depends on them. The handout explicitly instructs a second divider and approximately 60 Hz clock for game logic; the sprite tips require early reads by the actual memory latency. I inspected local `prototype/model/params.py`, `scoring.py`, `step.py`, `rewards.py`, and `lfsr.py` to distinguish current local behavior from the target.

The course repository and Homework were not edited. I did not edit code, tests, generated assets, vendor sources, or any remote repository. The generated [prototype metrics summary](prototype/metrics/latest.md) was reviewed and left untouched. The separate `CS-256 Tron Opus 5.5 Architecture and Integration Review.md` was absent from this checkout at review time; I did not create a link to it or treat its future recommendations as decisions. This review does not claim to audit current remote `main`.

At audit start the nested `Game_research` repository was at `6ef8104` with uncommitted README, plan, mechanics, glossary, ADR, and other document edits already present; the two locked primary notes and ADR 0002 were untracked. I preserved that working state and built on it. The `/tmp` snapshot is for comparison, not a new vault artifact.

## Findings and evidence

### High — authority was split across active documents

The project [README](README.md) and [AGENTS.md](AGENTS.md) directed readers to the team repository's interface contract and Mechanics note as authorities. The locked specification says the remote contract and implementations were not changed by the discussion and that stale code is a discrepancy to reconcile. This left future readers with two plausible, conflicting sources. The [Domain docs](docs/agents/domain.md) also described Mechanics as the agreed rules document.

**Fix:** the README and agent pointers now put course/TA requirements first, the locked specification as the current team baseline, the decision record as provenance, and the remote contract as the implementation-interface authority only after reconciliation. Mechanics is now a derived index. The [architecture map](CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md) makes those roles explicit.

### High — legacy prototype behavior was presented as unresolved design

The [prototype README](prototype/README.md) called the local 3-bit Arena, 99-Point cap, +3/+3/+5 Rewards, +5 Survival Bonus, and four-frame cadence a comparison contract with “Model choices awaiting L2.” The code in `prototype/model/` confirms these are current legacy implementation details. L2 is no longer the point at which the locked behavior is to be decided.

**Fix:** the README labels those sections as local implementation behavior and gives a short target-versus-local mismatch table. It states that current local tests and metrics do not prove the locked design is implemented.

### Medium — design plans retained stale or over-specific details

The VGA plan still described the selected game step as an 8 px Cell per K ticks, linked rule checks to Mechanics, and assigned project milestones to course dates that could read as hard feature deadlines. Its verification table used checkmarks even though the converter, HDL, and generated IP were absent from this workspace. The development plan fixed UART RX to `pixclk`, gave an exact oversampling-divider value, tied an Arena BRAM port to `pixclk`, and said the software model would use the same LFSR as the HDL, despite those implementation choices not being selected or verified.

**Fix:** the plans now link rule checks to the specification, use the selected 16 px / six-game-clock-tick step, make internal target dates explicitly flexible, mark receiver/fast-memory clock selection as unresolved, and distinguish the shared-model decision from the still-open PRNG/seed implementation. The VGA matrix labels converter/IP/HDL work as planned or absent rather than complete.

### Medium — historical proposals could still read as current instructions

The integration comparison preserved a pre-meeting “Already agreed” section, a three-person split, a one-clock game proposal, and obsolete suggestions. The TA email was labeled a draft despite the clock question being closed. The coding-practices note and VGA appendix still called the superseded clock/pixel-pipeline alternatives future evaluations. The whiteboard overview still listed the Master/menu role and unresolved rules as if they described the current proposal. A generic board research report recommended 640 × 480 as a first-game mode without saying that the course handout governs this project.

**Fix:** these records now carry concise historical/reference status notes; the coding-practices note distinguishes AMD guidance from historical project applications and labels the optional BRAM-port arrangement as unselected. Original analysis and evidence were retained. The vendor documentation README now points back to the project map.

### No conflict found in the locked decision artifacts

I compared the full agreed specification with the live Q1–Q40 record. The spec's 10/20/30/40 goals, final-Step scoring, two-member ownership, strict divided game clock, shared-model intent, Scoreboard mapping, and tentative layout/schedule agree with the live record and its later clarifications. The old comparison beneath the live record remains historical; no discrepancy was found that requires changing either locked artifact.

## Control structure established

The [CS-256 Tron Architecture and Documentation Map](CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md) provides:

- One canonical owner for team rules, vocabulary, clock architecture, code behavior, verification, and tentative planning.
- A reading sequence from README and agreement through glossary/mechanics, accepted ADRs, implementation status, evidence, and planning.
- An architecture/ownership table for the slow game-state clock, video clock, fast Arena service, ordered inputs, shared model, Scoreboard, and cross-testing. Unselected clocks and protocols are explicitly left open.
- A register for all project Markdown areas reviewed, with authority/status, owner, purpose, source, and update trigger.
- A traceability table using the existing `A1/A2`, `G1–G5`, `I1–I4`, `M2`, `P2/P3`, `V1–V4`, `X1/X2`, and `Z1–Z5` work-list IDs.

The spec's `decision_status: agreed`, the note-level `review_status`, and implementation evidence are described as separate fields. A locked agreement is not a claim of migration, passing verification, or a completed board build.

## Exact edits

- Updated `README.md`, `AGENTS.md`, and `docs/agents/domain.md` to establish authority and the read path. `CLAUDE.md`, issue-tracker guidance, and triage-label definitions were reviewed and did not need changes.
- Reduced `CS-256 Tron Game Mechanics.md` to a topic index to the agreed specification; aligned glossary terms and removed the obsolete Master/Setup Phase as current vocabulary.
- Updated `CS-256 Tron Development Plan.md` and `CS-256 VGA and Sprite Design Plan.md` where active plan text conflicted with settled rules, treated flexible targets as commitments, or overstated implementation status.
- Reframed `prototype/README.md` as a guide to the existing local implementation, with explicit migration gaps, legacy candidate effects, and the PNG-versus-`.coe` distinction.
- Reconciled `CS-256 Official FPGA Coding Practices.md` to ADR 0002; marked old clock and delayed-stream comparisons historical, left port clocks and transfer protocols open, and linked Arena encoding to its canonical specification section.
- Marked the integration comparison and TA email archived; marked the overview and generic board research as historical/reference material. Updated the vendor docs README to point back to the project map.
- Added `CS-256 Tron Architecture and Documentation Map.md` and this review report.
- Did not modify `CS-256 Tron Agreed Specification 2026-10-20.md` or `CS-256 Tron Team Decisions 2026-10-20.md`.

## Remaining implementation work and boundaries

These are engineering tasks in the locked spec, not open gameplay decisions:

- Reconcile the remote team contract and existing implementations; migrate to one shared headless model and viewer adapters.
- Select and verify the exact PRNG, Start-time seed capture/advancement, and bounded or multi-frame Reward placement schedule.
- Define and measure the fast Arena service, slow-game request/result transfers, render snapshots, arbitration, reset/Pause behavior, and stale-transaction handling. The selected boundary does not lock a specific clock or CDC circuit.
- Finish Enter's wire encoding, ordered UART/input transfer, P/L glyphs, and native RGB444 asset/COE generation.
- Verify actual generated pixel/game-clock frequencies, actual ROM latency, alignment boundaries, synthesis, routed timing/CDC/DRC, and board behavior. No such target HDL evidence was found in the workspace inventory.
- Keep the working Arena layout revisable after game review. Keep the 15 November and 23 November internal targets flexible; the 19 November, 30 November, and 10 December course dates remain fixed.
- Source comments in `prototype/model/params.py`, `prototype/look/art.py`, `prototype/look/rgb444.py`, and `prototype/look/candidates.py` still call L2 a pending lockdown or describe `080` as an L2 proposal. Python files were outside the authorized edit scope; the prototype README now labels these as legacy viewer behavior, but those comments remain to reconcile.

The current remote repository, its README, and its interface contract were not changed or reviewed against current `main`. After the separate current-main architecture/integration review, reconcile the remote README and contract to the authority order and locked interface boundary here; first compare any proposed findings with course/TA direction and the locked specification. Do not treat the remote contract as reconciled until that work is recorded.

## Validation

Focused documentation validation covered all **17 changed Markdown files** (15 edits and two new notes):

- A parser checked YAML frontmatter, fenced code blocks, and trailing whitespace. It reported **no frontmatter errors, unmatched fences, or trailing whitespace**.
- Relative Markdown links, Obsidian wiki targets, and heading anchors in the edited documents were checked: **no missing file targets or unresolved anchors**.
- `git -C CS-256/Game_research diff --check` completed cleanly.
- The two locked files matched the saved before-edit snapshot byte-for-byte: specification SHA-256 `cd524e90200623ec4ccb39a3431deb5aa37e9615ae6eb78ea81d3af2dacafec2`; decision record SHA-256 `ff9c1c6223de3a47ebef67f17751bddf940bddf080b2da0da8af1d214d029269`.
- A focused `rg` scan of known stale role, clock, scoring, and schedule claims found remaining instances only in explicitly historical records or sections describing current legacy prototype behavior.

No code tests, build, IP generation, board check, or GUI launch was run. The local HDL, simulation, and evidence directories are absent from the workspace. The quick-start commands were not changed or executed.

## Parent review

The parent compared all 15 existing-file edits against the saved pre-edit snapshot and reviewed both new notes. Both locked primary files still match the snapshot byte-for-byte. The review corrected the prototype README's placement-estimate reference to the development plan's Open items section. It also restored `review_status: unreviewed` on the coding-practices, VGA-plan and development-plan notes: this pass establishes documentation consistency, not a complete independent revalidation of their cited sources. These notes now state that review boundary explicitly. No agreed gameplay or architecture decision was changed.

Independent checks passed across the 17 changed documents: 60 relative Markdown links and 145 wiki targets, including referenced headings, resolved locally; 11 frontmatters parsed; no unmatched fences or trailing whitespace were found; and `git -C CS-256/Game_research diff --check` passed. ADR 0001 retains its pre-existing minimal ADR frontmatter (`status` only), checked against the domain-modeling ADR format rather than the full vault-note schema. The other ten frontmatters were checked for the required vault-note properties. External URLs and source-claim accuracy were outside this link check.

After Opus completed its separate integration review, the parent registered [[CS-256 Tron Opus 5.5 Architecture and Integration Review]] and [[CS-256 Tron Repository Merge Plan]] in the README and document map. The parent corrected two additional documentation nits: agreed ownership was still described as “for review,” and the Glossary conflated the collision Wall with the drawn Border. The architecture review now carries explicit parent reservations about its proposed CDC, render coherence, timing bounds and migration procedure. Those proposals remain unaccepted; no migration, commit or push was executed. See [[CS-256 Tron Opus 5.5 Architecture and Integration Review#Parent review and adoption limits]].

Final combined checks passed for 19 changed Markdown files: 13 parsed frontmatters (including the existing minimal ADR format), 277 local links and heading references, matched fences, no trailing whitespace, and `git diff --check`. Two ambiguous merge-plan links were qualified to the current `00-System/Planning/Metadata-and-File-Standard` rather than its archived namesake. Both locked files still match the original hashes. These are documentation checks; target hardware verification remains outstanding.
