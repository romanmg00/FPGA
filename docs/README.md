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
| `docs/design/` | VGA and Sprite Design Plan; Official FPGA Coding Practices (manufacturer guidance; superseded clock and pixel-pipeline comparisons are marked historical); UART input research and [prototype findings](design/CS-256%20UART%20Input%20Prototype%20Findings.md), including Icarus/XSim, routed timing/CDC and native IP Catalog evidence |
| `docs/plan/` | Development Plan (calendar, freezes, scope tiers, work list, verification approach) and the Repository Merge Plan |
| `docs/reviews/` | Opus 5.5 Architecture and Integration Review (read its parent-review reservations before adopting recommendations), Documentation Control Review, and the archived Integration Comparison |
| `docs/history/` | Game Overview (whiteboard concept), superseded TA game-clock email draft, and the import commit map |
| `docs/references/` | Nexys A7 research report, vendor datasheets (`datasheets/`), and official documentation links |
| `docs/agents/` | Instructions for AI agents: issue tracker, triage labels, domain docs. The root `AGENTS.md` and `CLAUDE.md` point here |
| `proyecto_final/` | Hardware: interface contract, SystemVerilog, testbenches |
| `prototipos/tron_fpga/` | Local Python prototype modelled on the hardware blocks (the Look Prototype, renamed from `prototipos/look/`): model (`model/`, headless), viewer (`juego/`, pygame-ce), tests and metrics. Revised to the agreed specification on 21 October 2026; choosing it as the shared model, and target Step logs, remain open |
| `prototipos/` (others) | Roman's prototypes and launcher, including the `tron/` viewer |
| `tools/` | Host-side scripts for candidate-art generation, VGA cycle modelling and desktop Vivado access |
| `assets/` | Sprite art (`.png`) and generated `.coe` files |
| `evidence/` | Retained experiment logs and metadata, currently the I2/X2 UART transport experiment; read each run's README for verification limits |

Create new folders when their first file is needed. Name report evidence with its Development Plan objective ID, such as `<ObjectiveID>-<short-name>.<ext>` or an objective-specific folder.

