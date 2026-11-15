#!/usr/bin/env bash
# Export Vivado's schematics of a built tron_top (schematic.tcl) as PDF and SVG,
# from the synth.dcp of a run_tron.sh build, in the Vivado 2025.2 container.
# show_schematic needs the GUI, so Vivado runs under xvfb-run. Run outside the
# agent sandbox: the launcher needs sudo -n.
#   run_schematic.sh [BUILD]   BUILD: a tron-* folder name; default the newest
set -euo pipefail
builds=/home/alan/.local/share/cs256-vivado/builds
build=${1:-$(cd "$builds" && ls -td tron-*/ | head -1)}
build=${build%/}
[[ -s $builds/$build/synth.dcp ]] || { echo "no synth.dcp in $builds/$build" >&2; exit 2; }
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
launch=/usr/local/sbin/cs256-vivado
out="/builds/schematic-$(date +%Y%m%d-%H%M%S)-$$"
sudo -n "$launch" start >/dev/null
sudo -n "$launch" exec mkdir -p "$out"
sudo -n "$launch" exec tee "$out/schematic.tcl" >/dev/null < "$here/schematic.tcl"
printf 'Artifacts (host): %s/%s (from %s)\n' "$builds" "${out##*/}" "$build"
sudo -n "$launch" exec bash -c '
set -eo pipefail
source /tools/2025.2/Vivado/settings64.sh
source /home/vivado/vivado-runtime.sh
cd "$1"
timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" vivado -mode gui -nojournal -log vivado.log \
    -source "$1/schematic.tcl" -tclargs "$1" "/builds/$2/synth.dcp" > /dev/null 2>&1 || true
grep "^SCHEMATIC" vivado.log || true
test -s "$1/SCHEMATIC_COMPLETE.txt"
' bash "$out" "$build"
echo "RESULT: SCHEMATIC_COMPLETE"
