#!/usr/bin/env bash
# Author: Alan (AIF31).
# Evidence for the authorship headers in proyecto_final/: for each hand-written .sv, .xdc and .tcl
# (recursive; prototypes/ and deprecated/ left out), who created it, non-merge commits per person
# (git log --follow; a file move adds a commit for whoever moved it) and current lines per person
# (git blame -w -M: moves inside a file are followed, lines copied from another file are not).
# Only the line counts are meant to stay the same across a pure move.
# Maps git author names to people; no emails are read or printed.
rev=${1:-origin/main}
who() { case "$1" in AIF31|"Alan Iván Flores Juárez") echo Alan;; mandujre|romanmg00) echo Roman;; *) echo "?$1";; esac; }
printf '| File | Created by | Commits A/R | Lines A/R |\n|---|---|---|---|\n'
git ls-tree -r --name-only "$rev" -- proyecto_final/ |
  grep -E '\.(sv|xdc|tcl)$' | grep -v -E '^proyecto_final/(prototypes|deprecated)/' |
  while read -r f; do
  c=$(git log "$rev" --follow --diff-filter=A --format='%an' -- "$f" | tail -1)
  ca=0; cr=0
  while read -r a; do [ -z "$a" ] && continue; case $(who "$a") in Alan) ca=$((ca+1));; Roman) cr=$((cr+1));; esac; done < <(git log "$rev" --follow --no-merges --format='%an' -- "$f")
  la=0; lr=0
  while read -r n a; do case $(who "$a") in Alan) la=$((la+n));; Roman) lr=$((lr+n));; esac; done < <(git blame -w -M --line-porcelain "$rev" -- "$f" | sed -n 's/^author //p' | sort | uniq -c)
  printf '| `%s` | %s | %d/%d | %d/%d |\n' "${f#proyecto_final/}" "$(who "$c")" "$ca" "$cr" "$la" "$lr"
done
