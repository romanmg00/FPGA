"""Selected visual designs and temporary desktop-test defaults.

Synthwave and outrun are the final visual designs. Classic is a temporary
test-only view with its HUD enabled, and is the default while programming.
There is no core preset or live per-axis customization. Geometry and the
FPGA core scope remain governed by the agreement, not these PC settings.
"""

from dataclasses import dataclass

from .rgb444 import halve

_BASE = dict(border=0xFFF, p1=0x0FF, p2=0xF80, hud_fg=0xFFF, hud_bg=0x000,
             star=0xCCF, sun_hi=0xFC4, sun_lo=0xD2A)

PALETTES = {
    # RGB444 words. P1 cyan and P2 orange in every palette (agreed initial colours).
    # border = the handout's white 10 px frame. bg -> bg2 is the sky
    # gradient (top -> bottom); grid_glow is the neon halo; wall_line the
    # neon tube on the Wall edge.
    "synthwave": dict(_BASE, bg=0x001, bg2=0x506, floor=0x203, sky_low=0x205,
                      grid=0xD2E, grid_glow=0x304,
                      wall=0x101, wall_line=0xF4D, reward_small=0xFE3, reward_big=0xC8F,
                      sun_hi=0xFB4, sun_lo=0xC2A),
    "outrun": dict(_BASE, bg=0x002, bg2=0x613, floor=0x302, sky_low=0x403,
                   grid=0xF4A, grid_glow=0x302,
                   wall=0x001, wall_line=0x96F, reward_small=0xFF4, reward_big=0xAEF,
                   star=0xFFF, sun_hi=0xFE5, sun_lo=0xF26),
    # Temporary test palette; not a final visual design.
    "classic": dict(_BASE, bg=0x001, grid=0x112, wall=0x778,
                    reward_small=0xFF0, reward_big=0xF0F),
}
for _p in PALETTES.values():                 # fields older palettes leave out
    _p.setdefault("bg2", _p["bg"])
    _p.setdefault("floor", _p["bg"])
    _p.setdefault("sky_low", _p["bg2"])
    _p.setdefault("grid_glow", halve(_p["grid"]))
    _p.setdefault("wall_line", 0xFFF)

@dataclass(frozen=True)
class LookConfig:
    hud: str = "on"
    bike_style: str = "cycle"
    reward_look: str = "gem"
    palette: str = "classic"
    trail: str = "full"
    grid: str = "32px"
    font: str = "seg"
    bg: str = "plain"
    wall: str = "flat"
    reward_anim: str = "still"
    crash: str = "blink"
    crt: str = "off"
    bike_fx: str = "none"


# M cycles complete designs; individual fields are not keyboard candidates.
PRESETS = {
    "classic": {f: getattr(LookConfig(), f) for f in LookConfig.__dataclass_fields__},
    "synthwave": dict(hud="on", palette="synthwave", bg="sunset", grid="neon", wall="neon",
                      trail="pulse", bike_style="synth", reward_look="neon",
                      reward_anim="pulse", font="neon", crash="ring+flash", crt="scanlines",
                      bike_fx="none"),
    "outrun": dict(hud="on", palette="outrun", bg="stars", grid="neon", wall="neon",
                   trail="neon", bike_style="racer", reward_look="neon",
                   reward_anim="spin", font="chrome", crash="ring", crt="scanlines",
                   bike_fx="streaks"),
}

PRESET_STATUS = {"classic": "TEST ONLY", "synthwave": "FINAL DESIGN", "outrun": "FINAL DESIGN"}
DEFAULT_PRESET = "classic"
