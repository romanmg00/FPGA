# Agent instructions: CS-256 Tron project

This is the team repository for the CS-256 two-player Tron game (Roman and Alan). `CLAUDE.md` imports this file, so Claude Code and other agents read the same instructions.

## Layout and boundaries

- `proyecto_final/`: hardware. Its interface contract, `proyecto_final/Contrato de interfaces game_top (CS 256).md`, is Roman's and is written in Spanish.
- `prototipos/`: PC prototypes. `prototipos/tron/` is Roman's viewer; `prototipos/tron_fpga/` is Alan's hardware-modelled Tron (viewer package `juego/`, rules in `model/`), imported as the Look Prototype. Each has its own requirements file and needs its own virtual environment: one uses `pygame`, the other `pygame-ce`.
- `docs/`: decisions, ADRs, design notes, plans and reviews. See [docs/README.md](docs/README.md) for the layout.
- `tools/`, `assets/`: host-side scripts and sprite art.

Keep existing paths where they are. Put new material in the folder that owns it, and create a folder only when its first file is needed.

## Authority

Start with the authority path in [docs/README.md](docs/README.md), then use [CS-256 Tron Architecture and Documentation Map](docs/CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md) to find the current owner and status of each fact. Use the vocabulary in [CS-256 Tron Glossary](docs/domain/CS-256%20Tron%20Glossary.md).

The current team-rule authority is [CS-256 Tron Agreed Specification 2026-10-20](docs/decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md); [CS-256 Tron Team Decisions 2026-10-20](docs/decisions/CS-256%20Tron%20Team%20Decisions%202026-10-20.md) records provenance. The Mechanics note is a derived index. Course requirements and the TAs' strict-architecture instruction take precedence. The interface contract in `proyecto_final/` becomes the implementation authority after it is reconciled with those sources. Existing code establishes current implementation behavior only.

**Never edit the files in `docs/decisions/`**, not even their links: their SHA-256 values are recorded in [docs/decisions/README.md](docs/decisions/README.md). Record a later team decision as a new ADR in `docs/adr/` (0003 onward).

Before changing implementation or architecture, read the relevant course handout, accepted ADR, and design notes, then inspect the actual code. Mark unverified proposals as proposals and keep implementation evidence separate from decision status.

Synthesis and simulation run on the remote Vivado workstation, or on `alan-desktop` once its Vivado install is finished. Vivado Lab on a member's laptop only programs the board and reads ILA captures. See the Toolchain section of [docs/README.md](docs/README.md).

## Agent skills

### Issue tracker

GitHub Issues in this repository, through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

One project glossary and a small set of accepted ADRs. See `docs/agents/domain.md` for the reading path and precedence rules.
