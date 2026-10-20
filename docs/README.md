# CS-256 Tron Project: Folder Policy

All work for the CS-256 class project (the two-player Tron game) lives in this folder: notes, designs, decisions, HDL, testbenches, tools, and sprite assets. Do not write project files anywhere else in the vault. In particular, `CS-256/Homework/` is read-only, and `CS-256/cs256-fall-2026/` is the course's own repository (reference only, never push).

## Layout

| Path | Contents |
|---|---|
| `CS-256 Tron Game Overview.md` | Game concept from the whiteboard photo |
| `CS-256 Tron Game Mechanics.md` | Short, derived navigation summary of the locked rules |
| `CS-256 Tron Glossary.md` | Canonical game vocabulary. Use these terms in notes, code comments, and the report |
| `CS-256 VGA and Sprite Design Plan.md` | VGA timing, render pipeline, sprite ROMs, milestones |
| `CS-256 Tron Development Plan.md` | Calendar, freezes, scope tiers, work list, verification approach, prototype phases |
| `CS-256 Tron Agreed Specification 2026-10-20.md` | Consolidated team-agreed baseline locked at the end of the discussion; layout and schedule remain tentative |
| `CS-256 Tron Team Decisions 2026-10-20.md` | Question-by-question meeting decisions and the source-backed pre-meeting comparison |
| `CS-256 Tron Integration Comparison.md` | Historical comparison against the team-repository snapshot checked 15 October; recommendations are not decisions |
| `CS-256 TA Email - Game Clock.md` | Superseded historical draft; the game-clock question is closed |
| `CS-256 Official FPGA Coding Practices.md` | Manufacturer guidance for the selected design; superseded clock and pixel-pipeline comparisons are marked historical |
| `CS-256 Tron Architecture and Documentation Map.md` | Document authority, status, owners, update triggers, and traceability |
| `CS-256 Tron Documentation Control Review 2026-10-20.md` | Audit scope, findings, edits, and validation evidence |
| `CS-256 Tron Opus 5.5 Architecture and Integration Review.md` | Pinned team-repository review, integration gaps and proposed architecture; read the parent-review reservations before adopting recommendations |
| `CS-256 Tron Repository Merge Plan.md` | Draft repository-import procedure and choices; no migration, history rewrite or publication has been approved or executed by this review |
| `Nexys_A7_Game_Research_Report.md` | Board capabilities research |
| `Datasheets/`, `Nexys_A7_100T_Official_Docs/` | Vendor references |
| `hdl/` | Synthesizable SystemVerilog and `.xdc` constraints |
| `sim/` | Testbenches and simulation outputs (waveforms, `.ppm` frame dumps) |
| `prototype/` | Legacy local Python model (`model/`, headless), viewer (`look/`, pygame-ce), and local tests/metrics; shared-model migration and target Step logs remain open |
| `tools/` | Host-side scripts, such as `png2coe.py`, and the P2 web controller page (Web Serial) |
| `assets/` | Sprite art (`.png`) and generated `.coe` files |
| `evidence/` | Report evidence (waveforms, `.ppm` frames, board photos, report excerpts), named `<ObjectiveID>-<short-name>.<ext>`; logged in the development plan |
| `docs/adr/` | Architecture decision records, numbered `0001-slug.md` |
| `AGENTS.md`, `CLAUDE.md`, `docs/agents/` | Instructions for AI agents: issue tracker, triage labels, domain docs |

Create the subfolders when their first file is needed.

**Implementation home:** the team selected [romanmg00/FPGA](https://github.com/romanmg00/FPGA) for the shared HDL/model implementation. Its interface contract must first be reconciled with the course requirements and the locked team agreement; the remote contract and either implementation have not been migrated during the discussion. Until that reconciliation is recorded, the agreed specification is the current team-rule authority and existing code describes only its own present behavior.

## Read and authority path

1. Start with this folder policy and [[CS-256 Tron Architecture and Documentation Map]].
2. Read [[CS-256 Tron Agreed Specification 2026-10-20]] for the locked baseline and [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] for decision provenance. The pre-meeting comparison later in the decision note is historical.
3. Use [[CS-256 Tron Game Mechanics]] as a topic index and [[CS-256 Tron Glossary]] for terms; neither replaces the specification.
4. Read accepted ADRs and the relevant design guidance. [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md) is the accepted game-clock decision; ADR 0001 is superseded.
5. Read implementation notes alongside the actual code. The local prototype and the last reviewed remote snapshot predate the agreement; neither is evidence that the selected rules are implemented.
6. Check verification plans and recorded evidence before claiming a feature works. [[CS-256 Tron Development Plan]] is tentative planning, not an implementation report.

## Team

As confirmed from the TAs’ instruction on 2026-10-20, the team is **Roman and Alan**. Earlier three-person ownership plans are superseded. See [[CS-256 Tron Development Plan#Ownership]] for the proposed two-person split and [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] for confirmed decisions. One shared headless rules model in the team repository is selected; the current separate model implementations still need migration.

## Toolchain

- **Vivado (synthesis, implementation, simulation):** the team's shared tool is the remote KAUST workstation (`myws.kaust.edu.sa`), used through its web interface. Alan is also installing full Vivado on `alan-desktop` for local testing. Use the same Vivado version as the workstation, because IP cores (Clocking Wizard, Block Memory Generator) are tied to the version that generated them.
- **Vivado Lab (board programming and on-board debugging):** runs on each member's laptop, with the board attached (Alan: `alan-legion`, reached over SSH). Copy the `.bit` file, plus the `.ltx` probe file when the build includes ILA debug cores, from wherever it was built, then program the board locally.
- Prefer scripting Vivado Lab through its Tcl console (program, trigger, export captures as CSV) over operating its GUI.

## Rules

- **Authority:** course requirements and the TAs' strict-architecture instruction govern the project. The locked [[CS-256 Tron Agreed Specification 2026-10-20]] is the current team decision baseline. The team repository's interface contract is the selected implementation contract only after it incorporates that baseline; its older rules do not override the agreement. Existing code documents current behavior, not intended behavior. See the [[CS-256 Tron Architecture and Documentation Map]] for ownership and status.

- Follow the course [class project handout](../cs256-fall-2026/classproject/README.md) and [sprite tips](../cs256-fall-2026/classproject/sprites/README.md) strictly, as confirmed by the team from its TAs’ recommendation on 2026-10-20. The **final game** uses a second Clocking Wizard plus counter divider for an approximately **60 Hz game clock**, output-aligned coordinates and early sprite-memory reads. [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md) supersedes the frame-enable proposal in ADR 0001. Clock-enable and delayed-stream alternatives remain historical research in [[CS-256 Official FPGA Coding Practices]].

- The requested **83.46 MHz pixel clock** is separate from the approximately **60 Hz frame refresh** and the approximately **60 Hz game-state clock**. The divider, fast Arena service, and video pipeline have different responsibilities; do not describe the divided game clock as display-only.

- New notes use the vault's frontmatter and naming standard ([Metadata and File Standard](../../00-System/Planning/Metadata-and-File-Standard.md)), with a `CS-256` title prefix.
- When a game term is settled or changed, update the glossary. For rule changes, update the agreed specification and decision provenance first; update Mechanics only if its topic links need to change.
- Code and generated files (`.sv`, `.xdc`, `.coe`, `.py`) do not need frontmatter.
