"""Sprite ROMs as the FPGA will hold them, drawn through ROM addressing.

A ROM is a row-by-row list of 12-bit words for square art pointing UP. The
viewer never rotates images: each Heading's picture is read through
`rom_address`, the same table as the VGA plan's `bike_addr`, so what the PC
shows is what the address logic will fetch.
"""

import os

import pygame

from model.turn_unit import DOWN, LEFT, RIGHT, UP

from . import art
from .rgb444 import TINT_KEY, TRANSPARENT, expand, quantize


BIKE_PX = 32
REWARD_PX = 16


def _checked(rom: "SpriteRom", side: int) -> "SpriteRom":
    """Flag art that is not at the agreed native size."""
    problem = f"{rom.name}: {rom.size}x{rom.size}, not the agreed {side}x{side}"
    if rom.size != side and problem not in rom.problems:
        rom.problems.append(problem)
    return rom


def rom_address(heading: int, dx: int, dy: int, bits: int) -> int:
    """VGA plan, bike_addr: address = {row, col}; ~ is a bitwise NOT."""
    m = (1 << bits) - 1
    if heading == UP:
        row, col = dy, dx
    elif heading == DOWN:
        row, col = m - dy, m - dx
    elif heading == RIGHT:
        row, col = m - dx, dy
    else:  # LEFT
        row, col = dx, m - dy
    return (row << bits) | col


class SpriteRom:
    def __init__(self, name: str, size: int, words: list, source: str, problems=()):
        self.name = name
        self.size = size
        self.words = words
        self.source = source          # "generated" or a PNG path
        self.problems = list(problems)
        self._surfaces = {}

    @property
    def bits(self) -> int:
        return (self.size - 1).bit_length()

    def surface(self, heading: int, tint: int) -> pygame.Surface:
        key = (heading, tint)
        if key not in self._surfaces:
            s = self.size
            surf = pygame.Surface((s, s))
            for dy in range(s):
                for dx in range(s):
                    w = self.words[rom_address(heading, dx, dy, self.bits)]
                    if w == TINT_KEY:
                        w = tint
                    surf.set_at((dx, dy), expand(w))
            surf.set_colorkey(expand(TRANSPARENT))
            self._surfaces[key] = surf
        return self._surfaces[key]


def load_png(path: str, name: str) -> SpriteRom:
    """Read a PNG the way png2coe.py will: row by row, `v >> 4` per channel."""
    img = pygame.image.load(path)
    w, h = img.get_size()
    problems = []
    if w != h:
        problems.append(f"{name}: {w}x{h} is not square")
    if w & (w - 1):
        problems.append(f"{name}: side {w} is not a power of two")
    size = min(w, h)
    words = []
    for y in range(size):
        for x in range(size):
            r, g, b, a = img.get_at((x, y))
            words.append(TRANSPARENT if a < 128 else quantize(r, g, b))
    if size & (size - 1):
        size = 1 << (size.bit_length() - 1)
        words = [words[y * min(w, h) + x] for y in range(size) for x in range(size)]
    return SpriteRom(name, size, words, path, problems)


class SpriteLibrary:
    """Bike and Reward ROMs by (kind, style), from assets/ or generated, at
    the agreed native sizes: 32 x 32 Bikes (1024 words), 16 x 16 Rewards (256)."""

    def __init__(self, assets_dir: str):
        self.assets_dir = assets_dir
        self.cache = {}
        self.png_bikes = {}
        if os.path.isdir(assets_dir):
            for f in sorted(os.listdir(assets_dir)):
                if f.startswith("bike-") and f.endswith(".png"):
                    self.png_bikes["png:" + f[5:-4]] = os.path.join(assets_dir, f)

    def bike_styles(self) -> tuple:
        return tuple(art.BIKE_STYLES) + tuple(self.png_bikes)

    def bike(self, style: str) -> SpriteRom:
        if style in self.png_bikes:
            rom = self._get(("bike", style), lambda: load_png(self.png_bikes[style], style))
        else:
            rom = self._generated(f"bike-{style}-{BIKE_PX}", art.BIKE_STYLES[style], BIKE_PX)
        return _checked(rom, BIKE_PX)

    def reward(self, look: str, kind: int) -> SpriteRom:
        fn = art.REWARD_LOOKS[look][kind]
        name = f"reward-{fn.__name__[7:].replace('_', '-')}-{REWARD_PX}"
        return _checked(self._generated(name, fn, REWARD_PX), REWARD_PX)

    def _generated(self, name, fn, size):
        def make():
            path = os.path.join(self.assets_dir, "candidates", name + ".png")
            if os.path.exists(path):
                return load_png(path, name)
            return SpriteRom(name, size, fn(size), "generated")
        return self._get(name, make)

    def _get(self, key, make):
        if key not in self.cache:
            self.cache[key] = make()
        return self.cache[key]
