#!/usr/bin/env bash
# Out-of-context synthesis of one module in the Vivado 2025.2 container, for
# resource, latch and timing feasibility. Not a routed sign-off.
#
#   run_synth.sh [-g NAME=VALUE]... [-c CLOCK_PORT PERIOD_NS]... TOP FILE.sv...
#
# FILE paths are relative to proyecto_final/; core_blocks/game_pkg.sv is
# always read first. Each -c adds create_clock on a top-level port. Unclocked
# inputs and outputs are left unconstrained (OOC). Writes, in a fresh
# /builds/core-synth-<top>-<timestamp>-<pid>/ folder: synth.log,
# utilization.txt, timing.txt, latches.txt, ram.txt. Fails if synthesis
# errors or infers a latch. Run outside the agent sandbox: the launcher
# needs sudo -n.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../.." && pwd)    # proyecto_final/
generics=() clocks=()
while :; do
    case ${1:-} in
        -g) generics+=("$2"); shift 2 ;;
        -c) clocks+=("$2" "$3"); shift 3 ;;
        *) break ;;
    esac
done
top=${1:?Usage: run_synth.sh [-g NAME=VALUE]... [-c PORT PERIOD_NS]... TOP FILE.sv...}
shift
(($#)) || { echo "No source files given" >&2; exit 2; }
for f in "$@"; do [[ -f $root/$f ]] || { echo "Missing $root/$f" >&2; exit 2; }; done

launcher=/usr/local/sbin/cs256-vivado
sudo -n "$launcher" start >/dev/null
run_dir="/builds/core-synth-$top-$(date +%Y%m%d-%H%M%S)-$$"
sudo -n "$launcher" exec mkdir -p "$run_dir/src"
tar -C "$root" --exclude='*.pdf' --exclude=deprecated --exclude=.Xil -cf - . |
    sudo -n "$launcher" exec tar -C "$run_dir/src" -xf -

{
    echo "set run_dir $run_dir"
    echo "read_verilog -sv \$run_dir/src/prototypes/core_blocks/game_pkg.sv"
    for f in "$@"; do echo "read_verilog -sv \"\$run_dir/src/$f\""; done
    printf 'synth_design -top %s -part xc7a100tcsg324-1 -mode out_of_context' "$top"
    for g in "${generics[@]}"; do printf ' -generic %s' "$g"; done
    echo
    for ((i = 0; i < ${#clocks[@]}; i += 2)); do
        echo "create_clock -name ${clocks[i]} -period ${clocks[i+1]} [get_ports ${clocks[i]}]"
    done
    cat <<'TCL'
report_utilization -file $run_dir/utilization.txt
report_utilization -hierarchical -file $run_dir/utilization_hier.txt
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 10 -file $run_dir/timing.txt
set latches [all_latches]
set f [open $run_dir/latches.txt w]; puts $f "latches: [llength $latches]"; foreach l $latches {puts $f $l}; close $f
set f [open $run_dir/ram.txt w]
foreach c [get_cells -hier -filter {REF_NAME =~ RAMB* || PRIMITIVE_GROUP == DMEM}] {
    puts $f "[get_property REF_NAME $c] $c"
}
close $f
if {[llength $latches] > 0} {error "Inferred [llength $latches] latch(es)"}
TCL
} | sudo -n "$launcher" exec tee "$run_dir/synth.tcl" >/dev/null

status=0
sudo -n "$launcher" exec bash -c '
    set -eo pipefail
    source /tools/2025.2/Vivado/settings64.sh
    source /home/vivado/vivado-runtime.sh
    set -u
    cd "$1"
    vivado -mode batch -nojournal -log synth.log -source synth.tcl > /dev/null 2>&1 ||
        { grep -E "^(ERROR|CRITICAL WARNING)" synth.log; exit 1; }
    grep -E "^(CRITICAL WARNING|WARNING: \[Synth 8-(327|3331|6014|7129|87)\])" synth.log | sort -u | head -40 || true
    cat latches.txt ram.txt
    sed -n "/Design Timing Summary/,/^$/{p}" timing.txt | head -1
    grep -A3 -E "^\s+WNS\(ns\)" timing.txt | head -4
    grep -E "^\| (Slice LUTs\*?|Slice Registers|Block RAM Tile|F7 Muxes|DSPs) " utilization.txt
    echo "RESULT: synthesized $2"
' bash "$run_dir" "$top" || status=$?
printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${run_dir##*/}"
exit "$status"
