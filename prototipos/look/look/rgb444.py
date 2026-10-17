"""RGB444 colours (FPGA limit 2). Every colour in the viewer is a 12-bit word."""

TRANSPARENT = 0x000      # sprite tips / handout step 7: black is see-through
TINT_KEY = 0x0F0         # replaced by the Player (or Reward) colour
NEAR_BLACK = 0x111       # art uses this where it needs a visible black


def expand(c12: int) -> tuple:
    """12-bit word -> 8-bit RGB as the DAC levels look on screen (n * 17)."""
    return ((c12 >> 8) & 0xF) * 17, ((c12 >> 4) & 0xF) * 17, (c12 & 0xF) * 17


def quantize(r: int, g: int, b: int) -> int:
    """8-bit RGB -> 12-bit word, keeping the top 4 bits (png2coe's `v >> 4`)."""
    return ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)


def halve(c12: int) -> int:
    """Each channel shifted right once: a dim variant that costs no ROM."""
    return ((c12 >> 1) & 0x777)
