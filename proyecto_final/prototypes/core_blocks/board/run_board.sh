#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
hdl=$(cd "$here/../../.." && pwd)
launch=/usr/local/sbin/cs256-vivado
out="/builds/core-board-$(date +%Y%m%d-%H%M%S)-$$"
sudo -n "$launch" start >/dev/null
sudo -n "$launch" exec mkdir -p "$out/src"
tar -C "$hdl" -cf - . | sudo -n "$launch" exec tar -C "$out/src" -xf -
printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${out##*/}"
sudo -n "$launch" exec bash -c '
set -eo pipefail
source /tools/2025.2/Vivado/settings64.sh
source /home/vivado/vivado-runtime.sh
cd "$1"
vivado -mode batch -source "$1/src/prototypes/core_blocks/board/run_board.tcl" -tclargs "$1" "$2"
test -s "$1/BUILD_COMPLETE.txt"
' bash "$out" "${1:-full}"
