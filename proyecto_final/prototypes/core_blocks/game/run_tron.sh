#!/usr/bin/env bash
# Build the tron_top bitstream in the Vivado 2025.2 container (run_tron.tcl).
# Run outside the agent sandbox: the launcher needs sudo -n.
#   run_tron.sh [mailbox|qualified|captured] [STEP_TICKS]
#     mailbox     quiet-window mailbox (ADR 0003 working default)
#     qualified   req/ack crossing + batch_fifo (crossing/FINDINGS.md)
#     captured    qualified, with the response codes captured first (needs >= 8)
#     STEP_TICKS  game ticks per Step, default 6 (ADR 0007)
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
hdl=$(cd "$here/../../.." && pwd)    # proyecto_final/
launch=/usr/local/sbin/cs256-vivado
case "${1:-mailbox}" in
    mailbox) qualified=0; rsp_reg=0; tag=tron ;;
    qualified) qualified=1; rsp_reg=0; tag=tron-qualified ;;
    captured) qualified=1; rsp_reg=1; tag=tron-captured ;;
    *) echo "usage: run_tron.sh [mailbox|qualified|captured] [STEP_TICKS]" >&2; exit 2 ;;
esac
step=${2:-6}
[[ $step =~ ^[0-9]+$ ]] || { echo "STEP_TICKS must be a number" >&2; exit 2; }
[[ $step == 6 ]] || tag="$tag-s$step"
out="/builds/$tag-$(date +%Y%m%d-%H%M%S)-$$"
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
vivado -mode batch -nojournal -log vivado.log -source "$1/src/prototypes/core_blocks/game/run_tron.tcl" -tclargs "$1" "$2" "$3" "$4" > /dev/null
test -s "$1/BUILD_COMPLETE.txt"
' bash "$out" "$qualified" "$rsp_reg" "$step"
echo "RESULT: BUILD_COMPLETE"
