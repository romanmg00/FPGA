#!/usr/bin/env bash
# Quick loop for drawcon_game's look: one command from an edited design to the
# board.
#   1. regenerate the HUD and background tables from the Python viewer;
#   2. export a game scene and the viewer's frame of it (../tools/look_frame.py);
#   3. in parallel: render that scene in XSim (drawcon_frame_tb, ~1 min) and
#      diff it with the viewer, and build the bitstream (run_tron.sh, ~3.5 min);
#   4. if routed timing is met, program the board over JTAG.
# Run outside the agent sandbox: the Vivado launcher needs sudo -n.
#
#   look_loop.sh [--ticks N] [--no-build] [--no-program]
#
# The full benches (run_all.sh, run_system.sh, run_game.sh) stay the check
# before a commit; this loop only shows the picture.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../../../.." && pwd)
py=${PYTHON:-$HOME/.venvs/cs256-tron/bin/python}
jtag=${JTAG_HELPER:-$HOME/.claude/skills/vivado-container/scripts/host-jtag.sh}
ticks=150; build=1; program=1
while (($#)); do
    case $1 in
        --ticks) ticks=$2; shift ;;
        --no-build) build=0; program=0 ;;
        --no-program) program=0 ;;
        *) echo "usage: look_loop.sh [--ticks N] [--no-build] [--no-program]" >&2; exit 2 ;;
    esac
    shift
done
out="$here/look"
mkdir -p "$out"

echo "== tables and scene"
"$py" "$here/../tools/make_hud_icons.py" "$here/sprites/hud-icons-16.mem"
"$py" "$here/../tools/make_bg_luts.py" "$here/sprites" 2>&1 | grep -v '^pygame'
"$py" "$here/../tools/look_frame.py" scene "$out" --ticks "$ticks" 2>&1 | grep -v '^pygame'

if ((build)); then
    echo "== bitstream build started (log: $out/build.log)"
    "$here/run_tron.sh" mailbox >"$out/build.log" 2>&1 &
    build_pid=$!
fi

echo "== frame bench"
p=prototypes/core_blocks/game
if ! "$here/../run_xsim.sh" drawcon_frame_tb $p/sprite_rom.sv $p/drawcon_game.sv $p/drawcon_frame_tb.sv \
        >"$out/frame.log" 2>&1; then
    grep -E 'ERROR|Error|RESULT' "$out/frame.log" || tail -20 "$out/frame.log"
    echo "frame bench failed; see $out/frame.log" >&2
    exit 1
fi
run=$(sed -n 's/^Artifacts (host): //p' "$out/frame.log" | tail -1)
grep -h '^frame phase' "$run/sim.log" || true
"$py" "$here/../tools/look_frame.py" compare "$run/frame.hex" "$out" 2>&1 | grep -v '^pygame'

((build)) || exit 0
echo "== waiting for the build"
wait "$build_pid" || { tail -5 "$out/build.log"; exit 1; }
b=$(sed -n 's/^Artifacts (host): //p' "$out/build.log" | tail -1)
grep -q '^RESULT: BUILD_COMPLETE' "$out/build.log" || { tail -5 "$out/build.log"; exit 1; }
read -r wns _ _ _ whs _ < <(sed -n '/Design Timing Summary/,+6p' "$b/timing_summary.rpt" | tail -1)
unknown=$(awk '$2 == "clk_juego" && $3 ~ /pixel/ {print $(NF-1)}' "$b/report_cdc_summary.rpt")
drc=$(grep -ci violation "$b/report_drc.rpt" || true)
echo "build $b"
echo "  WNS $wns ns, WHS $whs ns; game->pixel Unknown CDC endpoints: ${unknown:-?}; DRC lines: $drc"
if ! grep -q 'All user specified timing constraints are met' "$b/timing_summary.rpt"; then
    echo "routed timing NOT met: not programming" >&2
    exit 1
fi
((program)) || exit 0
if [[ ! -f $jtag ]]; then
    echo "no JTAG helper at $jtag (set JTAG_HELPER); program $b/tron_top.bit by hand"
    exit 0
fi
echo "== programming the board"
bash "$jtag" "$b/tron_top.bit" 2>&1 | grep -E '^(DEVICE|DONE_PIN|PROGRAMMED)|ERROR'
