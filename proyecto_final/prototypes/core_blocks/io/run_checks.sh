#!/usr/bin/env bash
# Reproduce Alan's provisional IO evidence using the read-only shared runners.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.."
base=prototypes/core_blocks/io
runner=prototypes/core_blocks
run() {
    local label=$1
    shift
    "$@" 2>&1 | tee "$base/evidence/$label.txt"
}
run sync_2ff_tb "$runner/run_xsim.sh" sync_2ff_tb "$base/sync_2ff.sv" "$base/sync_2ff_tb.sv"
run btn_debounce_tb "$runner/run_xsim.sh" btn_debounce_tb "$base/sync_2ff.sv" "$base/btn_debounce.sv" "$base/btn_debounce_tb.sv"
run seg7_page_tb "$runner/run_xsim.sh" seg7_page_tb "$base/seg7_page.sv" "$base/seg7_page_tb.sv"
run seg7_driver_tb "$runner/run_xsim.sh" seg7_driver_tb "$base/seg7_driver.sv" "$base/seg7_driver_tb.sv"
run btn_debounce_synth "$runner/run_synth.sh" -c clk 11.982 btn_debounce "$base/sync_2ff.sv" "$base/btn_debounce.sv"
run seg7_driver_synth "$runner/run_synth.sh" -c clk_pix 11.982 seg7_driver "$base/seg7_driver.sv"
