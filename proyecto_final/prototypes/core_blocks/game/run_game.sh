#!/usr/bin/env bash
# Replay the 12 M2 scenarios through the HDL game core and diff each Step log
# against the model's, keeping every field including tick.
#
#   run_game.sh [-g NAME=VALUE]...     (N, PHASE, WINDOW: see game_tb.sv)
#
# Regenerate the event files and model logs first if the scenarios or the
# model changed:  (cd prototipos/tron_fpga && python3 ../../proyecto_final/prototypes/core_blocks/game/make_events.py)
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../../../.." && pwd)
p=prototypes/core_blocks
out=$(mktemp)
"$here/../run_xsim.sh" "$@" game_tb \
    $p/io/sync_2ff.sv $p/io/seg7_page.sv \
    $p/step/turn_unit.sv $p/step/next_cell.sv $p/step/step_resolve.sv \
    $p/score/score_unit.sv $p/arena/arena_map.sv \
    prototypes/uart_input/uart_cmd_decode.sv \
    $p/game/arena_svc.sv $p/game/fast_core.sv $p/game/game_core.sv $p/game/game_tb.sv | tee "$out" |
    grep -E '^(REPLAYED|SUMMARY|PASS|RESULT|Artifacts)|Fatal|ERROR|Error' || true
build=$(sed -n 's/^Artifacts (host): //p' "$out")
grep -q '^RESULT: PASS game_tb' "$out" || { echo "bench failed; see $build"; exit 1; }
fail=0
while read -r name; do
    if python3 "$repo/tools/steplog_diff.py" "$here/scenarios/$name.model.log" "$build/$name.hdl.log" >/tmp/diff.$$ 2>&1; then
        printf 'MATCH %-24s %s\n' "$name" "$(head -1 /tmp/diff.$$)"
    else
        fail=1
        printf 'DIFF  %-24s\n' "$name"; sed 's/^/      /' /tmp/diff.$$ | head -6
    fi
done <"$here/scenarios/manifest.txt"
rm -f /tmp/diff.$$ "$out"
exit "$fail"
