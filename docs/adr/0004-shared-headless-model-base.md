---
title: Use tron_fpga as the shared headless model base
status: accepted
created_at: "2026-10-28"
---

# Use tron_fpga as the shared headless model base

Use `prototipos/tron_fpga/model/` as the shared rules-model base for both
PC viewers and SystemVerilog verification, keeping existing prototype paths.
Roman selected this prototype in ADR 0003 item 6; Alan explicitly confirmed
this choice on 28 October 2026. Reusing the tested headless rules and scenarios
avoids introducing another rules implementation or relocating the package.

The agreed gameplay rules remain authoritative. Unverified hardware timing,
CDC, memory-service and rendering assumptions may change as evidence requires.
This selects the base; adapting Roman's viewer to consume it is still work to
complete. It does not accept the other proposed choices in ADR 0003 or claim
model/HDL equivalence, synthesized timing, or board verification.
