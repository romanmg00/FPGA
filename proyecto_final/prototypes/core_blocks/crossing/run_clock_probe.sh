#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
launcher=/usr/local/sbin/cs256-vivado
out=/builds/crossing-clock-probe-$(date +%Y%m%d-%H%M%S)-$$
sudo -n "$launcher" start >/dev/null
sudo -n "$launcher" exec mkdir -p "$out"
sudo -n "$launcher" exec tee "$out/clock_probe.tcl" < "$here/clock_probe.tcl" >/dev/null
printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${out##*/}"
sudo -n "$launcher" exec bash -c '
source /tools/2025.2/Vivado/settings64.sh
source /home/vivado/vivado-runtime.sh
cd "$1"
vivado -mode batch -nojournal -log probe.log -source clock_probe.tcl -tclargs "$1" > console.txt 2>&1
' bash "$out"