**Implementation home:** this repository, [romanmg00/FPGA](https://github.com/romanmg00/FPGA), is the team's shared HDL/model implementation home. Its interface contract (`proyecto_final/Contrato de interfaces game_top (CS 256).md`) must first be reconciled with the course requirements and the locked team agreement. The 20 October update of the contract adopts the agreed rules, inputs, clocks, Arena codes and two-person split, and marks the interfaces the specification leaves open as *Pendiente*; its earlier version is in `proyecto_final/deprecated/`. Until each pending interface is settled and recorded there, the agreed specification is the current team-rule authority and existing code describes only its own present behavior.

## Read and authority path

1. Start with this README and [CS-256 Tron Architecture and Documentation Map](CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md).
2. Read [CS-256 Tron Agreed Specification 2026-10-20](decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md) for the locked baseline and [CS-256 Tron Team Decisions 2026-10-20 — Live decision record](decisions/CS-256%20Tron%20Team%20Decisions%202026-10-20.md#live-decision-record) for decision provenance. The pre-meeting comparison later in the decision note is historical.
3. Use [CS-256 Tron Game Mechanics](domain/CS-256%20Tron%20Game%20Mechanics.md) as a topic index and [CS-256 Tron Glossary](domain/CS-256%20Tron%20Glossary.md) for terms; neither replaces the specification.
4. Read accepted ADRs and the relevant design guidance. For FPGA work, read [Official FPGA Coding Practices](design/CS-256%20Official%20FPGA%20Coding%20Practices.md) and the [interface contract's conventions](../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md#1-convenciones-generales). [ADR 0002](adr/0002-follow-ta-divided-game-clock.md) is the accepted game-clock decision; ADR 0001 is superseded.
5. Read implementation notes alongside the actual code. The last reviewed remote snapshot predates the agreement. `prototipos/tron_fpga/` was revised to the agreed rules on 21 October 2026; its tests check that Python model only, not HDL or board behavior.
6. Check verification plans and recorded evidence before claiming a feature works. [CS-256 Tron Development Plan](plan/CS-256%20Tron%20Development%20Plan.md) is tentative planning, not an implementation report.

## Reference index

Use this index to return to the relevant source before future work. The architecture map owns document authority and status; the descriptions below identify each reference's purpose. Plans, research, reviews and prototype results do not establish accepted interfaces or verified board behavior.

### Course, agreement and vocabulary

| Reference | Use it for |
|---|---|
| [Course project slides](../proyecto_final/cs256-project1-fall26.pdf) | Local course presentation cited by the interface contract. Course requirements and TA instructions take precedence. |
| [Course project handout](../../cs256-fall-2026/classproject/README.md) and [sprite tips](../../cs256-fall-2026/classproject/sprites/README.md) | Required architecture, VGA timing, drawing logic, sprite memories and early reads. These sibling-repository links require a separate course checkout; see Rules below. |
| [Architecture and Documentation Map](CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md) | Authority, ownership, document status and objective traceability. Some implementation/evidence entries describe earlier snapshots; check the current code and evidence guides below. |
| [Agreed Specification, 20 October](decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md) | Locked team baseline for rules, inputs, layout, clocks and work division. |
| [Team Decisions, 20 October](decisions/CS-256%20Tron%20Team%20Decisions%202026-10-20.md#live-decision-record) | Locked decision provenance; the comparison following the live record is historical. |
| [Locked-record integrity and old paths](decisions/README.md) | SHA-256 values, tags and relocation map. Never edit the files in this folder. |
| [ADR 0002: divided game clock](adr/0002-follow-ta-divided-game-clock.md) | Accepted second-Clocking-Wizard/divider architecture and its game/service/render boundary. |
| [Glossary](domain/CS-256%20Tron%20Glossary.md) | Canonical vocabulary for notes, code comments, issues and reports. |
| [Game Mechanics](domain/CS-256%20Tron%20Game%20Mechanics.md) | Topic links into the locked specification; a derived index. |

### FPGA design and verification planning

| Reference | Use it for |
|---|---|
| [CS-256 Official FPGA Coding Practices](design/CS-256%20Official%20FPGA%20Coding%20Practices.md) | Source-backed guidance on clocks and constraints, CDC, BRAM and sprite latency, RTL/reset/input handling, assets, pins and implementation reports. Read before FPGA work alongside the course material, ADR 0002 and contract conventions. Historical clock-enable and delayed-stream comparisons are marked superseded; proposed interfaces still need validation. |
| [VGA and Sprite Design Plan](design/CS-256%20VGA%20and%20Sprite%20Design%20Plan.md) | Course-aligned raster, output coordinates, early ROM reads, sprite conversion and planned video checks. Its alternative-pipeline appendix is historical. |
| [UART Input Path Research](design/CS-256%20UART%20Input%20Path%20Research.md) | Proposed browser/USB-UART receiver, command encoding, ordered CDC transport, P1 input handling and verification plan; open choices remain proposals. |
| [UART Input Prototype Findings](design/CS-256%20UART%20Input%20Prototype%20Findings.md) | Icarus/XSim results, routed timing/CDC, native IP Catalog inspection, ordering/Start counterexamples and queue limits. Board/game integration remains unverified; experiment results do not approve the interface. |
| [Development Plan](plan/CS-256%20Tron%20Development%20Plan.md) | Objective IDs, scope tiers, ownership, tentative schedule, independent checks, Step-log comparisons and report evidence. |

### Implementation, prototypes, tools and evidence

| Reference | Use it for |
|---|---|
| [Hardware README](../proyecto_final/README.md) | Current HDL files, bring-up progress and simulation entry points. |
| [Interface contract](../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md) | SystemVerilog conventions, module interfaces, shared constants and ownership. Unsettled interfaces are marked **Pendiente**; reconcile with the course and locked baseline before implementation. |
| [Alan's hardware-modelled Tron guide](../prototipos/tron_fpga/README.md) | Separate pygame-ce environment, viewer controls, tests, art workflow and headless model. Revised to the agreement, but not yet selected as the shared model. |
| [Roman's prototype instructions](../README.md#prototipos-en-python) | Launcher, pygame environment and `prototipos/tron/` viewer controls. Check each prototype's own behavior against the agreement. |
| [Prototype metrics](../prototipos/tron_fpga/metrics/latest.md) and [CSV](../prototipos/tron_fpga/metrics/look-metrics.csv) | Historical PC-viewer measurements and hardware estimates from 17 October; not target HDL or board evidence. |
| [UART transport experiment guide](../proyecto_final/prototypes/uart_input/README.md) | Throwaway SystemVerilog experiment, runners and reproduction instructions; separate from the game's accepted interfaces. |
| [I2/X2 UART evidence](../evidence/I2-uart-input-prototype/README.md) | Retained Icarus/XSim logs, routed reports, IP Catalog screenshots, source hashes and model analysis, with explicit verification limits. |
| [Desktop Vivado launcher setup](../tools/vivado/README.md) | Administrator-installed launcher, scoped container access and invocation checks. Read alongside the Toolchain policy below. |
| [Candidate-art generator](../tools/make_candidate_art.py) and [VGA cycle model](../tools/vga_out_tb_cycle_model.py) | Host-side asset generation and cycle-level exploration; inspect the scripts before use. |

### Board, FPGA and peripheral references

| Reference | Use it for |
|---|---|
| [Official documentation bundle](references/Nexys_A7_100T_Official_Docs/README.md) and [vendor link list](references/Nexys_A7_100T_Official_Docs/OFFICIAL_LINKS.txt) | Digilent board manual/schematic, AMD device/XADC guides, sensor sources and categorized `.url` shortcuts. The bundle README mentions a downloader that is absent from this checkout; use the retained links and files. |
| [Nexys A7 game research report](references/Nexys_A7_Game_Research_Report.md) and [PDF](references/Nexys_A7_Game_Research_Report.pdf) | Broad board capabilities and game-development research. Generic video modes and architectures do not override this project's course baseline. |
| [DS180: 7-series overview](references/datasheets/DS180_7_Series_FPGA_Overview.pdf) | Cached vendor reference for device resources. |
| [DS181: Artix-7 DC/AC characteristics](references/datasheets/DS181_Artix_7_DC_AC_Switching.pdf) | Cached vendor reference for electrical and speed-grade limits. |
| [Digilent master XDC copy](references/datasheets/Nexys-A7-100T-Master.xdc) and [root XDC](../nexys-a7-100t-master.xdc) | Pin-reference material and repository constraints. Check actual top-level ports and enabled constraints before using either copy. |
| [ADXL362 accelerometer](references/datasheets/adxl362.pdf) and [ADT7420 temperature sensor](references/datasheets/adt7420.pdf) | Cached peripheral datasheets for optional board exploration; not requirements for the agreed Tron controls. |

### Reviews, migration and historical material

| Reference | Use it for |
|---|---|
| [Documentation Control Review, 20 October](reviews/CS-256%20Tron%20Documentation%20Control%20Review%202026-10-20.md) | Audit findings, authority corrections and validation recorded at that date. |
| [Opus 5.5 Architecture and Integration Review](reviews/CS-256%20Tron%20Opus%205.5%20Architecture%20and%20Integration%20Review.md) | Findings against pinned repository snapshots and proposed integration options. Read its **Parent review and adoption limits** before adopting recommendations. |
| [Repository Merge Plan](plan/CS-256%20Tron%20Repository%20Merge%20Plan.md) | Import execution record, path mapping, procedure and rollback. Its recorded remaining steps are historical status, not authorization to run them. |
| [Integration Comparison](reviews/CS-256%20Tron%20Integration%20Comparison.md) | Archived pre-meeting comparison; its recommendations and “Already agreed” labels are not current authority. |
| [ADR 0001: pixel clock with frame enable](adr/0001-pixel-clock-with-frame-enable.md) | Superseded clock proposal and source rationale; ADR 0002 selects the final architecture. |
| [TA game-clock email draft](history/CS-256%20TA%20Email%20-%20Game%20Clock.md) | Superseded approval-request draft; no frame-enable approval request remains pending. |
| [Game Overview](history/CS-256%20Tron%20Game%20Overview.md) | Historical whiteboard concept and rubric context. |
| [Import commit map](history/game-research-commit-map.txt) | Old-to-imported commit mapping for tracing repository history. |
| [Old root README](../deprecated/README-2026-10-11.md), [old hardware README](../proyecto_final/deprecated/README-2026-10-11.md) and [old interface contract](../proyecto_final/deprecated/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29%202026-10-11.md) | Preserved pre-agreement versions; do not implement their superseded rules. |
| [Zombie Crossing optional-art guide](../prototipos/zombie_crossing/assets/LEEME.md) | Asset filenames for an earlier prototype idea, unrelated to the selected Tron design. |

### Agent workflow

| Reference | Use it for |
|---|---|
| [AGENTS.md](../AGENTS.md) and [CLAUDE.md](../CLAUDE.md) | Shared repository instructions and the Claude import entry point. |
| [Domain-document instructions](agents/domain.md) | Required reading order, vocabulary and conflict handling. |
| [Issue-tracker instructions](agents/issue-tracker.md) and [triage labels](agents/triage-labels.md) | GitHub Issues workflow and the five canonical triage labels. |

## Team

As confirmed from the TAs’ instruction on 2026-10-20, the team is **Roman and Alan**. Earlier three-person ownership plans are superseded. See [CS-256 Tron Development Plan — Ownership](plan/CS-256%20Tron%20Development%20Plan.md#ownership) for the proposed two-person split and [CS-256 Tron Team Decisions 2026-10-20 — Live decision record](decisions/CS-256%20Tron%20Team%20Decisions%202026-10-20.md#live-decision-record) for confirmed decisions. One shared headless rules model in the team repository is selected; the current separate model implementations still need migration.

## Toolchain

- **Vivado (synthesis, implementation, simulation):** the team's shared tool is the remote KAUST workstation (`myws.kaust.edu.sa`), used through its web interface. Alan's desktop also has full Vivado **2025.2** in the existing Ubuntu container. **For unattended desktop/agent runs, use the verified fixed-container launcher in [tools/vivado/README.md](../tools/vivado/README.md)** before requesting credentials; the UART runner selects it automatically. The launcher runs as UID/GID 1000 with privilege escalation disabled. Use the same Vivado version as the workstation, because IP cores (Clocking Wizard, Block Memory Generator) are tied to the version that generated them; desktop/workstation version parity has not been established here.
- **Vivado Lab (board programming and on-board debugging):** runs on each member's laptop, with the board attached (Alan: `alan-legion`, reached over SSH). Copy the `.bit` file, plus the `.ltx` probe file when the build includes ILA debug cores, from wherever it was built, then program the board locally.
- Prefer scripting Vivado Lab through its Tcl console (program, trigger, export captures as CSV) over operating its GUI.

## Rules

- **Authority:** course requirements and the TAs' strict-architecture instruction govern the project. The locked [CS-256 Tron Agreed Specification 2026-10-20](decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md) is the current team decision baseline. The team repository's interface contract is the selected implementation contract only after it incorporates that baseline; its older rules do not override the agreement. Existing code documents current behavior, not intended behavior. See the [CS-256 Tron Architecture and Documentation Map](CS-256%20Tron%20Architecture%20and%20Documentation%20Map.md) for ownership and status.

- Follow the course [class project handout](../../cs256-fall-2026/classproject/README.md) and [sprite tips](../../cs256-fall-2026/classproject/sprites/README.md) strictly, as confirmed by the team from its TAs’ recommendation on 2026-10-20. Links into `cs256-fall-2026/` resolve only when this repository is cloned beside the course repository, as in the vault's `CS-256/` folder. The **final game** uses a second Clocking Wizard plus counter divider for an approximately **60 Hz game clock**, output-aligned coordinates and early sprite-memory reads. [ADR 0002](adr/0002-follow-ta-divided-game-clock.md) supersedes the frame-enable proposal in ADR 0001. Clock-enable and delayed-stream alternatives remain historical research in [CS-256 Official FPGA Coding Practices](design/CS-256%20Official%20FPGA%20Coding%20Practices.md).

- The requested **83.46 MHz pixel clock** is separate from the approximately **60 Hz frame refresh** and the approximately **60 Hz game-state clock**. The divider, fast Arena service, and video pipeline have different responsibilities; do not describe the divided game clock as display-only.

- New notes use the Obsidian vault's frontmatter and naming standard ([Metadata and File Standard](../../../00-System/Planning/Metadata-and-File-Standard.md)), with a `CS-256` title prefix.
- When a game term is settled or changed, update the glossary. The 20 October records in `docs/decisions/` stay byte-identical: record a rule change as a new ADR (0003 onward) or a dated successor specification, then update Mechanics' topic links if needed.
- Code and generated files (`.sv`, `.xdc`, `.coe`, `.py`) do not need frontmatter.
