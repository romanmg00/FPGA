---
schema_version: 1
id: cs256-tron-game-mechanics-20261014
title: CS-256 Tron Game Mechanics
type: note
subject: CS-256
status: active
created_at: "2026-10-14T23:00:00"
updated_at: "2026-10-20T19:33:29"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
review_status: verified
tags:
  - tron
---

# CS-256 Tron Game Mechanics

This note is a short topic index for the locked team rules. The canonical rule details live in [[CS-256 Tron Agreed Specification 2026-10-20]]; [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] records how they were chosen. Course requirements and the TAs' strict-architecture instruction take precedence over the team baseline.

Use [[CS-256 Tron Glossary]] for domain terms. A rule agreement records intended behavior; it does not show that a prototype, HDL block, or remote contract implements or verifies it. See [[CS-256 Tron Architecture and Documentation Map]] for document status, implementation links, and evidence paths.

## Rule topics

| Topic | Canonical specification section |
|---|---|
| Match, Points Goal, scoring and simultaneous finishes | [[CS-256 Tron Agreed Specification 2026-10-20#Match, Points Goal and scoring]] |
| Movement, Pending Turns, Trails and Crashes | [[CS-256 Tron Agreed Specification 2026-10-20#Movement, Turns and Crashes]] |
| Reward slots, Survival Bonus and randomness | [[CS-256 Tron Agreed Specification 2026-10-20#Rewards and randomness]] |
| Start, Round transitions, Crash display, Pause and reset | [[CS-256 Tron Agreed Specification 2026-10-20#Start, Crash display, Pause and reset]] |
| Physical Scoreboard | [[CS-256 Tron Agreed Specification 2026-10-20#Physical Scoreboard]] |
| Video, sprites and revisable working layout | [[CS-256 Tron Agreed Specification 2026-10-20#Video, sprites and working layout]] |
| Clocks, Arena encoding and service boundary | [[CS-256 Tron Agreed Specification 2026-10-20#Clocks, Arena encoding and service boundary]] |
| Ownership, scope and tentative schedule | [[CS-256 Tron Agreed Specification 2026-10-20#Work division and independent verification]] · [[CS-256 Tron Agreed Specification 2026-10-20#Scope and tentative schedule]] |

## Maintenance

When the team formally revises a rule, record it in a new ADR (0003 onward) or a dated successor record; the 20 October specification and decision record stay byte-identical. Then check the affected links here and the glossary. Keep implementation notes and evidence linked to the rule they realize; do not copy the specification's rule tables into this index.

## Legacy section links

The following concise headings retain anchors cited from the pre-meeting comparison in the locked decision record. Each now routes to the canonical specification rather than reproducing the old rule text.

### Match and Rounds

Current rules: [[CS-256 Tron Agreed Specification 2026-10-20#Match, Points Goal and scoring]] and [[CS-256 Tron Agreed Specification 2026-10-20#Start, Crash display, Pause and reset]].

### Movement

Current rules: [[CS-256 Tron Agreed Specification 2026-10-20#Movement, Turns and Crashes]].

### Trails and Crashes

Current rules: [[CS-256 Tron Agreed Specification 2026-10-20#Movement, Turns and Crashes]].

### Points

Current rules: [[CS-256 Tron Agreed Specification 2026-10-20#Match, Points Goal and scoring]].

### Rewards

Current rules: [[CS-256 Tron Agreed Specification 2026-10-20#Rewards and randomness]].

### Controls

Current rules: [[CS-256 Tron Agreed Specification 2026-10-20#Start, Crash display, Pause and reset]].

### Scoreboard (7-segment)

Current mapping and timing: [[CS-256 Tron Agreed Specification 2026-10-20#Physical Scoreboard]].

### Display sizes

Current working video/layout baseline: [[CS-256 Tron Agreed Specification 2026-10-20#Video, sprites and working layout]].

### Beyond the core game

Current scope and schedule: [[CS-256 Tron Agreed Specification 2026-10-20#Scope and tentative schedule]].
