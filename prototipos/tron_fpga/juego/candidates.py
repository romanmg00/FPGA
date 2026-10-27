"""Visual candidates for the viewer, and their defaults.

Geometry is not a candidate: Cells, sprite sizes and the 64 px HUD band are
the agreed working layout (model/params.py). The default "core" preset
draws only what the agreed core build draws: plain background, Walls,
Trails, Rewards and Bikes, with P1 cyan and P2 orange. Everything else
(the on-screen HUD, animated backgrounds, grid lines, glow-style effects,
scanlines, spinning or pulsing Rewards, the Crash ring and flash) comes
after the core in the agreed scope.
"""

from dataclasses import dataclass, replace

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
    # The three L1 research-brief palettes (colour-vision checks UNVERIFIED).
    "classic": dict(_BASE, bg=0x001, grid=0x112, wall=0x778,
                    reward_small=0xFF0, reward_big=0xF0F),
    "softer": dict(_BASE, bg=0x011, grid=0x122, wall=0x899, p1=0x6EF, p2=0xF93,
                   reward_small=0xFE4, reward_big=0xE6F, hud_fg=0xEEF, hud_bg=0x001),
    "strong": dict(_BASE, bg=0x000, grid=0x111, wall=0x888, p1=0xAFF, p2=0xD60,
                   reward_small=0xFF0, reward_big=0xFFF),
}
for _p in PALETTES.values():                 # fields older palettes leave out
    _p.setdefault("bg2", _p["bg"])
    _p.setdefault("floor", _p["bg"])
    _p.setdefault("sky_low", _p["bg2"])
    _p.setdefault("grid_glow", halve(_p["grid"]))
    _p.setdefault("wall_line", 0xFFF)

@dataclass(frozen=True)
class LookConfig:
    hud: str = "off"
    bike_style: str = "cycle"
    reward_look: str = "gem+star"
    palette: str = "classic"
    trail: str = "full"
    grid: str = "off"
    font: str = "seg"
    bg: str = "plain"
    wall: str = "flat"
    reward_anim: str = "still"
    crash: str = "blink"
    crt: str = "off"
    bike_fx: str = "none"


# key label, field, choices. bike_style choices are filled in at run time
# because PNG art found in assets/ joins them.
AXES = [
    ("1", "bike_style", ()),
    ("2", "reward_look", ("gem+star", "gem", "orb", "neon")),
    ("3", "palette", tuple(PALETTES)),
    ("4", "trail", ("full", "inset", "core", "neon", "pulse")),
    ("5", "grid", ("off", "32px", "cell", "neon", "floor")),
    ("H", "hud", ("off", "on")),
    ("F", "font", ("seg", "block", "neon", "chrome")),
    ("B", "bg", ("plain", "sky", "stars", "sunset")),
    ("N", "wall", ("flat", "neon")),
    ("R", "reward_anim", ("still", "pulse", "spin")),
    ("X", "crash", ("blink", "ring", "ring+flash")),
    ("C", "crt", ("off", "scanlines")),
    ("V", "bike_fx", ("none", "streaks")),
]

# Style presets (key M). "core" is the LookConfig default; the others show extras.
PRESETS = {
    "core": {f: getattr(LookConfig(), f) for f in LookConfig.__dataclass_fields__},
    "synthwave": dict(hud="on", palette="synthwave", bg="sunset", grid="neon", wall="neon",
                      trail="pulse", bike_style="synth", reward_look="neon",
                      reward_anim="pulse", font="neon", crash="ring+flash", crt="scanlines",
                      bike_fx="none"),
    "outrun": dict(hud="on", palette="outrun", bg="stars", grid="neon", wall="neon",
                   trail="neon", bike_style="racer", reward_look="neon",
                   reward_anim="spin", font="chrome", crash="ring", crt="scanlines",
                   bike_fx="streaks"),
    "classic": dict(hud="on", palette="classic", bg="plain", grid="32px", wall="flat",
                    trail="full", bike_style="cycle", reward_look="gem",
                    reward_anim="still", font="seg", crash="blink", crt="off",
                    bike_fx="none"),
}


def cycle(config: LookConfig, field: str, choices: tuple, step: int = 1) -> LookConfig:
    current = getattr(config, field)
    i = choices.index(current) if current in choices else -1
    return replace(config, **{field: choices[(i + step) % len(choices)]})
