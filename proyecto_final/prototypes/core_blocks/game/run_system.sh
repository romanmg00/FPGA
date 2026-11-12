#!/usr/bin/env bash
# End-to-end smoke bench of tron_system (see tron_system_tb.sv).
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
p=prototypes/core_blocks
exec "$here/../run_xsim.sh" "$@" tron_system_tb \
    counters.sv $p/video/vga_out.sv \
    $p/io/sync_2ff.sv $p/io/btn_debounce.sv $p/io/seg7_driver.sv $p/io/seg7_page.sv \
    $p/step/turn_unit.sv $p/step/next_cell.sv $p/step/step_resolve.sv \
    $p/score/score_unit.sv $p/arena/arena_map.sv \
    prototypes/uart_input/uart_sync_2ff.sv prototypes/uart_input/uart_rx.sv prototypes/uart_input/uart_cmd_decode.sv \
    $p/crossing/batch_fifo.sv $p/game/arena_svc.sv $p/game/fast_core.sv $p/game/game_core.sv \
    $p/game/sprite_rom.sv $p/game/drawcon_game.sv $p/game/tron_system.sv $p/game/tron_system_tb.sv
