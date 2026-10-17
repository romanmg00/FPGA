"""BRAM budget and Arena-clear time for the current look (FPGA limit 6).

Block counts are estimates from the 7-series block RAM aspect ratios; the
Block Memory Generator Summary and the synthesis report give the real
numbers. No pygame here.
"""

from dataclasses import dataclass

from model.arena import CELL_BITS

PIXEL_HZ = 83.46e6                 # handout pixel clock
BLANK_LINES = 28                   # vcount 827 and 0..26: full blank lines
LINE_CYCLES = 1680
BLANK_CYCLES = BLANK_LINES * LINE_CYCLES          # 47,040
BLANK_US = BLANK_CYCLES / PIXEL_HZ * 1e6          # about 563.6 us

RAMB36_TOTAL = 135                 # XC7A100T, DS180 Table 4
BRAM_KB_TOTAL = 4860

# (depth, width) shapes of one primitive (UG473 v1.14 Tables 1-11..1-14). The
# last shape of each is simple dual-port only, which a read-only ROM can use.
RAMB18_SHAPES = ((16384, 1), (8192, 2), (4096, 4), (2048, 9), (1024, 18), (512, 36))
RAMB36_SHAPES = ((32768, 1), (16384, 2), (8192, 4), (4096, 9), (2048, 18), (1024, 36), (512, 72))
LUT_ROM_BITS = 2048                # smaller ROMs may well be built from LUTs


def _ceil(a, b):
    return -(-a // b)


def _fit(shapes, width, depth):
    return min(_ceil(depth, d) * _ceil(width, w) for d, w in shapes)


def ramb18_equivalents(width: int, depth: int) -> int:
    """Best of RAMB18-only and RAMB36-only mappings, in RAMB18 halves."""
    return min(_fit(RAMB18_SHAPES, width, depth), 2 * _fit(RAMB36_SHAPES, width, depth))


@dataclass(frozen=True)
class Item:
    name: str
    instances: int
    width: int
    depth: int

    @property
    def bits(self) -> int:
        return self.instances * self.width * self.depth

    @property
    def ramb18(self) -> int:
        return self.instances * ramb18_equivalents(self.width, self.depth)

    @property
    def maybe_lut(self) -> bool:
        return self.width * self.depth <= LUT_ROM_BITS


def items(geom, bike_px, reward_px, reward_roms, font, icon_bits) -> list:
    return [
        Item(f"Bike ROM {bike_px}x{bike_px}", 2, 12, bike_px * bike_px),
        Item(f"Reward ROM {reward_px}x{reward_px}", reward_roms, 12, reward_px * reward_px),
        Item(f"Arena grid {geom.stride_w}x{geom.stride_h}", 1, CELL_BITS, geom.stride_w * geom.stride_h),
        Item(f"Digit font {font.glyph_w}x{font.glyph_h}", 1, 1, font.rom_bits),
        Item("HUD icons", 1, 1, icon_bits),
    ]


def clear_us(geom) -> float:
    """One write per pixel clock over the whole padded grid."""
    return geom.stride_w * geom.stride_h / PIXEL_HZ * 1e6
