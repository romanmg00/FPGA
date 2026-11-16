#!/usr/bin/env bash
# Run AFTER the shared run_synth.sh; argument is its /builds/core-synth-* path.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
run_dir=${1:?Pass container /builds/core-synth-TOP-TIMESTAMP-PID path}
[[ $run_dir == /builds/core-synth-* && $run_dir != *..* ]] || exit 2
launcher=/usr/local/sbin/cs256-vivado
sudo -n "$launcher" exec tee "$run_dir/report_ram.tcl" < "$here/report_ram.tcl" >/dev/null
sudo -n "$launcher" exec bash -c '
    set -eo pipefail
    source /tools/2025.2/Vivado/settings64.sh
    source /home/vivado/vivado-runtime.sh
    cd "$1"
    vivado -mode batch -nojournal -log ram_checked.log -source report_ram.tcl -tclargs "$1" > ram_checked.out 2>&1
    cat ram.txt
    grep "PASS arena_ram_report" ram_checked.log
' bash "$run_dir"
