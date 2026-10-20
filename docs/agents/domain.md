# Domain docs

How project agents use the game vocabulary, decisions, architecture records, and code without treating derived or stale material as current authority.

## Read in this order

1. Read the root [README](../README.md) and [[CS-256 Tron Architecture and Documentation Map]] for the authority order and document statuses.
2. Read [[CS-256 Tron Agreed Specification 2026-10-20]] for the locked team baseline. Use [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] for decision provenance; the older comparison below that record is historical.
3. Use [[CS-256 Tron Glossary]] for terms and [[CS-256 Tron Game Mechanics]] as a short topic index. The specification owns the rule details.
4. Read the accepted ADRs relevant to the task. ADR 0002 records the divided game clock; ADR 0001 is superseded. A plan or technical recommendation is not an accepted decision.
5. Inspect the actual source code for current implementation behavior. The local prototype and the team-repository snapshot described in the meeting record have not been reconciled to the locked agreement.

Course requirements and the TAs' strict-architecture instruction take precedence over team decisions. The selected remote interface contract is authoritative for implementation interfaces after reconciliation; stale contract text does not override the locked baseline. Keep decision status, review status, and implementation/verification evidence distinct.

## File structure

This is a single game context:

```text
CS-256/Game_research/
├── CS-256 Tron Glossary.md
├── CS-256 Tron Agreed Specification 2026-10-20.md
├── CS-256 Tron Game Mechanics.md     # derived index
└── docs/adr/
    ├── 0001-pixel-clock-with-frame-enable.md  # superseded
    └── 0002-follow-ta-divided-game-clock.md   # accepted
```

## Use the glossary and surface conflicts

Use the glossary's defined terms in issues, code comments, plans, and reports. Keep it focused on domain meaning; rule details belong in the agreed specification, and implementation mechanics belong beside the relevant code or design note.

If a task or source contradicts an accepted ADR or the locked specification, state the conflict with the document and section. Do not silently promote an old proposal or implementation into the current design.
