#!/usr/bin/env bash
# Protocol benches of the qualified crossing (FINDINGS.md): batch_fifo_tb at
# both read modes and handshake_tb as "qualified" (6 ticks) and "captured"
# (RSP_REG = 1, 8 ticks), in parallel. Run outside the agent sandbox.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
p=prototypes/core_blocks
run="$here/../run_xsim.sh"
logs=$(mktemp -d)
"$run" batch_fifo_tb $p/crossing/batch_fifo.sv $p/crossing/batch_fifo_tb.sv >"$logs/fifo1" 2>&1 &
"$run" -g RD_REG=0 batch_fifo_tb $p/crossing/batch_fifo.sv $p/crossing/batch_fifo_tb.sv >"$logs/fifo0" 2>&1 &
"$run" handshake_tb $p/game_pkg.sv $p/io/sync_2ff.sv $p/io/seg7_page.sv \
    $p/step/turn_unit.sv $p/step/next_cell.sv $p/step/step_resolve.sv \
    $p/score/score_unit.sv $p/game/game_core.sv $p/crossing/handshake_tb.sv >"$logs/hs" 2>&1 &
"$run" -g RSP_REG=1 -g STEP=8 handshake_tb $p/game_pkg.sv $p/io/sync_2ff.sv $p/io/seg7_page.sv \
    $p/step/turn_unit.sv $p/step/next_cell.sv $p/step/step_resolve.sv \
    $p/score/score_unit.sv $p/game/game_core.sv $p/crossing/handshake_tb.sv >"$logs/hs_captured" 2>&1 &
wait
fail=0
for f in fifo1 fifo0 hs hs_captured; do
    grep -E '^(STATS|RESULT|Artifacts)|Error|Fatal' "$logs/$f" || true
    grep -q '^RESULT: PASS' "$logs/$f" || fail=1
done
echo "Logs: $logs"
exit "$fail"
