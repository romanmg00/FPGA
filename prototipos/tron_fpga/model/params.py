"""Rule values and Arena geometry for the Game Model.

Constants use the names of `game_pkg` in the interface contract
(proyecto_final/, section 5) so the model and the HDL read the same values;
tests/test_model.py checks them against the contract. The values are the
agreed specification's (2026-10-20). Its layout and start Cells are a
working baseline the team may revise after testing: change them here, in
the contract and in a new ADR together.
"""

from dataclasses import dataclass

# Video (handout): 1280 x 800 visible pixels and a 10 px white border
SCREEN_W = 1280
SCREEN_H = 800
BORDER_PX = 10

# Grid: 16 px Cells, address {cy[5:0], cx[6:0]} over a padded 128 x 64 grid
TILE_SHIFT = 4
CELL_PX = 1 << TILE_SHIFT
GRID_W, GRID_H = 80, 50                  # Cells on screen
HUD_ROWS = 4                             # cy 0..3: the 64 px HUD band
CX_W, CY_W, ADDR_W = 7, 6, 13
PLAY_CX_MIN, PLAY_CX_MAX = 1, 78         # 78 x 44 playable Cells, inclusive
PLAY_CY_MIN, PLAY_CY_MAX = 5, 48         # Walls: cy 4, cy 49, cx 0, cx 79

# Rules, in ticks of the ~60 Hz game clock (ADR 0002)
STEP_TICKS = 6                           # one Cell every 6 ticks: ~10 Cells/s
LIVES_START = 3
REWARD_PTS0, REWARD_PTS1, REWARD_PTS2 = 1, 1, 3
SURVIVAL_BONUS = 3
CRASH_TICKS = 120                        # ~2 s Crash display
SCORE_VIEW_TICKS = 180                   # ~3 s per Scoreboard view
GOALS = (10, 20, 30, 40)                 # Points Goal by {SW15, SW14}

# Start Cells: P1 (20, 27) heading RIGHT, P2 (59, 27) heading LEFT
SAL_P1_CX, SAL_P2_CX, SAL_CY = 20, 59, 27

# Widths that hold every legal value without wrapping. The largest final
# total is 39 + 3 (Reward) + 3 (Survival Bonus) = 45 at the 40-Point Goal.
POINTS_MAX = max(GOALS) - 1 + max(REWARD_PTS0, REWARD_PTS1, REWARD_PTS2) + SURVIVAL_BONUS
POINTS_W = POINTS_MAX.bit_length()       # 6 bits
LIVES_W = LIVES_START.bit_length()       # 2 bits

GAME_HZ = 60.0                           # nominal; record the achieved Wizard/divider rate


def goal_from_switches(sw: int) -> int:
    """{SW15, SW14} as a 2-bit number: 00 -> 10 (default), 01 -> 20, 10 -> 30, 11 -> 40."""
    return GOALS[sw & 3]


class ArenaGeometry:
    """The agreed working layout, in Cells and pixels.

    The Arena memory covers the whole screen, one word per Cell, padded to
    128 x 64 so the address is the bit concatenation {cy, cx} of
    curr_y[9:4] and curr_x[10:4]. Every Cell outside the playable area (the
    HUD band, the Wall ring and the padding) holds WALL.
    """

    cell_px = CELL_PX
    x_bits, y_bits = CX_W, CY_W
    stride_w, stride_h = 1 << CX_W, 1 << CY_W
    hud_px = HUD_ROWS * CELL_PX
    # Playable Cells: x0 <= cx < x1, y0 <= cy < y1
    x0, x1 = PLAY_CX_MIN, PLAY_CX_MAX + 1
    y0, y1 = PLAY_CY_MIN, PLAY_CY_MAX + 1
    width, height = x1 - x0, y1 - y0

    def in_interior(self, x: int, y: int) -> bool:
        return self.x0 <= x < self.x1 and self.y0 <= y < self.y1

    def start_cells(self) -> tuple:
        return (SAL_P1_CX, SAL_CY), (SAL_P2_CX, SAL_CY)


GEOMETRY = ArenaGeometry()


@dataclass(frozen=True)
class RuleParams:
    """Rule values, defaulting to the agreed ones.

    Tests shorten timers and viewers may tune `step_ticks` for playtesting;
    the first build keeps the agreed speed. With `fixed_seed`, every new
    Match restarts the Reward generator from `seed` (repeatable tests);
    otherwise the Start tick is mixed into it (normal play).
    """

    lives: int = LIVES_START
    reward_values: tuple = (REWARD_PTS0, REWARD_PTS1, REWARD_PTS2)
    survival_bonus: int = SURVIVAL_BONUS
    step_ticks: int = STEP_TICKS
    crash_ticks: int = CRASH_TICKS
    score_view_ticks: int = SCORE_VIEW_TICKS
    seed: int = 0x1D2C_3B4A
    fixed_seed: bool = False

    def __post_init__(self):
        if len(self.reward_values) != 3:
            raise ValueError("There are exactly three Reward slots")
        if self.step_ticks < 1:
            raise ValueError("step_ticks must be at least 1")
