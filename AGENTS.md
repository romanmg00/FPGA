# Agent instructions: CS-256 Tron project

Start with the folder policy and authority path in [README.md](docs/README.md), then use [CS-256 Tron Architecture and Documentation Map](docs/CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md) to find the current owner and status of each fact. Use the vocabulary in [CS-256 Tron Glossary](docs/domain/CS-256%20Tron%20Glossary.md).

The current team-rule authority is [CS-256 Tron Agreed Specification 2026-10-20](docs/decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md); [CS-256 Tron Team Decisions 2026-10-20](docs/decisions/CS-256%20Tron%20Team%20Decisions%202026-10-20.md) records provenance. The Mechanics note is a derived index. Course requirements and the TAs' strict-architecture instruction take precedence. The remote interface contract becomes the implementation authority after it is reconciled with those sources. Existing code establishes current implementation behavior only.

Before changing implementation or architecture, read the relevant course handout, accepted ADR, and design notes, then inspect the actual code. Mark unverified proposals as proposals and keep implementation evidence separate from decision status.

Synthesis and simulation run on the remote Vivado workstation, or on `alan-desktop` once its Vivado install is finished. Vivado Lab on a member's laptop only programs the board and reads ILA captures. See the Toolchain section of the README.

## Agent skills

### Issue tracker

GitHub Issues in the team repository, through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

One project glossary and a small set of accepted ADRs. See `docs/agents/domain.md` for the reading path and precedence rules.
