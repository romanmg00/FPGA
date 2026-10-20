# CS-256 Tron Project: Folder Policy

All work for the CS-256 class project (the two-player Tron game) lives in this folder: notes, designs, decisions, HDL, testbenches, tools, and sprite assets. Do not write project files anywhere else in the vault. In particular, `CS-256/Homework/` is read-only, and `CS-256/cs256-fall-2026/` is the course's own repository (reference only, never push).

## Layout

| Path | Contents |
|---|---|
| `CS-256 Tron Game Overview.md` | Game concept from the whiteboard photo |
| `CS-256 Tron Game Mechanics.md` | The game rules on one page, for group discussion |
| `CS-256 Tron Glossary.md` | Canonical game vocabulary. Use these terms in notes, code comments, and the report |
| `CS-256 VGA and Sprite Design Plan.md` | VGA timing, render pipeline, sprite ROMs, milestones |
| `CS-256 Tron Development Plan.md` | Calendar, freezes, scope tiers, work list, verification approach, prototype phases |
| `CS-256 Tron Agreed Specification 2026-10-20.md` | Consolidated team-agreed baseline locked at the end of the discussion; layout and schedule remain tentative |
| `CS-256 Tron Team Decisions 2026-10-20.md` | Question-by-question meeting decisions and the source-backed pre-meeting comparison |
| `CS-256 Tron Integration Comparison.md` | Every difference from Roman's team repo (`romanmg00/FPGA`), with team decisions and technical recommendations, for the integration meeting |
| `CS-256 TA Email - Game Clock.md` | Draft email to the TAs about the game-clock decision |
| `CS-256 Official FPGA Coding Practices.md` | Detailed manufacturer guidance for the selected design, plus divided-clock/clock-enable and sprite-pipeline comparisons |
| `Nexys_A7_Game_Research_Report.md` | Board capabilities research |
| `Datasheets/`, `Nexys_A7_100T_Official_Docs/` | Vendor references |
| `hdl/` | Synthesizable SystemVerilog and `.xdc` constraints |
| `sim/` | Testbenches and simulation outputs (waveforms, `.ppm` frame dumps) |
| `prototype/` | Python Game Model (`model/`, headless) and Look Prototype viewer (`look/`, pygame-ce); generates Step logs for comparison with HDL |
| `tools/` | Host-side scripts, such as `png2coe.py`, and the P2 web controller page (Web Serial) |
| `assets/` | Sprite art (`.png`) and generated `.coe` files |
| `evidence/` | Report evidence (waveforms, `.ppm` frames, board photos, report excerpts), named `<ObjectiveID>-<short-name>.<ext>`; logged in the development plan |
| `docs/adr/` | Architecture decision records, numbered `0001-slug.md` |
| `AGENTS.md`, `CLAUDE.md`, `docs/agents/` | Instructions for AI agents: issue tracker, triage labels, domain docs |

Create the subfolders when their first file is needed.

**Implementation home:** the team selected [romanmg00/FPGA](https://github.com/romanmg00/FPGA) and its reconciled interface contract as the project authority below course requirements. This folder holds the existing research/prototype and the agreed specification; code migration and updating the remote contract have not been performed during the discussion. See [[CS-256 Tron Agreed Specification 2026-10-20]].

## Team

As confirmed from the TAs’ instruction on 2026-10-20, the team is **Roman and Alan**. Earlier three-person ownership plans are superseded. See [[CS-256 Tron Development Plan#Ownership]] for the proposed two-person split and [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]] for confirmed decisions. One shared headless rules model in the team repository is selected; the current separate model implementations still need migration.

## Toolchain

- **Vivado (synthesis, implementation, simulation):** the team's shared tool is the remote KAUST workstation (`myws.kaust.edu.sa`), used through its web interface. Alan is also installing full Vivado on `alan-desktop` for local testing. Use the same Vivado version as the workstation, because IP cores (Clocking Wizard, Block Memory Generator) are tied to the version that generated them.
- **Vivado Lab (board programming and on-board debugging):** runs on each member's laptop, with the board attached (Alan: `alan-legion`, reached over SSH). Copy the `.bit` file, plus the `.ltx` probe file when the build includes ILA debug cores, from wherever it was built, then program the board locally.
- Prefer scripting Vivado Lab through its Tcl console (program, trigger, export captures as CSV) over operating its GUI.

## Rules

- **Specification authority (team decision, 2026-10-20):** course requirements and the TAs' strict-architecture instruction first, then the team repository's interface contract, reconciled with [[CS-256 Tron Team Decisions 2026-10-20#Live decision record]]. Local mechanics/glossary/plans mirror those decisions. Existing Python/HDL and the remote contract still need reconciliation; an old implementation does not override the meeting record. The Arena layout is a revisable working baseline, not a hard lock.

- Follow the course [class project handout](../cs256-fall-2026/classproject/README.md) and [sprite tips](../cs256-fall-2026/classproject/sprites/README.md) strictly, as confirmed by the team from its TAs’ recommendation on 2026-10-20. The **final game** uses a second Clocking Wizard plus counter divider for an approximately **60 Hz game clock**, output-aligned coordinates and early sprite-memory reads. [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md) supersedes the frame-enable proposal in ADR 0001. Clock-enable and delayed-stream alternatives remain historical research in [[CS-256 Official FPGA Coding Practices]].

- New notes use the vault's frontmatter and naming standard ([Metadata and File Standard](../../00-System/Planning/Metadata-and-File-Standard.md)), with a `CS-256` title prefix.
- When a game term is settled or changed, update the glossary in the same change. When a game rule is settled or changed, update the mechanics note.
- Code and generated files (`.sv`, `.xdc`, `.coe`, `.py`) do not need frontmatter.
