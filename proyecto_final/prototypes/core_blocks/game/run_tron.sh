#!/usr/bin/env bash
# Build the tron_top bitstream in the Vivado 2025.2 container (run_tron.tcl).
# Run outside the agent sandbox: the launcher needs sudo -n.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
hdl=$(cd "$here/../../.." && pwd)    # proyecto_final/
launch=/usr/local/sbin/cs256-vivado
out="/builds/tron-$(date +%Y%m%d-%H%M%S)-$$"
sudo -n "$launch" start >/dev/null
sudo -n "$launch" exec mkdir -p "$out/src"
tar -C "$hdl" --exclude='*.pdf' --exclude=deprecated --exclude=.Xil -cf - . |
    sudo -n "$launch" exec tar -C "$out/src" -xf -
printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${out##*/}"
sudo -n "$launch" exec bash -c '
set -eo pipefail
source /tools/2025.2/Vivado/settings64.sh
source /home/vivado/vivado-runtime.sh
cd "$1"
vivado -mode batch -nojournal -log vivado.log -source "$1/src/prototypes/core_blocks/game/run_tron.tcl" -tclargs "$1" > /dev/null
test -s "$1/BUILD_COMPLETE.txt"
' bash "$out"
echo "RESULT: BUILD_COMPLETE"
