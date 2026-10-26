"""The L1 candidate axes compared at the L2 lockdown, and their defaults.

Sizes default to the design already recorded in the mechanics note and VGA
plan (8 px Cells, 32 x 32 Bike, P1 cyan, P2 orange), so unlocked items fall
back to them. The style axes default to the "synthwave" preset.
"""

from dataclasses import dataclass, replace

from model import HudReserve

from .rgb444 import halve

_BASE = dict(border=0xFFF, p1=0x0FF, p2=0xF80, hud_fg=0xFFF, hud_bg=0x000,
             star=0xCCF, sun_hi=0xFC4, sun_lo=0xD2A)

PALETTES = {
    # RGB444 words. P1 cyan and P2 orange in every palette (mechanics 🔵).
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

HUD_LAYOUTS = ("top", "sides", "corners")


def hud_reserve(layout: str, digit_px: int) -> HudReserve:
    """Screen area kept out of the Arena; the top band grows with the digits."""
    if layout == "top":
        return HudReserve(top=-(-(10 + digit_px + 6) // 16) * 16)
    if layout == "sides":
        return HudReserve(left=96, right=96)
    return HudReserve()


@dataclass(frozen=True)
class LookConfig:
    hud: str = "top"
    cell_px: int = 8
    bike_px: int = 32
    bike_style: str = "synth"
    reward_look: str = "neon"
    reward_size: str = "half-bike"
    palette: str = "synthwave"
    trail: str = "pulse"
    grid: str = "neon"
    anchor: str = "centre"
    font: str = "neon"
    digit_px: int = 32
    bg: str = "sunset"
    wall: str = "neon"
    reward_anim: str = "pulse"
    crash: str = "ring+flash"
    crt: str = "scanlines"
    bike_fx: str = "glow"

    def reward_px(self, bike_px: int) -> int:
        """bike_px is the loaded Bike ROM's side (a PNG Bike keeps its own)."""
        return bike_px // 2 if self.reward_size == "half-bike" else self.cell_px


# key label, field, choices. bike_style choices are filled in at run time
# because PNG art found in assets/ joins them.
AXES = [
    ("1", "hud", tuple(HUD_LAYOUTS)),
    ("2", "cell_px", (4, 8, 16)),
    ("3", "bike_px", (16, 32, 64)),
    ("4", "bike_style", ()),
    ("5", "reward_look", ("neon", "gem", "orb", "gem+star")),
    ("6", "reward_size", ("half-bike", "cell")),
    ("7", "palette", tuple(PALETTES)),
    ("8", "trail", ("pulse", "neon", "full", "inset", "core")),
    ("9", "grid", ("neon", "floor", "off", "32px", "cell")),
    ("0", "anchor", ("centre", "nose")),
    ("F", "font", ("neon", "chrome", "seg", "block")),
    ("H", "digit_px", (32, 48, 64)),
    ("B", "bg", ("sunset", "stars", "sky", "plain")),
    ("N", "wall", ("neon", "flat")),
    ("R", "reward_anim", ("pulse", "spin", "still")),
    ("X", "crash", ("ring+flash", "ring", "blink")),
    ("C", "crt", ("scanlines", "off")),
    ("V", "bike_fx", ("glow", "streaks", "none")),
]

GEOMETRY_FIELDS = ("hud", "cell_px", "digit_px")       # changing these starts a new Match

# Style presets (key M). Sizes and HUD layout are left alone.
PRESETS = {
    "synthwave": dict(palette="synthwave", bg="sunset", grid="neon", wall="neon",
                      trail="pulse", bike_style="synth", reward_look="neon",
                      reward_anim="pulse", font="neon", crash="ring+flash", crt="scanlines",
                      bike_fx="glow"),
    "outrun": dict(palette="outrun", bg="stars", grid="neon", wall="neon",
                   trail="neon", bike_style="racer", reward_look="neon",
                   reward_anim="spin", font="chrome", crash="ring", crt="scanlines",
                   bike_fx="streaks"),
    "classic": dict(palette="classic", bg="plain", grid="32px", wall="flat",
                    trail="full", bike_style="cycle", reward_look="gem",
                    reward_anim="still", font="seg", crash="blink", crt="off",
                    bike_fx="none"),
}


def cycle(config: LookConfig, field: str, choices: tuple, step: int = 1) -> LookConfig:
    current = getattr(config, field)
    i = choices.index(current) if current in choices else -1
    return replace(config, **{field: choices[(i + step) % len(choices)]})
