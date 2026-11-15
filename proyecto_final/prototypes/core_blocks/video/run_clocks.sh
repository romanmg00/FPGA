#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
launcher=/usr/local/sbin/cs256-vivado
sudo -n "$launcher" start >/dev/null
run_dir="/builds/core-video-clocks-$(date +%Y%m%d-%H%M%S)-$$"
sudo -n "$launcher" exec mkdir -p "$run_dir"
sudo -n "$launcher" exec tee "$run_dir/clock_feasibility.tcl" < "$here/clock_feasibility.tcl" >/dev/null
sudo -n "$launcher" exec bash -c '
set -eo pipefail
source /tools/2025.2/Vivado/settings64.sh
source /home/vivado/vivado-runtime.sh
cd "$1"
vivado -mode batch -nojournal -log clocks.log -source clock_feasibility.tcl -tclargs "$1" > console.txt 2>&1 || { tail -60 console.txt; exit 1; }
cat clocks.txt
' bash "$run_dir"
printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${run_dir##*/}"
