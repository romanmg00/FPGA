"""The L1 candidate axes compared at the L2 lockdown, and their defaults.

Defaults are the design already recorded in the mechanics note and VGA plan
(8 px Cells, 32 x 32 Bike, P1 cyan, P2 orange), so unlocked items fall back
to them.
"""

from dataclasses import dataclass, replace

from model import HudReserve

PALETTES = {
    # RGB444 words. bg/grid/p1/p2/wall/hud_fg from the L1 research brief
    # (cyan vs orange, no red-green coding; colour-vision checks UNVERIFIED).
    # border = the handout's white 10 px frame.
    "classic": dict(bg=0x001, grid=0x112, wall=0x778, border=0xFFF,
                    p1=0x0FF, p2=0xF80, reward_small=0xFF0, reward_big=0xF0F,
                    hud_fg=0xFFF, hud_bg=0x000),
    "softer": dict(bg=0x011, grid=0x122, wall=0x899, border=0xFFF,
                   p1=0x6EF, p2=0xF93, reward_small=0xFE4, reward_big=0xE6F,
                   hud_fg=0xEEF, hud_bg=0x001),
    "strong": dict(bg=0x000, grid=0x111, wall=0x888, border=0xFFF,
                   p1=0xAFF, p2=0xD60, reward_small=0xFF0, reward_big=0xFFF,
                   hud_fg=0xFFF, hud_bg=0x000),
}

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
    bike_style: str = "cycle"
    reward_look: str = "gem"
    reward_size: str = "half-bike"
    palette: str = "classic"
    trail: str = "full"
    grid: str = "32px"
    anchor: str = "centre"
    font: str = "seg"
    digit_px: int = 32

    @property
    def reward_px(self) -> int:
        return self.bike_px // 2 if self.reward_size == "half-bike" else self.cell_px


# key label, field, choices. bike_style choices are filled in at run time
# because PNG art found in assets/ joins them.
AXES = [
    ("1", "hud", tuple(HUD_LAYOUTS)),
    ("2", "cell_px", (4, 8, 16)),
    ("3", "bike_px", (16, 32, 64)),
    ("4", "bike_style", ()),
    ("5", "reward_look", ("gem", "orb", "gem+star")),
    ("6", "reward_size", ("half-bike", "cell")),
    ("7", "palette", tuple(PALETTES)),
    ("8", "trail", ("full", "inset", "core")),
    ("9", "grid", ("off", "32px", "cell")),
    ("0", "anchor", ("centre", "nose")),
    ("F", "font", ("seg", "block")),
    ("H", "digit_px", (32, 48, 64)),
]

GEOMETRY_FIELDS = ("hud", "cell_px", "digit_px")       # changing these starts a new Match


def cycle(config: LookConfig, field: str, choices: tuple, step: int = 1) -> LookConfig:
    current = getattr(config, field)
    i = choices.index(current) if current in choices else -1
    return replace(config, **{field: choices[(i + step) % len(choices)]})
