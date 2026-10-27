#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir=${1:?Usage: run_iverilog.sh FRESH_OUTPUT_DIRECTORY}
if [[ -e $output_dir ]]; then printf 'Use a fresh output directory.\n' >&2; exit 2; fi
mkdir -p "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
iverilog_bin=${UART_IVERILOG:-iverilog}
vvp_bin=${UART_VVP:-vvp}
compiler=("$iverilog_bin" -g2012)
if [[ -n ${UART_IVL_BASE:-} ]]; then compiler+=(-B "$UART_IVL_BASE"); fi
rtl=()
for module in uart_sync_2ff uart_rx uart_cmd_decode uart_async_fifo uart_input_path; do
    rtl+=("$source_dir/$module.sv")
done
"${compiler[@]}" -V > "$output_dir/version.txt" 2>&1 || true
for test_case in rx fifo path-fast path-real; do
    case $test_case in
        rx) bench=uart_rx_tb; parameters=();;
        fifo) bench=uart_async_fifo_tb; parameters=();;
        path-fast) bench=uart_input_path_tb; parameters=(-P uart_input_path_tb.real_ratio=0);;
        path-real) bench=uart_input_path_tb; parameters=(-P uart_input_path_tb.real_ratio=1);;
    esac
    "${compiler[@]}" -s "$bench" "${parameters[@]}" -o "$output_dir/$test_case.vvp" \
        "${rtl[@]}" "$source_dir/$bench.sv" 2>&1 | tee "$output_dir/$test_case-compile.txt"
    "$vvp_bin" "$output_dir/$test_case.vvp" 2>&1 | tee "$output_dir/$test_case.txt"
    if ! grep -Fq "PASS $bench" "$output_dir/$test_case.txt"; then
        printf 'Missing PASS marker for %s\n' "$test_case" >&2; exit 1
    fi
done
printf 'All four Icarus runs passed.\n' | tee "$output_dir/PASS.txt"
