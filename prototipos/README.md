# Compare Alan's Tron prototypes

Both games use **pygame-ce**, NumPy and Pillow. Use the same dedicated environment
for these two; Roman's `tron/main.py` uses its separate pygame environment.

Run each game in its own terminal from the repository root:

| Version | Folder | Window title |
|---|---|---|
| Preserved PR #2 game | `prototipos/tron/fpga/` | `CS-256 Tron - PR #2 comparison` |
| Newer hardware-block model | `prototipos/tron_fpga/` | `CS-256 Tron - FPGA model (PR #4)` |

```powershell
# PR #2 game
cd prototipos/tron/fpga
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m juego
```

```powershell
# Newer game
cd prototipos/tron_fpga
& "$env:USERPROFILE\.venvs\cs256-tron\Scripts\python.exe" -m juego
```

With that environment activated on Linux/macOS, use `python -m juego` in each
folder. See the [newer game's setup guide](tron_fpga/README.md#quick-start) to
create the environment and install dependencies.

Click a window to control it: **Space/Enter** starts, **arrows** control P1,
**WASD** control P2, **P** pauses, and **Esc** quits. The games have independent
state. Both games start with the synthwave appearance. The newer one retains the
agreed layout and rules, and omits the older sprites' legacy glow key. In the
newer game, **Shift+M** selects the plain `core` view from startup. **M** cycles presets.

The older source is pinned to PR #2 merge `0a8ef4bbafcdf09db847bcc7f966acf2249582eb`.
Its art is preserved in `assets/tron-pr2/`, independent of the newer assets.
Its rules are historical and do not establish the agreed specification.
The newer source comes from PR #4 commit `628430196aea57bb5b2cd2554ee89e1bcfccd126`;
its proposed HDL interfaces remain proposals, as described in its README.

Run each version's existing checks from its folder:

```sh
python -m unittest discover -s tests
```

Roman's original prototype remains at `tron/main.py` and is unchanged.
