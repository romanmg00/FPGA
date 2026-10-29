#!/usr/bin/env bash
# Compile and run one self-checking XSim bench in the Vivado 2025.2 container.
#
#   run_xsim.sh [-g NAME=VALUE]... BENCH_TOP FILE.sv...
#
# FILE paths are relative to proyecto_final/. core_blocks/game_pkg.sv is
# always compiled first. Every module elaborates at 1ns/1ps, so file order
# does not matter for `timescale. Each run copies proyecto_final/ (minus PDFs and
# deprecated/) into a fresh /builds/core-<bench>-<timestamp>-<pid>/ folder.
# Passes only when the log contains "PASS BENCH_TOP" and no fatal/error line.
# Run outside the agent sandbox: the launcher needs sudo -n.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../.." && pwd)    # proyecto_final/
generics=()
while [[ ${1:-} == -g ]]; do generics+=(--generic_top "$2"); shift 2; done
bench=${1:?Usage: run_xsim.sh [-g NAME=VALUE]... BENCH_TOP FILE.sv...}
shift
(($#)) || { echo "No source files given" >&2; exit 2; }
for f in "$@"; do [[ -f $root/$f ]] || { echo "Missing $root/$f" >&2; exit 2; }; done

launcher=/usr/local/sbin/cs256-vivado
sudo -n "$launcher" start >/dev/null
run_dir="/builds/core-$bench-$(date +%Y%m%d-%H%M%S)-$$"
sudo -n "$launcher" exec mkdir -p "$run_dir/src"
tar -C "$root" --exclude='*.pdf' --exclude=deprecated --exclude=.Xil -cf - . |
    sudo -n "$launcher" exec tar -C "$run_dir/src" -xf -

status=0
sudo -n "$launcher" exec bash -c '
    set -eo pipefail
    source /tools/2025.2/Vivado/settings64.sh
    source /home/vivado/vivado-runtime.sh
    set -u
    run_dir=$1 bench=$2 ngen=$3; shift 3
    gen=("${@:1:ngen}"); shift "$ngen"
    cd "$run_dir"
    srcs=(src/prototypes/core_blocks/game_pkg.sv)
    for f in "$@"; do srcs+=("src/$f"); done
    xvlog -sv "${srcs[@]}" > xvlog.out 2>&1 || { cat xvlog.out; exit 1; }
    xelab -debug typical --timescale 1ns/1ps --override_timeunit "${gen[@]}" "$bench" -s "$bench" > xelab.out 2>&1 || { cat xelab.out; exit 1; }
    xsim "$bench" -runall -log sim.log > /dev/null 2>&1 || true
    cat sim.log
    grep -E "WARNING: \[(VRFC|XSIM)" xvlog.out xelab.out || true
    grep -q "PASS $bench" sim.log || { echo "RESULT: missing PASS $bench"; exit 1; }
    if grep -Eiq "fatal|^error|[^_]error:" sim.log; then echo "RESULT: error line in log"; exit 1; fi
    echo "RESULT: PASS $bench"
' bash "$run_dir" "$bench" "${#generics[@]}" "${generics[@]}" "$@" || status=$?
printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${run_dir##*/}"
exit "$status"
