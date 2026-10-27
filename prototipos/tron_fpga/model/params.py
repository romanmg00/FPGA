"""Shared constants: the Python copy of `game_pkg.sv`.

Names follow `game_pkg` in the interface contract (proyecto_final/,
section 5) so the model and the HDL read the same values;
tests/test_model.py checks them against the contract. Rule values are the
agreed specification's (2026-10-20). Its layout and start Cells are a
working baseline the team may revise after testing: change them here, in
the contract and in a new ADR together.

The block marked PROPOSAL holds values this model needs for the slow/fast
service boundary (X1). They follow the recommended architecture in the
Opus 5.5 Architecture and Integration Review, section 5, and are not team
decisions yet; see docs/design/CS-256 Tron Game Model Hardware Map.md.
"""

from dataclasses import dataclass

# --- Video (handout): 1280 x 800 visible pixels and a 10 px white border ---
SCREEN_W = 1280
SCREEN_H = 800
BORDER_PX = 10

# --- Grid: 16 px Cells, address {cy[5:0], cx[6:0]} over a padded 128 x 64 grid ---
TILE_SHIFT = 4
CELL_PX = 1 << TILE_SHIFT
GRID_W, GRID_H = 80, 50                  # Cells on screen
HUD_ROWS = 4                             # cy 0..3: the 64 px HUD band
CX_W, CY_W, ADDR_W = 7, 6, 13
PLAY_CX_MIN, PLAY_CX_MAX = 1, 78         # 78 x 44 playable Cells, inclusive
PLAY_CY_MIN, PLAY_CY_MAX = 5, 48         # Walls: cy 4, cy 49, cx 0, cx 79

# --- Cell contents (CELL_*), the same in the model and the HDL ---
CELL_EMPTY = 0
CELL_WALL = 1                            # Wall or any inaccessible Cell (HUD band, padding)
CELL_P1_TRAIL, CELL_P1_HEAD = 2, 3
CELL_P2_TRAIL, CELL_P2_HEAD = 4, 5
CELL_CRASH = 6                           # defined by the agreement; this model does not write it
CELL_RESERVED = 7
CELL_REWARD0 = 8                         # Reward slots 0..2 are codes 8..10
CELL_BITS = 4

# --- Headings (DIR_*): turning right adds 1 (mod 4) ---
DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT = 0, 1, 2, 3

# --- Game states (G_*): contract proposal, plus G_PREP (this model's proposal) ---
G_IDLE, G_PLAY, G_CRASH, G_READY, G_MATCH = 0, 1, 2, 3, 4
G_PREP = 5                               # waiting for PREPARE: Arena clear, heads, three Rewards
PHASE_NAMES = ("IDLE", "PLAY", "CRASH", "READY", "MATCH_OVER", "PREP")

# --- Board buttons: bit positions in btn[4:0] ---
BTN_U, BTN_D, BTN_L, BTN_R, BTN_C = 0, 1, 2, 3, 4
SW_PAUSE = 0                             # sw[0]
SW_GOAL_LSB = 14                         # sw[15:14]

# --- Rules, in ticks of the ~60 Hz game clock (ADR 0002) ---
STEP_TICKS = 6                           # one Cell every 6 ticks: ~10 Cells/s
LIVES_START = 3
REWARD_PTS0, REWARD_PTS1, REWARD_PTS2 = 1, 1, 3
SURVIVAL_BONUS = 3
CRASH_TICKS = 120                        # ~2 s Crash display
SCORE_VIEW_TICKS = 180                   # ~3 s per Scoreboard view
GOALS = (10, 20, 30, 40)                 # Points Goal by {SW15, SW14}

# --- Start Cells: P1 (20, 27) heading RIGHT, P2 (59, 27) heading LEFT ---
SAL_P1_CX, SAL_P2_CX, SAL_CY = 20, 59, 27

# --- Widths that hold every legal value without wrapping ---
# The largest final total is 39 + 3 (Reward) + 3 (Survival Bonus) = 45 at goal 40.
POINTS_MAX = max(GOALS) - 1 + max(REWARD_PTS0, REWARD_PTS1, REWARD_PTS2) + SURVIVAL_BONUS
POINTS_W = POINTS_MAX.bit_length()       # 6 bits
LIVES_W = LIVES_START.bit_length()       # 2 bits

# --- PROPOSAL: slow/fast service boundary (X1), not yet agreed ---
SYNC_STAGES = 2          # 2-FF synchronizer on switches in the game domain
STEP_LATENCY = 2         # ticks from a Step launch (READ2) to its registered outcome
MIN_STEP_TICKS = 4       # launch, outcome (+2), COMMIT done seen (+4): next launch
SEQ_W = 4                # mailbox command sequence number
SERVICE_WINDOW = 1 << 18 # fast-domain cycles a command may take after the tick (~3.1 ms)
LFSR_SEED = 0x1D2C_3B4A  # reset value and fixed-seed value of the Reward LFSR
RANDOM_DRAWS = 64        # Reward placement: LFSR candidates before the address scan

PIX_HZ = 83.46e6
GAME_HZ = 60.0           # nominal; record the achieved Wizard/divider rate


def goal_from_switches(sw: int) -> int:
    """{SW15, SW14} as a 2-bit number: 00 -> 10 (default), 01 -> 20, 10 -> 30, 11 -> 40."""
    return GOALS[sw & 3]


class ArenaGeometry:
    """The agreed working layout, in Cells and pixels.

    The Arena memory covers the whole screen, one word per Cell, padded to
    128 x 64 so the address is the bit concatenation {cy, cx} of
    curr_y[9:4] and curr_x[10:4] (curr_y is 11 bits wide, but bit 10 is
    always 0 for rows 0..799). Every Cell outside the playable area (the
    HUD band, the Wall ring and the padding) holds CELL_WALL.
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
DEFAULT_STARTS = ((SAL_P1_CX, SAL_CY, DIR_RIGHT), (SAL_P2_CX, SAL_CY, DIR_LEFT))


@dataclass(frozen=True)
class RuleParams:
    """Rule values, defaulting to the agreed ones.

    These stand for HDL module parameters. Tests shorten timers, scenarios
    may move the start Cells (a testbench parameter, needed for a same-Cell
    Head-on, which the mirrored starts cannot reach), and viewers may tune
    `step_ticks` for playtesting; the first build keeps the agreed values.
    With `fixed_seed`, every new Match restarts the Reward LFSR from `seed`
    (repeatable tests); otherwise the Start tick is mixed into it.
    """

    lives: int = LIVES_START
    reward_values: tuple = (REWARD_PTS0, REWARD_PTS1, REWARD_PTS2)
    survival_bonus: int = SURVIVAL_BONUS
    step_ticks: int = STEP_TICKS
    crash_ticks: int = CRASH_TICKS
    score_view_ticks: int = SCORE_VIEW_TICKS
    seed: int = LFSR_SEED
    fixed_seed: bool = False
    starts: tuple = DEFAULT_STARTS       # ((cx, cy, heading) for P1, for P2)

    def __post_init__(self):
        if len(self.reward_values) != 3:
            raise ValueError("There are exactly three Reward slots")
        if self.step_ticks < MIN_STEP_TICKS:
            raise ValueError(f"step_ticks must be at least {MIN_STEP_TICKS}: a Step needs "
                             "a READ2 and a COMMIT round trip through the mailbox")
        if self.crash_ticks < 1 or self.score_view_ticks < 1:
            raise ValueError("timers must be at least one tick")
        for x, y, _ in self.starts:
            if not GEOMETRY.in_interior(x, y):
                raise ValueError(f"start Cell {(x, y)} is not playable")
