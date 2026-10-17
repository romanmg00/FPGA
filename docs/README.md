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

**Pending move:** Roman is setting up the team git repository. Once everyone has access, project files move there; until then, this folder is the working copy.

## Toolchain

- **Vivado (synthesis, implementation, simulation):** the team's shared tool is the remote KAUST workstation (`myws.kaust.edu.sa`), used through its web interface. Alan is also installing full Vivado on `alan-desktop` for local testing. Use the same Vivado version as the workstation, because IP cores (Clocking Wizard, Block Memory Generator) are tied to the version that generated them.
- **Vivado Lab (board programming and on-board debugging):** runs on each member's laptop, with the board attached (Alan: `alan-legion`, reached over SSH). Copy the `.bit` file, plus the `.ltx` probe file when the build includes ILA debug cores, from wherever it was built, then program the board locally.
- Prefer scripting Vivado Lab through its Tcl console (program, trigger, export captures as CSV) over operating its GUI.

## Rules

- Follow the course [class project handout](../cs256-fall-2026/classproject/README.md) and [sprite tips](../cs256-fall-2026/classproject/sprites/README.md) as the implementation baseline (user preference, 2026-10-15). Keep the divided game clock and output-aligned coordinates with early sprite-memory reads as the current baseline. Document the clock-enable and delayed-stream alternatives in [[CS-256 Official FPGA Coding Practices]] for future evaluation; manufacturer guidance informs both paths.

- New notes use the vault's frontmatter and naming standard ([Metadata and File Standard](../../00-System/Planning/Metadata-and-File-Standard.md)), with a `CS-256` title prefix.
- When a game term is settled or changed, update the glossary in the same change. When a game rule is settled or changed, update the mechanics note.
- Code and generated files (`.sv`, `.xdc`, `.coe`, `.py`) do not need frontmatter.
