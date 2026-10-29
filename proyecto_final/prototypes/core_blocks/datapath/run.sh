#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../../.."
base=prototypes/core_blocks
sources=("$base/step/turn_unit.sv" "$base/step/next_cell.sv" "$base/step/step_resolve.sv" "$base/score/score_unit.sv" "$base/datapath/step_core.sv")
if [[ ${1:-} == synth ]];then
 proyecto_final/$base/run_synth.sh -c clk 11.982 step_core "${sources[@]}"
else
 proyecto_final/$base/run_xsim.sh "$@" datapath_tb "${sources[@]}" "$base/arena/arena_map.sv" "$base/arena/arena_ctrl.sv" "$base/datapath/datapath_tb.sv"
fi
