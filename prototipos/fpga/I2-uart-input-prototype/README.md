# I2 / X2 UART transport experiment evidence

Recorded 27 October 2026. See the [findings](../../../docs/design/CS-256%20UART%20Input%20Prototype%20Findings.md)
for interpretation, assumptions, the completed Vivado/IP Catalog checks, and
the remaining game-integration and physical-board limits.

- `rx.txt`, `fifo.txt`, `path-fast.txt`, `path-real.txt`: final portable Icarus stdout.
- `PASS.txt`: the portable runner's completion marker (all four runs passed).
- `version.txt`: Icarus version/license output from this run.
- `xsim-*.txt`: final Vivado/XSim results, including checked clock/ratio values.
- `vivado-summary.json`: final run path, timing/CDC/skew metrics, bitstream hash
  and unattended-launcher verification state.
- `*.rpt`, `clock-arithmetic.txt`, `cdc-endpoints.txt`, `derived-constraints.xdc`:
  final routed reports, generated clock calculations and applied constraints.
- `vivado-version.txt`, `vivado-uart-interfaces.txt`, `BUILD_COMPLETE.txt`:
  Vivado version, installed catalog/interface query and accepted run marker.
- `ip-catalog-uartlite.png`, `ip-catalog-uart16550.png`, `uart-ip-interfaces.png`:
  actual native Vivado GUI screenshots (not reconstructed illustrations).
- `source-sha256.txt`: final prototype `.sv`, `.xdc`, shell, Python and Tcl
  hashes, matched against the final Vivado source snapshot, plus the reviewed
  unattended-launcher template/installer hashes. Documentation is excluded.
- `portable-source-sha256.txt`: historical source hashes from the earlier
  portable run; the later board wrapper and build scripts differ intentionally.
- `installed-ip-metadata.json`: static inspection of installed IP-XACT XML,
  including source-file hashes. This is not a GUI screenshot or Vivado run.
- `model-analysis.json`: executable counterexamples using the existing Python model.
- `local-checks.txt`: recorded parser, shell/Tcl structural and Python-suite results.

Reproduce portable checks from the repository root with Icarus on PATH:

```bash
bash proyecto_final/prototypes/uart_input/run_iverilog.sh /tmp/cs256-uart-new-run
python3 proyecto_final/prototypes/uart_input/analyze.py
```

The retained manifests and `model-analysis.json` describe the experiment snapshot.
After PR #4 integration, `analyze.py` was adapted to the new hardware-block model
API; its current hash differs from the manifest. The UART RTL is unchanged.

The receiver test's `+reset_only` argument skips the large baud sweep for focused
debugging; the retained `rx.txt` is the complete sweep, not that shorter run.
The FIFO intentionally discards four full queues at coordinated reset; its
accepted/read totals differ by exactly those 256 commands.

The portable run directory is `/tmp/cs256-uart-portable-final`. The accepted
Vivado run is `/builds/uart-20261027-150541-280860` in the existing container,
mapped on the host beneath `/home/alan/.local/share/cs256-vivado/builds/`.
Its bitstream and checkpoints remain outside Git; the bitstream path/hash are
in `vivado-summary.json`. All four XSim runs and routed timing/skew acceptance
passed. Five structural CDC warnings remain explicitly documented and unwaived.
No physical-board operation is claimed. Roman's official independent tests and
the agreed phase/epoch integration are still required.

Reproduce the complete verified flow without a password prompt on this desktop:

```bash
bash proyecto_final/prototypes/uart_input/run.sh --docker
```

The approved launcher and revocation instructions are in
[tools/vivado/README.md](../../../tools/vivado/README.md).
