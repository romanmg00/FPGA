#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
flow=full
if [[ ${1:-} == --docker ]]; then
    shift
    [[ ${1:-} != --sim-only ]] || flow=sim
    container_name=cs256-vivado-ubuntu24
    docker_cmd=(docker)
    restricted_launcher=/usr/local/sbin/cs256-vivado
    if [[ -x $restricted_launcher ]]; then
        container_start() { sudo -n "$restricted_launcher" start; }
        container_exec() { sudo -n "$restricted_launcher" exec "$@"; }
    else
        if ! docker info >/dev/null 2>&1; then docker_cmd=(sudo docker); fi
        container_start() { "${docker_cmd[@]}" start "$container_name"; }
        container_exec() { "${docker_cmd[@]}" exec -i "$container_name" "$@"; }
    fi
    container_start >/dev/null
    output_dir="/builds/uart-$(date +%Y%m%d-%H%M%S)-$$"
    container_exec mkdir -p "$output_dir/source"
    tar -C "$source_dir" --exclude=out --exclude=.Xil -cf - . |
        container_exec tar -C "$output_dir/source" -xf -
    container_exec bash -c '
        set -eo pipefail
        source /tools/2025.2/Vivado/settings64.sh
        source /home/vivado/vivado-runtime.sh
        set -u
        cd "$1"
        vivado -mode batch -log vivado.log -journal vivado.jou \
            -source "$1/source/run.tcl" -tclargs "$1" "$2"
        if [[ $2 == sim ]]; then test -s "$1/tests/PASS.txt";
        else test -s "$1/BUILD_COMPLETE.txt"; fi
    ' bash "$output_dir" "$flow"
    printf 'Artifacts (container): %s\n' "$output_dir"
    printf 'Artifacts (host): /home/alan/.local/share/cs256-vivado/builds/%s\n' "${output_dir##*/}"
else
    output_dir=${1:?Usage: run.sh OUTPUT_DIRECTORY [--sim-only] | --docker [--sim-only]}
    [[ ${2:-} != --sim-only ]] || flow=sim
    mkdir -p "$output_dir"
    output_dir=$(cd -- "$output_dir" && pwd)
    cd "$output_dir"
    vivado -mode batch -log vivado.log -journal vivado.jou \
        -source "$source_dir/run.tcl" -tclargs "$output_dir" "$flow"
    if [[ $flow == sim ]]; then test -s "$output_dir/tests/PASS.txt";
    else test -s "$output_dir/BUILD_COMPLETE.txt"; fi
fi
