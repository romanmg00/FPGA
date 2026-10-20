"""Rule values and Arena geometry for the Game Model.

Every rule value marked 🔵 or ⏳ in CS-256 Tron Game Mechanics is a parameter
here, so the L2 lockdown can change a value without touching the rules.
Geometry follows the handout: 1280 x 800 visible pixels and a 10 px white
border; the Wall is the ring of Cells that covers that border.
"""

from dataclasses import dataclass, field

SCREEN_W = 1280                      # handout: curr_x 0..1279
SCREEN_H = 800                       # handout: curr_y 0..799
BORDER_PX = 10                       # handout Drawing Logic step 4
CELL_SIZES = (4, 8, 16)              # Development Plan, FPGA limit 4
HUD_ALIGN_PX = 16                    # HUD reservations stay on a 16 px grid


@dataclass(frozen=True)
class HudReserve:
    """Screen pixels kept out of the Arena for the HUD (0 = none)."""

    top: int = 0
    bottom: int = 0
    left: int = 0
    right: int = 0


@dataclass(frozen=True)
class ArenaGeometry:
    """Where the Arena's Cells sit on the screen and in the grid memory.

    The grid memory covers the whole screen, one word per Cell, with a
    power-of-two row stride so the address is the bit concatenation
    {cell_y, cell_x} of curr_y/curr_x slices. Cells outside the Arena
    interior (Wall ring, HUD area, stride padding) hold WALL.
    """

    cell_px: int = 8
    hud: HudReserve = field(default_factory=HudReserve)

    def __post_init__(self):
        if self.cell_px not in CELL_SIZES:
            raise ValueError(f"Cell size must be one of {CELL_SIZES}, got {self.cell_px}")
        for side in ("top", "bottom", "left", "right"):
            px = getattr(self.hud, side)
            if px < 0 or px % HUD_ALIGN_PX:
                raise ValueError(f"HUD {side} reserve must be a multiple of {HUD_ALIGN_PX} px, got {px}")
        if self.width < 8 or self.height < 8:
            raise ValueError("HUD reserve leaves no playable Arena")

    # Whole-screen grid in Cells
    @property
    def grid_w(self) -> int:
        return SCREEN_W // self.cell_px

    @property
    def grid_h(self) -> int:
        return SCREEN_H // self.cell_px

    @property
    def x_bits(self) -> int:
        return (self.grid_w - 1).bit_length()

    @property
    def y_bits(self) -> int:
        return (self.grid_h - 1).bit_length()

    @property
    def stride_w(self) -> int:
        return 1 << self.x_bits

    @property
    def stride_h(self) -> int:
        return 1 << self.y_bits

    @property
    def wall_cells(self) -> int:
        """Wall thickness in Cells: enough to cover the 10 px border."""
        return -(-BORDER_PX // self.cell_px)

    # Arena interior, in grid Cells: x0 <= x < x1, y0 <= y < y1
    @property
    def x0(self) -> int:
        return self.hud.left // self.cell_px + self.wall_cells

    @property
    def x1(self) -> int:
        return self.grid_w - self.hud.right // self.cell_px - self.wall_cells

    @property
    def y0(self) -> int:
        return self.hud.top // self.cell_px + self.wall_cells

    @property
    def y1(self) -> int:
        return self.grid_h - self.hud.bottom // self.cell_px - self.wall_cells

    @property
    def width(self) -> int:
        return self.x1 - self.x0

    @property
    def height(self) -> int:
        return self.y1 - self.y0

    def in_interior(self, x: int, y: int) -> bool:
        return self.x0 <= x < self.x1 and self.y0 <= y < self.y1

    def start_cells(self) -> tuple:
        """P1 at left-centre, P2 mirrored at right-centre (mechanics ✅)."""
        y = self.y0 + self.height // 2
        x1 = self.x0 + self.width // 4
        x2 = self.x1 - 1 - self.width // 4
        return (x1, y), (x2, y)


@dataclass(frozen=True)
class RuleParams:
    """Game rule values. 🔵 = proposed, ⏳ = waits for the size test."""

    lives: int = 3                          # ✅
    survival_bonus: int = 5                 # 🔵 +5
    points_cap: int = 99                    # 🔵 Points stop at 99
    reward_values: tuple = (3, 3, 5)        # 🔵 two +3 and one +5, one per slot
    frames_per_step: int = 4                # ⏳ K: frames between Steps (Bike speed)
    crash_freeze_frames: int = 120          # 🔵 about 2 s at 59.998 Hz
    next_round_needs_start: bool = True     # 🔵 after the freeze, wait for Start
    lfsr_seed: int = 0x1D2C_3B4A            # any non-zero 32-bit value

    def __post_init__(self):
        if len(self.reward_values) != 3:
            raise ValueError("Three Rewards are in the Arena at all times (mechanics ✅)")
        if self.frames_per_step < 1:
            raise ValueError("frames_per_step must be at least 1")
