#!/usr/bin/env python3
"""Generates the four ground tiles: grass, path, sakura_grass, tilled_soil.

Why this exists
---------------
These four PNGs existed but were placeholders from the very first art
pass, and they were worse than nothing:

    grass.png         16x16, 1 colour   <- a flat fill
    sakura_grass.png  16x16, 2 colours
    path.png          16x16, 3 colours
    tilled_soil.png   16x16, 3 colours

grass.png being a single colour means uploading it would look *identical*
to MapConfig's fallbackColor -- so the ground had no way to stop reading
as flat coloured blocks no matter what the pipeline did. That is the real
reason the cove's ground looks untextured; it was never a code bug.

These are redrawn at 64x64 with BLOCK=2 chunky pixels, matching
water.png (make_water_tile.py) so the ground and the water read as the
same art style at the same apparent resolution.

Seamless in both axes: every shape is plotted through put()/put_block(),
which wrap with `% S`, so anything crossing an edge reappears on the
opposite side. That matters more here than for a single decorative
sprite -- the cove is a grid of these (MapConfig.Grid), and any seam
reads as a hard lattice over the whole map. Sine-based features keep
integer wave counts over the tile for the same reason (see
make_water_tile.py, where a dash period that didn't divide the tile's
block count evenly put a visible seam at every boundary).

Base colours match each tile's MapConfig fallbackColor, so a tile that
hasn't been uploaded yet blends with its neighbours that have instead of
jumping to a different hue.

Usage:
    python3 tools/make_ground_tiles.py
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image

S = 64
BLOCK = 2

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "tiles")

# --- palettes ------------------------------------------------------
# The first entry of each is that tile's MapConfig fallbackColor.
GRASS_BASE = (58, 168, 74)
GRASS_DARK = (40, 136, 58)
GRASS_MID = (76, 186, 88)
GRASS_LIGHT = (112, 208, 112)

PATH_BASE = (222, 198, 156)
PATH_DARK = (188, 162, 120)
PATH_STONE = (172, 162, 150)
PATH_LIGHT = (240, 222, 188)

PETAL_LIGHT = (250, 190, 214)
PETAL_DARK = (230, 142, 178)

SOIL_BASE = (104, 68, 44)
SOIL_DARK = (74, 46, 28)
SOIL_RIDGE = (134, 96, 64)
SOIL_LIGHT = (158, 118, 82)


class Tile:
    """A 64x64 buffer whose plotting wraps, so every shape tiles."""

    def __init__(self, base: tuple[int, int, int]) -> None:
        self.img = Image.new("RGBA", (S, S), base + (255,))
        self.px = self.img.load()

    def put(self, x: int, y: int, c: tuple[int, int, int]) -> None:
        self.px[x % S, y % S] = c + (255,)

    def block(self, x: int, y: int, c: tuple[int, int, int]) -> None:
        """Paint one BLOCK-aligned chunk, so output stays chunky rather
        than dissolving into single-pixel noise at map scale."""
        bx, by = (x // BLOCK) * BLOCK, (y // BLOCK) * BLOCK
        for oy in range(BLOCK):
            for ox in range(BLOCK):
                self.put(bx + ox, by + oy, c)

    def save(self, name: str) -> None:
        path = os.path.join(ASSETS, name)
        self.img.save(path)
        print(f"wrote assets/tiles/{name} {self.img.size}")


def mottle(t: Tile, dark, light, *, waves_x: int, waves_y: int, dark_at: float, light_at: float) -> None:
    """Two-tone organic variation from summed sines. Integer wave counts
    keep it seamless; a plain random() fill would tile too but reads as
    static rather than as ground."""
    for y in range(0, S, BLOCK):
        for x in range(0, S, BLOCK):
            v = math.sin(2 * math.pi * waves_x * x / S + 0.7) + math.sin(2 * math.pi * waves_y * y / S + 2.1)
            if v < dark_at:
                t.block(x, y, dark)
            elif v > light_at:
                t.block(x, y, light)


def grass() -> Tile:
    t = Tile(GRASS_BASE)
    mottle(t, GRASS_DARK, GRASS_MID, waves_x=2, waves_y=3, dark_at=-1.35, light_at=1.35)
    # Blade tufts: a 2-chunk vertical tick with a lighter tip. Scattered
    # on a fixed seed so regenerating doesn't churn the committed art.
    rng = random.Random(11)
    for _ in range(34):
        x = rng.randrange(0, S, BLOCK)
        y = rng.randrange(0, S, BLOCK)
        t.block(x, y, GRASS_DARK)
        t.block(x, y - BLOCK, GRASS_MID)
        if rng.random() < 0.45:
            t.block(x, y - 2 * BLOCK, GRASS_LIGHT)
    return t


def sakura_grass() -> Tile:
    # Same ground as grass so the two read as one continuous lawn with
    # petals drifted over part of it, not as two different terrains.
    t = grass()
    rng = random.Random(23)
    for _ in range(26):
        x = rng.randrange(0, S, BLOCK)
        y = rng.randrange(0, S, BLOCK)
        # Petals are a 2-chunk sliver rather than a dot -- a single chunk
        # at this scale reads as dirt speckle, not blossom.
        t.block(x, y, PETAL_LIGHT)
        t.block(x + BLOCK, y, PETAL_DARK if rng.random() < 0.5 else PETAL_LIGHT)
        if rng.random() < 0.3:
            t.block(x, y + BLOCK, PETAL_DARK)
    return t


def path() -> Tile:
    t = Tile(PATH_BASE)
    mottle(t, PATH_DARK, PATH_LIGHT, waves_x=3, waves_y=2, dark_at=-1.2, light_at=1.25)
    # Embedded stones: small blobs with a lit top edge and a shadowed
    # bottom, which is what makes gravel read as 3D at this size.
    rng = random.Random(5)
    for _ in range(18):
        x = rng.randrange(0, S, BLOCK)
        y = rng.randrange(0, S, BLOCK)
        w = rng.choice((1, 2))
        for i in range(w):
            t.block(x + i * BLOCK, y, PATH_STONE)
            t.block(x + i * BLOCK, y + BLOCK, PATH_DARK)
        t.block(x, y - BLOCK, PATH_LIGHT)
    return t


def tilled_soil() -> Tile:
    t = Tile(SOIL_BASE)
    mottle(t, SOIL_DARK, SOIL_RIDGE, waves_x=2, waves_y=2, dark_at=-1.4, light_at=1.3)
    # Furrows: evenly spaced horizontal ridges, the visual shorthand for
    # worked soil. 64 / 8 == 8 rows exactly, so the spacing continues
    # across tile boundaries instead of stuttering at every edge.
    for row in range(0, S, 8):
        for x in range(0, S, BLOCK):
            wobble = round(math.sin(2 * math.pi * 2 * x / S + row)) * BLOCK
            t.block(x, row + wobble, SOIL_RIDGE)
            t.block(x, row + wobble + BLOCK, SOIL_DARK)
    # A few clods catching the light, so the furrows don't read as stripes.
    rng = random.Random(17)
    for _ in range(14):
        t.block(rng.randrange(0, S, BLOCK), rng.randrange(0, S, BLOCK), SOIL_LIGHT)
    return t


def main() -> None:
    grass().save("grass.png")
    sakura_grass().save("sakura_grass.png")
    path().save("path.png")
    tilled_soil().save("tilled_soil.png")


if __name__ == "__main__":
    main()
