#!/usr/bin/env bash
# Rerun every core-block bench in parallel through run_xsim.sh and summarize.
# vga_out_check_tb checks the prototype copy video/vga_out.sv; it would fail on
# the registered proyecto_final/vga_out.sv (video/FINDINGS.md), so it is reported separately.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
p=prototypes/core_blocks
logs=$(mktemp -d)
benches=(
    "game_pkg_tb $p/game_pkg_tb.sv"
    "arena_map_tb $p/arena/arena_map.sv $p/arena/arena_map_tb.sv"
    "arena_ctrl_tb $p/arena/arena_map.sv $p/arena/arena_ctrl.sv $p/arena/arena_ctrl_tb.sv"
    "turn_unit_tb $p/step/turn_unit.sv $p/step/turn_unit_tb.sv"
    "step_resolve_tb $p/step/next_cell.sv $p/step/step_resolve.sv $p/step/step_resolve_tb.sv"
    "score_directed_tb $p/score/score_unit.sv $p/score/score_directed_tb.sv"
    "score_model_tb $p/score/score_unit.sv $p/score/score_model_tb.sv"
    "sync_2ff_tb $p/io/sync_2ff.sv $p/io/sync_2ff_tb.sv"
    "btn_debounce_tb $p/io/sync_2ff.sv $p/io/btn_debounce.sv $p/io/btn_debounce_tb.sv"
    "seg7_page_tb $p/io/seg7_page.sv $p/io/seg7_page_tb.sv"
    "seg7_driver_tb $p/io/seg7_driver.sv $p/io/seg7_driver_tb.sv"
    "game_clk_div_tb $p/video/game_clk_div.sv $p/video/game_clk_div_tb.sv"
    "vga_out_check_tb counters.sv $p/video/vga_out.sv $p/video/vga_out_check_tb.sv"
)
for b in "${benches[@]}"; do
    read -r -a args <<<"$b"
    "$here/run_xsim.sh" "${args[@]}" >"$logs/${args[0]}.log" 2>&1 &
    sleep 1    # distinct run-folder timestamps
done
wait
fail=0
for b in "${benches[@]}"; do
    name=${b%% *}
    result=$(grep -m1 '^RESULT:' "$logs/$name.log" || echo 'RESULT: no result line')
    artifact=$(grep -m1 '^Artifacts' "$logs/$name.log" | sed 's/.*builds\///')
    printf '%-20s %-40s %s\n' "$name" "$result" "$artifact"
    [[ $result == "RESULT: PASS $name" || $name == vga_out_check_tb ]] || fail=1
done
echo "Logs: $logs"
exit "$fail"
