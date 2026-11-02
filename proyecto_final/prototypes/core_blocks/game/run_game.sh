#!/usr/bin/env bash
# Replay the 12 M2 scenarios through the HDL game core and diff each Step log
# against the model's, keeping every field including tick, and each arena log
# (CRC-32 of the whole Arena at every Step-log line) against the model's.
#
#   run_game.sh [-g NAME=VALUE]...     (N, PHASE, WINDOW, QUALIFIED, RSP_REG,
#                                       STEP_TICKS: see game_tb.sv)
#
# The reference log follows the crossing and Step interval: <name>.model.log
# for the mailbox at 6 ticks, else <name>.<crossing>-s<N>.log, with crossing
# mailbox, qualified (QUALIFIED=1) or captured (QUALIFIED=1 RSP_REG=1); see
# make_events.py and crossing/FINDINGS.md.
#
# Regenerate the event files and model logs first if the scenarios or the
# model changed:  (cd prototipos/tron_fpga && python3 ../../proyecto_final/prototypes/core_blocks/game/make_events.py)
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../../../.." && pwd)
p=prototypes/core_blocks
out=$(mktemp)
crossing=mailbox; rsp_reg=0; step=6
for a in "$@"; do
    case $a in
        QUALIFIED=1) [[ $crossing == mailbox ]] && crossing=qualified ;;
        RSP_REG=1) rsp_reg=1 ;;
        STEP_TICKS=*) step=${a#STEP_TICKS=} ;;
    esac
done
[[ $crossing == qualified && $rsp_reg == 1 ]] && crossing=captured
ref="$crossing-s$step"
[[ $ref == mailbox-s6 ]] && ref=model
first=$(head -1 "$here/scenarios/manifest.txt")
[[ -f "$here/scenarios/$first.$ref.log" ]] ||
    { echo "no reference logs $ref; add the variant to make_events.py" >&2; exit 2; }
[[ -f "$here/scenarios/$first.$ref.arena.log" ]] ||
    { echo "no arena logs $ref; rerun make_events.py" >&2; exit 2; }
echo "reference: <name>.$ref.log"
"$here/../run_xsim.sh" "$@" game_tb \
    $p/io/sync_2ff.sv $p/io/seg7_page.sv \
    $p/step/turn_unit.sv $p/step/next_cell.sv $p/step/step_resolve.sv \
    $p/score/score_unit.sv $p/arena/arena_map.sv \
    prototypes/uart_input/uart_cmd_decode.sv \
    $p/crossing/batch_fifo.sv $p/game/arena_svc.sv $p/game/fast_core.sv $p/game/game_core.sv $p/game/game_tb.sv | tee "$out" |
    grep -E '^(REPLAYED|SUMMARY|PASS|RESULT|Artifacts)|Fatal|ERROR|Error' || true
build=$(sed -n 's/^Artifacts (host): //p' "$out")
grep -q '^RESULT: PASS game_tb' "$out" || { echo "bench failed; see $build"; exit 1; }
fail=0
while read -r name; do
    for kind in step arena; do
        if [[ $kind == step ]]; then a="$here/scenarios/$name.$ref.log" b="$build/$name.hdl.log"
        else a="$here/scenarios/$name.$ref.arena.log" b="$build/$name.arena.hdl.log"; fi
        if python3 "$repo/tools/steplog_diff.py" "$a" "$b" >/tmp/diff.$$ 2>&1; then
            printf 'MATCH %-5s %-24s %s\n' "$kind" "$name" "$(head -1 /tmp/diff.$$)"
        else
            fail=1
            printf 'DIFF  %-5s %-24s\n' "$kind" "$name"; sed 's/^/      /' /tmp/diff.$$ | head -6
        fi
    done
done <"$here/scenarios/manifest.txt"
rm -f /tmp/diff.$$ "$out"
exit "$fail"
