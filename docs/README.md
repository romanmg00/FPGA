# CS-256 Tron Project: Documentation and Decisions

This folder holds the team's decisions, architecture decision records (ADRs), design notes, plans, reviews and references for the CS-256 class project, the two-player Tron game. It was imported with its Git history from Alan's `CS-256/Game_research` repository on 20 October 2026; see [the merge plan](plan/CS-256%20Tron%20Repository%20Merge%20Plan.md). The hardware lives in `proyecto_final/` and the PC prototypes in `prototipos/`. `CS-256/cs256-fall-2026/` is the course's own repository: reference only, never push.

## Layout

Paths are relative to the repository root.

| Path | Contents |
|---|---|
| `docs/decisions/` | **Locked** 20 October records, never edited: the Agreed Specification (current team-rule authority) and the Team Decisions provenance record. Hashes, tags and the old-path map are in [decisions/README.md](decisions/README.md) |
| `docs/adr/` | Architecture decision records, numbered `0001-slug.md`. ADR 0001 is superseded, ADR 0002 is accepted; later team decisions start at 0003 |
| `docs/CS-256 Tron Architecture and Documentation Map.md` | Document authority, status, owners, update triggers, and traceability |
| `docs/domain/` | Glossary (canonical game vocabulary; use these terms in notes, code comments, and the report) and Game Mechanics (derived index of the locked rules) |
| `docs/design/` | VGA and Sprite Design Plan; Official FPGA Coding Practices (manufacturer guidance; superseded clock and pixel-pipeline comparisons are marked historical) |
| `docs/plan/` | Development Plan (calendar, freezes, scope tiers, work list, verification approach) and the Repository Merge Plan |
| `docs/reviews/` | Opus 5.5 Architecture and Integration Review (read its parent-review reservations before adopting recommendations), Documentation Control Review, and the archived Integration Comparison |
| `docs/history/` | Game Overview (whiteboard concept), superseded TA game-clock email draft, and the import commit map |
| `docs/references/` | Nexys A7 research report, vendor datasheets (`datasheets/`), and official documentation links |
| `docs/agents/` | Instructions for AI agents: issue tracker, triage labels, domain docs. The root `AGENTS.md` and `CLAUDE.md` point here |
| `proyecto_final/` | Hardware: interface contract, SystemVerilog, testbenches |
| `prototipos/tron_fpga/` | Legacy local Python prototype modelled on the hardware blocks (the Look Prototype, renamed from `prototipos/look/`): model (`model/`, headless), viewer (`juego/`, pygame-ce), tests and metrics; shared-model migration and target Step logs remain open |
| `prototipos/` (others) | Roman's prototypes and launcher, including the `tron/` viewer |
| `tools/` | Host-side scripts, such as candidate-art generation and `png2coe.py` |
| `assets/` | Sprite art (`.png`) and generated `.coe` files |

Create new folders, such as `evidence/` for report evidence named `<ObjectiveID>-<short-name>.<ext>`, when their first file is needed.

**Implementation home:** this repository, [romanmg00/FPGA](https://github.com/romanmg00/FPGA), is the team's shared HDL/model implementation home. Its interface contract (`proyecto_final/Contrato de interfaces game_top (CS 256).md`) must first be reconciled with the course requirements and the locked team agreement. The 20 October update of the contract adopts the agreed rules, inputs, clocks, Arena codes and two-person split, and marks the interfaces the specification leaves open as *Pendiente*; its earlier version is in `proyecto_final/deprecated/`. Until each pending interface is settled and recorded there, the agreed specification is the current team-rule authority and existing code describes only its own present behavior.

## Read and authority path

1. Start with this README and [[CS-256 Tron Architecture and Documentation Map]].
2. Read [[CS-256 Tron Agreed Specification 2026-10-20]] for the locked baseline and [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] for decision provenance. The pre-meeting comparison later in the decision note is historical.
3. Use [[CS-256 Tron Game Mechanics]] as a topic index and [[CS-256 Tron Glossary]] for terms; neither replaces the specification.
4. Read accepted ADRs and the relevant design guidance. [ADR 0002](adr/0002-follow-ta-divided-game-clock.md) is the accepted game-clock decision; ADR 0001 is superseded.
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

- Follow the course [class project handout](../../cs256-fall-2026/classproject/README.md) and [sprite tips](../../cs256-fall-2026/classproject/sprites/README.md) strictly, as confirmed by the team from its TAs’ recommendation on 2026-10-20. Links into `cs256-fall-2026/` resolve only when this repository is cloned beside the course repository, as in the vault's `CS-256/` folder. The **final game** uses a second Clocking Wizard plus counter divider for an approximately **60 Hz game clock**, output-aligned coordinates and early sprite-memory reads. [ADR 0002](adr/0002-follow-ta-divided-game-clock.md) supersedes the frame-enable proposal in ADR 0001. Clock-enable and delayed-stream alternatives remain historical research in [[CS-256 Official FPGA Coding Practices]].

- The requested **83.46 MHz pixel clock** is separate from the approximately **60 Hz frame refresh** and the approximately **60 Hz game-state clock**. The divider, fast Arena service, and video pipeline have different responsibilities; do not describe the divided game clock as display-only.

- New notes use the Obsidian vault's frontmatter and naming standard ([Metadata and File Standard](../../../00-System/Planning/Metadata-and-File-Standard.md)), with a `CS-256` title prefix.
- When a game term is settled or changed, update the glossary. The 20 October records in `docs/decisions/` stay byte-identical: record a rule change as a new ADR (0003 onward) or a dated successor specification, then update Mechanics' topic links if needed.
- Code and generated files (`.sv`, `.xdc`, `.coe`, `.py`) do not need frontmatter.
