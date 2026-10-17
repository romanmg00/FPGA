# Look Prototype metrics (latest run)

Run 2026-10-17 16:32 on `Alan-Legion`, commit `69842fc`; Python 3.12.4, pygame-ce 2.5.8. History: `look-metrics.csv`. Regenerate with `python -m look.metrics` from `prototype/`, then commit both files.

Draw time is the PC viewer's work per 1280 x 800 frame (Game tick, Trail update, render, final colour stage), headless, 240 frames after 30 warm-up; the 60 fps budget is 16.7 ms. Build time is a renderer rebuild (look change).

Hardware columns are estimates against the XC7A100T and the handout timing: 270 RAMB18 halves; vertical blanking 563.6 us (47,040 pixel clocks). Arena clear and Reward placement assume one grid access per pixel clock.

| Configuration | Draw median / p95 (ms) | Build (ms) | RAMB18 | Effect tables (b) | Arena clear (us) | 2 placements (us) | RGB444 | White border | Lockdown flags |
|---|---|---|---|---|---|---|---|---|---|
| synthwave, 8 px | 9.96 / 10.59 | 279 | 15 (5.6%) | 7260 | 392.6 | 834.3 | yes | yes | Dim tint key 080: not in limit 3 yet |
| outrun, 8 px | 8.15 / 8.87 | 260 | 15 (5.6%) | 1128 | 392.6 | 834.3 | yes | yes | Dim tint key 080: not in limit 3 yet |
| classic, 8 px | 3.34 / 3.83 | 44 | 11 (4.1%) | 0 | 392.6 | 834.3 | yes | yes | none |
| synthwave, 4 px | 10.13 / 10.83 | 334 | 33 (12.2%) | 7260 | 1570.5 | 3190.0 | yes | yes | Arena clear 1,570 us > 563.6 us blanking; Dim tint key 080: not in limit 3 yet |
| synthwave, 16 px | 9.81 / 10.38 | 252 | 11 (4.1%) | 7260 | 98.2 | 245.4 | yes | yes | Dim tint key 080: not in limit 3 yet |
