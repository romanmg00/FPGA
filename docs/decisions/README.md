# Locked decision records

The two records in this folder were locked at the end of the team discussion on 20 October 2026. **They are never edited, links included.** Record a later decision as a new ADR in [`../adr/`](../adr/) (0003 onward) or as a new dated record beside these.

| Record | Role | SHA-256 |
|---|---|---|
| `CS-256 Tron Agreed Specification 2026-10-20.md` | Current team-rule authority | `cd524e90200623ec4ccb39a3431deb5aa37e9615ae6eb78ea81d3af2dacafec2` |
| `CS-256 Tron Team Decisions 2026-10-20.md` | Question-by-question provenance (Q1–Q40) | `ff9c1c6223de3a47ebef67f17751bddf940bddf080b2da0da8af1d214d029269` |

Check them from the repository root:

```bash
sha256sum docs/decisions/"CS-256 Tron Agreed Specification 2026-10-20.md" docs/decisions/"CS-256 Tron Team Decisions 2026-10-20.md"
```

## Tags

- `research/decisions-2026-10-20`: the decision-time snapshot. It is the last imported `Game_research` commit before the documentation restructure, plus the Markdown captured at 14:31 that day. Files outside that capture are as of the earlier commit, not decision-time bytes.
- `research/research-pre-merge`: the `Game_research` working tree as imported on 20 October 2026.

Commit hashes cited in the imported notes were rewritten by the import; [`../history/game-research-commit-map.txt`](../history/game-research-commit-map.txt) maps the original hashes to the imported ones.

## Old paths cited by the locked records

The records cite files by their location in the Obsidian vault before the import, as `[[CS-256/Game_research/…]]` wikilinks and as absolute `…/CS-256/Game_research/…` paths in commands. Those links are historical. In this repository the files are at:

| Path cited in the locked records (under `CS-256/Game_research/`) | Path in this repository |
|---|---|
| `README` | `docs/README.md` |
| `prototype/README` | `prototipos/look/README.md` |
| `prototype/` (including the `cd` and `requirements.txt` commands) | `prototipos/look/` |
| `prototype/look/app.py`, `candidates.py`, `font.py`, `hud.py` | `prototipos/look/look/` (same names) |
| `prototype/model/lfsr.py`, `params.py`, `rewards.py`, `steering.py` | `prototipos/look/model/` (same names) |
| `Datasheets/Nexys-A7-100T-Master.xdc` | `docs/references/datasheets/Nexys-A7-100T-Master.xdc` (same pins as the root `nexys-a7-100t-master.xdc`) |
| Notes cited by name, such as `[[CS-256 Tron Glossary]]` | Same filename under `docs/`; see the layout in [`../README.md`](../README.md) |

Links into `CS-256/cs256-fall-2026/` point at the course repository, which is not part of this repository.
