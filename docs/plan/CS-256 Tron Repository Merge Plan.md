---
schema_version: 1
id: cs256-tron-repository-merge-plan-20261020
title: CS-256 Tron Repository Merge Plan
type: plan
subject: CS-256
status: active
created_at: "2026-10-20T15:08:18"
updated_at: "2026-10-20T19:33:29"
term: 2026-fall
sources:
  - "[[CS-256 Tron Opus 5.5 Architecture and Integration Review]]"
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Architecture and Documentation Map]]"
  - "[[00-System/Planning/Metadata-and-File-Standard]]"
review_status: unreviewed
tags:
  - tron
  - repository
  - plan
---

# CS-256 Tron Repository Merge Plan

> [!info] Executed on 20 October 2026, with changes
> The team approved the import, and Alan ran steps A–D on branch `integrate/game-research`. Pushing it and the pull request to `main` (step E) are pending, and step F, converting the vault folder, has not been done. Where the procedure below differs from what was run, [[#Execution record, 2026-10-20]] is authoritative. The procedure text is kept as drafted.

This plan merges the local `CS-256/Game_research` repository into the team repository [romanmg00/FPGA](https://github.com/romanmg00/FPGA). Roman's `main` stays the canonical branch. Our decisions, ADRs, design notes, reviews, Look Prototype, tools and art are **merged with their Git history, not discarded**.

## Execution record, 2026-10-20

**Decisions as settled by the team.** M1 = A (history-preserving import through a pull request merged with a merge commit). M2 changed: the team treats the repository as team-only, so the vendor datasheets and the duplicate XDC are **kept**, under `docs/references/datasheets/`, and the commit author identity is kept as is (`AIF31`). M3 = A (locked records frozen). M4: the merged repository is cloned at `CS-256/FPGA/` in the vault, beside `Game_research`; step F waits until after the merge. M5 = A (one environment per viewer). The optional launcher entry and `CODEOWNERS` were not added: `CODEOWNERS` cannot require both members' approval.

**What was run, and how it differs from the procedure.**

- **Step A, without touching `Game_research`.** Its repository, permissions and working tree were left unchanged. Before anything else, `~/cs256-backups/` received a full tarball of the folder (including the ignored renders in `prototype/out/`), a verified bundle of its history, and a copy of the `/tmp` snapshot with its manifest, all of whose hashes matched. The two new commits were made in a scratch clone: the snapshot overlay on `6ef8104` (tag `decisions-2026-10-20`), then the live working tree read through `git --work-tree` (tag `research-pre-merge`). File lists and contents matched the working tree exactly.
- **Step B, one filter pass.** `git-filter-repo` v2.47.0 (the upstream script) ran with only the path renames and `--tag-rename ':research/'`. There was no exclusion and no mailmap. The research report needed **two full-filename renames**: `Nexys_A7_Game_Research_Report.` is not a prefix match and would have left both files at the root. A single pass produces one commit map, published as `docs/history/game-research-commit-map.txt`; filter-repo's second map is already cumulative, so joining two maps would have been wrong. Every historical path landed in the target layout.
- **Step C.** Merged cleanly into a clone of `romanmg00/FPGA` `main` at `f5cb82c`, with no change to Roman's paths before step D.
- **Step D.** Follow-up commits:
  - the viewer and the art generator (`tools/make_candidate_art.py` also needed its `sys.path` fixed);
  - relative links, each resolved from its old location and made relative from its new one;
  - the team-repository read path and agent instructions;
  - the locked-records index and the commit map;
  - the root README section and `.gitignore` entries;
  - this record.

  Course links point at the sibling `cs256-fall-2026/` checkout, so they resolve in the vault but not on GitHub.
- **Smoke checks** (they check the move, not the agreed rules):
  - our 21 tests pass under pygame-ce 2.5.8;
  - Roman's 35 tests pass under pygame 2.6.1, in a separate environment;
  - the viewer starts with all 32 candidate PNGs;
  - every relative Markdown link resolves.

**Acceptance checks that replace the draft ones.**

- Check the two locked files by name against their full hashes. The `docs/decisions/*.md` glob now also matches `README.md`.
- The empty-diff check on Roman's paths holds only before step D. After D, the only intended changes to his files are the README section and the `.gitignore` entries.
- Branch pushes do not publish tags, so `research/decisions-2026-10-20` and `research/research-pre-merge` are pushed explicitly, and nothing else: `git push --atomic --no-follow-tags origin` with the branch and the two tag refspecs.

**Vault side effects while both folders exist.** `CS-256/FPGA/` sits in the vault beside `CS-256/Game_research/`. Until step F:

- Every device's `.stignore` should exclude `/CS-256/FPGA/.git`, as step F already requires for `Game_research/.git`, and only one machine runs Git.
- The two folders share 24 note filenames, so Obsidian may resolve a bare wikilink to either copy. The current notes are the ones in `CS-256/FPGA/`.

## Summary

- **Result.** One repository, `romanmg00/FPGA` `main`. It contains Roman's existing tree unchanged, plus `docs/` (decisions, ADRs, design, plans, reviews), `prototipos/look/` (our prototype), `tools/` and `assets/`.
- **Method.** Filter a throwaway copy of our repository. Merge it into a branch of Roman's repository with `--allow-unrelated-histories`. Add small follow-up commits, open a pull request, and merge it with **"Create a merge commit"**.
- **Locked records stay byte-identical**, verified by SHA-256: specification `cd524e90…`, decision record `ff9c1c62…`. Their historical links stay resolvable through tags and a path map.
- **Nothing is lost.** Material kept out of the public repository stays in a Git bundle, in archive tags and in an ignored `local/` folder.
- **Roles.** Alan executes steps A–D and F. Roman reviews and merges the pull request (step E). Both approve M1–M5.

## Decisions to approve before executing

| Decision | Options | Recommendation |
|---|---|---|
| **M1. Integration method** | (A) History-preserving import, as described here. (B) `git subtree`, which keeps our repository alive and syncing and therefore leaves two sources of truth. (C) Copying files without history, which loses provenance and commit references. | **A** |
| **M2. What may be published** | (A) Exclude the vendor PDFs (official links already exist), map the personal author email to a GitHub no-reply address, and keep workstation hostnames (low risk). (B) Import everything verbatim. (C) Make the repository private; Roman's call. | **A.** Roman also settles one rule for course material: his `.gitignore` says course PDFs are not uploaded, yet `proyecto_final/cs256-project1-fall26.pdf` is committed |
| **M3. Locked records** | (A) Frozen byte-identical; historical links resolve through tags and a path map. (B) A link-only amendment with before and after hashes recorded, which creates a second version of a locked artifact. | **A** |
| **M4. Where the working copy lives** | (A) The vault's `CS-256/Game_research` becomes the clone of the merged repository, with `.git` excluded from Syncthing and one machine doing every Git operation. (B) A clone outside the vault, with only a pointer note in the vault. | **A.** It keeps the vault's folder policy and keeps the decisions in Obsidian |
| **M5. Python environments** (engineering) | (A) A separate requirements file and virtual environment per viewer. (B) Standardize on `pygame-ce` now. | **A** first; then B if Roman's viewer runs under `pygame-ce` |

## Current state of both repositories

Verified on 2026-10-20 at 15:08 (+03:00). Re-check these facts immediately before executing.

| Fact | Consequence for the plan |
|---|---|
| `Game_research` is a local Git repository with no remote: branch `main`, 15 commits from `9c8f9cc` to `6ef8104` (17 October). It has uncommitted edits to 15 tracked files, plus untracked new notes: the locked records, ADR 0002, the Map, the reviews and this plan. | The agreed specification, the decision record and ADR 0002 are **in no commit**. |
| The decision-time Markdown, as it was before the 14:34 documentation restructure, exists only in `/tmp/cs256-tron-docs-before-20261020/`. Its hashes are listed in `/tmp/cs256-tron-docs-before-20261020.txt`. | **`/tmp` is cleared on reboot.** Step A commits it first. |
| These paths are read-only: `.git` and some of its subfolders, `assets/`, `docs/adr/`, `docs/agents/`, `prototype/` and its subfolders, and `tools/`. | Steps A and F need write access restored deliberately. Re-apply the safeguard afterwards if wanted. |
| `romanmg00/FPGA` is **public**. `main` is at `f5cb82c`, it has 32 files and no other branch or pull request, and it allows merge, squash and rebase merges. | Publishing rules (M2) apply. Choose the merge-commit method explicitly. |
| Root-level names that collide: only `README.md` and `.gitignore`. Roman has no `docs/`, `tools/`, `assets/`, `AGENTS.md` or `CLAUDE.md`. | Renaming our two colliding files removes every merge conflict. |
| `Datasheets/` holds four vendor PDFs, about 4.8 MB (AMD DS180 and DS181, ADI ADT7420 and ADXL362), and an XDC whose pin lines equal Roman's root XDC. | These are left out of the published history. Official links already exist in `Nexys_A7_100T_Official_Docs/`. |
| Our 15 commits carry a personal author email address. | It is remapped during filtering (M2). |
| The vault is synced by **Syncthing**. `.stignore` does not exclude `.git`, and `.stversions/` holds versions of `Game_research/.git/index`. | Git metadata is being synced today. Exclude it before converting the folder (step F). |
| `prototype/look/app.py` L25–L26 finds `assets/` as a sibling of the prototype folder. `tools/make_candidate_art.py` writes to the repository root's `assets/candidates/`. | One-line path fix after the move (step D). |
| Roman requires `pygame>=2.5`; we require `pygame-ce>=2.5`. Both provide the `pygame` module. | Use separate environments (M5). |
| The locked decision record holds 17 vault-path links (13 distinct targets) into `CS-256/Game_research/…`. | These become historical pointers. A path map preserves them (M3). |
| `git-filter-repo` is not installed. This machine has Git 2.53. | Prerequisite. |

## Merge principles

1. **Roman's `main` is canonical.** All changes arrive through one pull request that Roman reviews. Merge it with a merge commit, never squash or rebase, so the imported commits survive.
2. **Lossless.** Every `Game_research` path gets a destination or a listed exclusion. History is kept. Excluded material stays in the bundle, the archive tags and `local/`.
3. **Roman's paths stay put:** `README.md`, `nexys-a7-100t-master.xdc`, `proyecto_final/` (including the interface contract) and `prototipos/`. New material goes into new folders.
4. **Locked records are never edited**, links included.
5. **Decisions are first-class.** `docs/decisions/` holds the locked records and `docs/adr/` the ADRs. Later team decisions (D1–D9) become ADR 0003 onward. Each open decision is tracked as a GitHub issue until its ADR closes it, per [docs/agents/issue-tracker.md](../agents/issue-tracker.md).
6. **Filenames are unchanged.** Obsidian resolves name-only wikilinks anywhere in the vault, so moving notes into `docs/` subfolders keeps those links working.

## Target structure

```text
FPGA/                                    romanmg00/FPGA, main (canonical)
├── README.md                            Roman's; add a "Documentation and decisions" section → docs/README.md
├── AGENTS.md, CLAUDE.md                 from Game_research (agent read path); paths updated
├── .gitignore                           Roman's, plus Game_research entries and local/
├── nexys-a7-100t-master.xdc             Roman's; the single vendor XDC reference
├── docs/                                from Game_research, with history
│   ├── README.md                        Game_research README: authority path, toolchain, rules; plain Markdown index
│   ├── CS-256 Tron Architecture and Documentation Map.md
│   ├── decisions/                       LOCKED, byte-identical
│   │   ├── CS-256 Tron Agreed Specification 2026-10-20.md
│   │   ├── CS-256 Tron Team Decisions 2026-10-20.md
│   │   └── README.md                    new: status, SHA-256s, tags, evidence-path map
│   ├── adr/                             0001 superseded · 0002 accepted · 0003+ for D1–D9
│   ├── domain/                          Glossary · Game Mechanics (index)
│   ├── design/                          VGA and Sprite Design Plan · Official FPGA Coding Practices
│   ├── plan/                            Development Plan · this merge plan
│   ├── reviews/                         Opus 5.5 review · Documentation Control Review · Integration Comparison (archived)
│   ├── history/                         Game Overview · TA Email (superseded) · import commit map
│   ├── references/                      Nexys research report (.md, .pdf) · Nexys_A7_100T_Official_Docs/ (links)
│   └── agents/                          issue tracker · triage labels · domain read path
├── proyecto_final/                      Roman's hardware root, unchanged; rtl/ sim/ ip/ constraints/ scripts/ added later
├── prototipos/                          Roman's prototypes, unchanged
│   ├── tron/                            Roman's viewer; becomes an adapter over model/ after decision D1
│   ├── look/                            our Look Prototype, intact (look/, model/, tests/, metrics/, README, requirements)
│   └── lanzador.py, correr_pruebas.py, slither/, mountain_crash/, zombie_crossing/
├── model/                               after D1: shared model, via git mv from prototipos/look/model (if D1 = A)
├── tools/                               make_candidate_art.py, vga_out_tb_cycle_model.py; later png2coe.py
├── assets/                              candidates/*.png; later native art and generated .coe
├── web/                                 later: Web Serial controller page
└── local/                               ignored, never published: vendor datasheets and the duplicate XDC
```

Our prototype goes to `prototipos/look/`, following Roman's `prototipos/<game>/` convention, and is not split at import time. Moving its model to `model/` waits for decision D1, so the import does not prejudge it. The hardware subfolder layout and module owners are in [[CS-256 Tron Opus 5.5 Architecture and Integration Review#4.4 Proposed canonical repository structure and model governance]].

## Path map

| `Game_research` path | `FPGA` destination | Treatment |
|---|---|---|
| `CS-256 Tron Agreed Specification 2026-10-20.md`, `CS-256 Tron Team Decisions 2026-10-20.md` | `docs/decisions/` | Locked; byte-identical; hashes checked |
| `docs/adr/0001-…`, `docs/adr/0002-…` | `docs/adr/` (same) | 0001 superseded, 0002 accepted |
| `docs/agents/*` | `docs/agents/` (same) | Update path references |
| `README.md` | `docs/README.md` | Avoids the root clash; becomes the documentation entry point |
| `CS-256 Tron Architecture and Documentation Map.md` | `docs/` | Update the authority path (step D, item 2) |
| `CS-256 Tron Glossary.md`, `CS-256 Tron Game Mechanics.md` | `docs/domain/` | — |
| `CS-256 VGA and Sprite Design Plan.md`, `CS-256 Official FPGA Coding Practices.md` | `docs/design/` | — |
| `CS-256 Tron Development Plan.md`, `CS-256 Tron Repository Merge Plan.md` | `docs/plan/` | — |
| `CS-256 Tron Opus 5.5 Architecture and Integration Review.md`, `CS-256 Tron Documentation Control Review 2026-10-20.md`, `CS-256 Tron Integration Comparison.md` | `docs/reviews/` | The Comparison stays marked archived |
| `CS-256 Tron Game Overview.md`, `CS-256 TA Email - Game Clock.md` | `docs/history/` | Historical status kept |
| `Nexys_A7_Game_Research_Report.md` and `.pdf`, `Nexys_A7_100T_Official_Docs/` | `docs/references/` | Our own report plus link files |
| `AGENTS.md`, `CLAUDE.md` | Root (same) | Update paths |
| `.gitignore` | `prototipos/look/.gitignore` | Change its entry `prototype/out/` to `out/` |
| `prototype/**` | `prototipos/look/**` | Intact; one-line `ASSETS` path fix |
| `tools/*.py`, `assets/candidates/*.png` | `tools/`, `assets/candidates/` (same) | — |
| `Datasheets/*.pdf` | **Not published** | Removed from the imported history; kept in the bundle and `local/datasheets/` |
| `Datasheets/Nexys-A7-100T-Master.xdc` | **Not published** | Same pins as Roman's root XDC; kept in the bundle and `local/` |
| `prototype/out/` (ignored renders) | Ignored `prototipos/look/out/` | Local only |

Roman's tree is unchanged except for one added `README.md` section, added `.gitignore` entries, and optionally a `look` entry in `prototipos/lanzador.py`, which he reviews.

## Procedure

### Prerequisites

- **Tools:** Git (2.53 here), `git-filter-repo` (for example `python3 -m pip install --user git-filter-repo` or the distribution package), and GitHub access to push a branch: Roman adds Alan as a collaborator, or Alan works from a fork.
- **Decisions:** M1–M5 approved, except step A, which can run now.
- **Machines:** all vault devices synced and idle, with Obsidian closed during step F.
- **Workspace:** use scratch directories outside the synced vault, here `~/cs256-merge` and `~/cs256-backups`.

```bash
GR="/path/to/vault/CS-256/Game_research"   # set to the real vault path
mkdir -p ~/cs256-merge ~/cs256-backups
```

### A. Preserve the decision-time evidence

**Urgent, and safe to run before any decision.** It turns the `/tmp` snapshot and the current working tree into two local commits, then writes a backup bundle. Nothing leaves the machine.

```bash
chmod -R u+w "$GR/.git"                      # lift the read-only safeguard on Git metadata
git -C "$GR" worktree add -b baseline-snapshot ~/cs256-merge/snap HEAD
rsync -a /tmp/cs256-tron-docs-before-20261020/ ~/cs256-merge/snap/
cd ~/cs256-merge/snap
sha256sum "CS-256 Tron Agreed Specification 2026-10-20.md" "CS-256 Tron Team Decisions 2026-10-20.md"
git add -A && git commit -m "Decision-time snapshot of the locked agreement, 2026-10-20 14:21"
git tag decisions-2026-10-20
cd "$GR"
git reset --soft baseline-snapshot           # main now points at the snapshot; the working tree is untouched
git add -A && git commit -m "Documentation control restructure, map, reviews and merge plan, 2026-10-20"
git tag research-pre-merge
git worktree remove ~/cs256-merge/snap
git bundle create ~/cs256-backups/game-research-2026-10-20.bundle --all
```

**Check:**
- The two hashes start with `cd524e90` and `ff9c1c62`.
- `git -C "$GR" status --short` is empty.
- `git bundle verify ~/cs256-backups/game-research-2026-10-20.bundle` succeeds.

The tag `decisions-2026-10-20` records exactly what the decision record cited at decision time; `research-pre-merge` records today's state.

### B. Build an importable copy

This works on a clone; the original repository is not changed. `mailmap.txt` holds one line mapping the old author identity to the chosen public identity.

```bash
git clone --no-local "$GR" ~/cs256-merge/research && cd ~/cs256-merge/research
# Pass 1: remove vendor PDFs and the duplicate XDC from all history; remap the author identity
git filter-repo --invert-paths --path Datasheets/ --path prototype/out/ --mailmap ~/cs256-merge/mailmap.txt
cp .git/filter-repo/commit-map ~/cs256-merge/commit-map-pass1.txt
# Pass 2: move every path into the target layout and prefix the imported tags
git filter-repo --force --tag-rename ':research/' \
  --path-rename 'prototype/:prototipos/look/' \
  --path-rename '.gitignore:prototipos/look/.gitignore' \
  --path-rename 'README.md:docs/README.md' \
  --path-rename 'CS-256 Tron Agreed Specification 2026-10-20.md:docs/decisions/CS-256 Tron Agreed Specification 2026-10-20.md' \
  --path-rename 'CS-256 Tron Team Decisions 2026-10-20.md:docs/decisions/CS-256 Tron Team Decisions 2026-10-20.md' \
  --path-rename 'CS-256 Tron Architecture and Documentation Map.md:docs/CS-256 Tron Architecture and Documentation Map.md' \
  --path-rename 'CS-256 Tron Glossary.md:docs/domain/CS-256 Tron Glossary.md' \
  --path-rename 'CS-256 Tron Game Mechanics.md:docs/domain/CS-256 Tron Game Mechanics.md' \
  --path-rename 'CS-256 VGA and Sprite Design Plan.md:docs/design/CS-256 VGA and Sprite Design Plan.md' \
  --path-rename 'CS-256 Official FPGA Coding Practices.md:docs/design/CS-256 Official FPGA Coding Practices.md' \
  --path-rename 'CS-256 Tron Development Plan.md:docs/plan/CS-256 Tron Development Plan.md' \
  --path-rename 'CS-256 Tron Repository Merge Plan.md:docs/plan/CS-256 Tron Repository Merge Plan.md' \
  --path-rename 'CS-256 Tron Opus 5.5 Architecture and Integration Review.md:docs/reviews/CS-256 Tron Opus 5.5 Architecture and Integration Review.md' \
  --path-rename 'CS-256 Tron Documentation Control Review 2026-10-20.md:docs/reviews/CS-256 Tron Documentation Control Review 2026-10-20.md' \
  --path-rename 'CS-256 Tron Integration Comparison.md:docs/reviews/CS-256 Tron Integration Comparison.md' \
  --path-rename 'CS-256 Tron Game Overview.md:docs/history/CS-256 Tron Game Overview.md' \
  --path-rename 'CS-256 TA Email - Game Clock.md:docs/history/CS-256 TA Email - Game Clock.md' \
  --path-rename 'Nexys_A7_Game_Research_Report.:docs/references/Nexys_A7_Game_Research_Report.' \
  --path-rename 'Nexys_A7_100T_Official_Docs/:docs/references/Nexys_A7_100T_Official_Docs/'
cp .git/filter-repo/commit-map ~/cs256-merge/commit-map-pass2.txt
git ls-files > ~/cs256-merge/imported-paths.txt
```

**Check:**
- `imported-paths.txt` matches the [[#Path map]] exactly.
- `git log --all --name-only --format= | grep -c '^Datasheets/'` prints 0.
- `git log --format='%an <%ae>' | sort -u` shows only the public identity.
- `git tag` lists `research/decisions-2026-10-20` and `research/research-pre-merge`.

If anything is wrong, delete `~/cs256-merge/research` and repeat from the clone.

Join the two commit maps into one table from original to imported hashes, for example with a short script. It becomes `docs/history/game-research-commit-map.txt` in step D, which keeps references such as the metrics baseline at commit `69842fc` traceable.

### C. Merge into a branch of Roman's repository

```bash
git clone https://github.com/romanmg00/FPGA.git ~/cs256-merge/fpga && cd ~/cs256-merge/fpga
git switch -c integrate/game-research
git fetch ~/cs256-merge/research 'refs/heads/main:refs/remotes/research/main' 'refs/tags/research/*:refs/tags/research/*'
git merge --allow-unrelated-histories --no-ff research/main \
  -m "Import Game_research with history: locked decisions, ADRs, design notes, Look Prototype, tools and assets"
```

**Check:**
- The merge completes without conflicts.
- `sha256sum docs/decisions/*.md` matches the step A hashes.
- `git diff --stat origin/main HEAD -- proyecto_final prototipos/tron prototipos/lanzador.py nexys-a7-100t-master.xdc README.md .gitignore` is empty.

### D. Follow-up commits on the branch

Make one small commit per item so Roman can review each separately.

1. **Make the viewer runnable at its new path.**
   - In `prototipos/look/look/app.py`, point `ASSETS` at the repository root's `assets/`.
   - Fix the run instructions in `prototipos/look/README.md` to `cd prototipos/look` and `python -m look`.
   - Change the entry in `prototipos/look/.gitignore` to `out/`.
2. **Fix links and navigation.**
   - Add `docs/decisions/README.md`: the status "locked, never edited", both SHA-256 values, the two `research/…` tags, and a table mapping each old evidence path cited by the locked records to its new path.
   - Add `docs/history/game-research-commit-map.txt`.
   - In **non-locked** notes only (`docs/README.md`, the Map, the plans, the design notes, the reviews, `AGENTS.md`, `docs/agents/`), update relative links and vault-path wikilinks. Correct the depth of `../cs256-fall-2026/…` course links.
   - Change the Map's authority path to: course and TA requirements → `docs/decisions/` → `proyecto_final/Contrato…` once reconciled → code.
3. **Root `README.md`.** Add a short "Documentation and decisions / Documentación y decisiones" section linking `docs/README.md`, `docs/decisions/` and `docs/adr/`.
4. **`.gitignore`.** Add `.pytest_cache/`, `prototipos/look/out/`, Vivado run directories and `local/`.
5. **Python environments (M5).** Keep `prototipos/requirements.txt` (Roman) and `prototipos/look/requirements.txt` (ours) separate, and document one virtual environment per viewer.
6. **Optional, in Roman's file:** a `look` entry in `prototipos/lanzador.py`. It runs `python -m look` with `cwd=prototipos/look`.
7. **Optional:** a `CODEOWNERS` file so that changes to `docs/decisions/` and `docs/adr/` need both members.

**Check:**
- Both viewers start, and `python3 prototipos/correr_pruebas.py` plus our `python -m unittest discover -s tests` (run from `prototipos/look`) execute. These are smoke checks of the move only; they are not evidence that the agreed rules are implemented.
- `grep -n "\[\[CS-256/Game_research/" -r docs --include=*.md` finds matches only inside `docs/decisions/`.

### E. Pull request and merge

- Alan pushes `integrate/game-research` and opens a pull request against `main`. The pull request links this plan and the [[#Acceptance checklist]].
- Roman reviews. Either member can block it; nothing on `main` changes until it merges.
- Merge with **Create a merge commit**. Squash would collapse the imported history into one commit; rebase would rewrite it.
- After merging, tag `integration-game-research` on the merge commit.

### F. Convert the vault folder into the working clone

Run this only after step E and after M4 = A. It follows the vault's batch procedure in [[00-System/Planning/Metadata-and-File-Standard#Migrating the existing folders]]: take a snapshot outside the vault, keep a move log, and run a link check before and after.

1. **Every device:** wait until Syncthing shows "Up to Date", then close Obsidian.
2. **Every device:** add `/CS-256/Game_research/.git` to the vault's `.stignore`. `.stignore` is per device and is not synced. On devices that will not run Git, delete the stale synced copy of `Game_research/.git`.
3. **On the one Git machine:**

```bash
cp -a "$GR" ~/cs256-backups/Game_research-before-switch      # snapshot outside the vault
chmod -R u+w "$GR"                                             # lift the read-only safeguards so Git can move files
mkdir -p "$GR/local" && cp -a "$GR/Datasheets" "$GR/local/datasheets"
cd "$GR"
git remote add origin https://github.com/romanmg00/FPGA.git
git fetch origin --tags
git switch -C main origin/main
git branch --set-upstream-to=origin/main main
```

4. Move any ignored local renders from `prototype/out/` to `prototipos/look/out/`, then remove the emptied old folders.
5. Reopen Obsidian and run the link check.

**Check:**
- `git status --short` is empty, apart from ignored files.
- The old local history is still reachable: `git log decisions-2026-10-20` and `git log research-pre-merge`.
- The only unresolved vault links are the historical vault-path links inside `docs/decisions/`, and `docs/decisions/README.md` lists them.

## Acceptance checklist

The pull request may merge only when all of these hold:

- [ ] `sha256sum docs/decisions/*.md` matches `cd524e90…` (specification) and `ff9c1c62…` (decision record).
- [ ] `imported-paths.txt` matches the [[#Path map]]. Every exclusion is listed, and the bundle contains the excluded files.
- [ ] `git log --all --name-only --format= -- '*.pdf' | sort -u` lists only `docs/references/Nexys_A7_Game_Research_Report.pdf` and Roman's course PDF.
- [ ] Imported commits show only the chosen public author identity.
- [ ] `git log --follow` works for moved notes, and the tags `research/decisions-2026-10-20` and `research/research-pre-merge` exist.
- [ ] `git diff --stat origin/main...integrate/game-research -- proyecto_final prototipos/tron nexys-a7-100t-master.xdc` shows no unintended change to Roman's files.
- [ ] Both viewers start and their existing tests run (smoke checks only).
- [ ] The merge method is **Create a merge commit**.

## Rollback

| Point of failure | Rollback |
|---|---|
| During step A | `git -C "$GR" reset --soft 6ef8104` restores the previous branch tip and keeps the working tree. Delete the `baseline-snapshot` branch and the two tags if they were created. The `/tmp` snapshot is only read, never changed. |
| During steps B–D | Delete `~/cs256-merge/research` or `~/cs256-merge/fpga` and start again. Neither the original repository nor Roman's repository has changed. |
| Pull request rejected | Close it and delete the branch. `main` is unchanged. |
| After the merge, if the import must be withdrawn | Roman runs `git revert -m 1 <merge-commit>` on `main`. To re-import later, revert that revert rather than merging again. |
| During or after step F | Run `git switch -C main research-pre-merge` to return the vault folder to its old layout, or restore `~/cs256-backups/Game_research-before-switch`. As a last resort, clone the bundle: `git clone ~/cs256-backups/game-research-2026-10-20.bundle`. |

## After the merge

- Record decision D9 itself as **ADR 0003** (repository structure and merge method) in `docs/adr/`.
- Open one GitHub issue for each still-open decision D1–D8 from [[CS-256 Tron Opus 5.5 Architecture and Integration Review#6.1 Team decisions, ranked]]. Close each issue with its ADR.
- Update the Map's document register and `docs/README.md`'s layout table to the new paths, and add this plan to both.
- Continue the contract reconciliation in `proyecto_final/` ([[CS-256 Tron Opus 5.5 Architecture and Integration Review#4.3 Contract reconciliation checklist]]). Then migrate the shared model per D1.

## Roles

| Who | Responsibility |
|---|---|
| Alan | Steps A–D and F; prepares the pull request and the evidence for the checklist |
| Roman | Reviews the pull request; chooses the merge method and merges; owns the changes to his files (README section, launcher entry); settles the course-PDF rule |
| Both | Approve M1–M5. If either objects, the pull request stays open and `main` is untouched |

## Limitations

- No command here has been executed. `git-filter-repo` behavior, especially renames combined with tag renaming, is taken from its documentation; the checks after steps B and C exist to catch mistakes.
- Facts were verified at 15:08 on 2026-10-20 against `main` at `f5cb82c`. If Roman pushes in the meantime, the plan still applies, because the import is a merge; re-run the step C checks.
- Syncthing behavior depends on each device's `.stignore`. Confirm on every device that `.git` is excluded before relying on step F.
