#!/usr/bin/env python3
"""Generates assets/tiles/water.png — a seamlessly tiling pixel-art water tile.

The asset pack shipped no usable water tile (its tileset is corrupt, see
GDD.md §15), so this draws one. Seamless in BOTH axes: every wave uses a
sine whose wave-count over the tile is an integer, so copies laid edge to
edge line up with no seam — which matters because the cove is a grid of
these (MapConfig.Grid) and any seam would read as a hard lattice.

Style is classic top-down pixel water: a mottled blue base with broken
horizontal wave crests, rather than a smooth gradient. Motion is NOT
baked in as frames — WaterController.lua scrolls this single texture's
Texture.OffsetStudsU/V with a per-tile random phase and speed, which
reads as randomized drifting waves while staying one uploaded asset.
"""
import math
import random
from PIL import Image

S = 64
BLOCK = 2  # chunky pixel size, so it still reads as pixel art at 8 studs

DEEP = (40, 100, 175)
MID = (66, 148, 235)
LIGHT = (120, 194, 248)
FOAM = (205, 236, 255)

random.seed(7)  # fixed: regenerating shouldn't churn the committed art

img = Image.new("RGBA", (S, S), MID + (255,))
px = img.load()


def put(x, y, c):
    px[x % S, y % S] = c + (255,)


def put_block(x, y, c):
    """Paint one BLOCK-aligned chunk so output stays chunky."""
    bx, by = (x // BLOCK) * BLOCK, (y // BLOCK) * BLOCK
    for oy in range(BLOCK):
        for ox in range(BLOCK):
            put(bx + ox, by + oy, c)


# Base depth mottling — kept very subtle. An earlier pass made these
# strong enough to read as dark holes punched in the water.
for y in range(0, S, BLOCK):
    for x in range(0, S, BLOCK):
        v = math.sin(2 * math.pi * x / S + 1.3) + math.sin(2 * math.pi * 2 * y / S)
        if v < -1.55:
            put_block(x, y, DEEP)

# Wave crests: short, near-horizontal dashes. Amplitude is deliberately
# small (one chunk) — an earlier pass used three, which sheared the
# dashes into diagonal streaks that read as rain, not water.
for row_y, phase, waves in ((6, 0.0, 1), (18, 1.9, 2), (30, 0.7, 1), (42, 2.4, 2), (54, 1.1, 1)):
    for x in range(0, S, BLOCK):
        dy = round(math.sin(2 * math.pi * waves * x / S + phase))
        y = row_y + dy * BLOCK

        # Long dashes with clear gaps, offset per row so rows don't align.
        gap = (x // BLOCK + int(phase * 4)) % 13
        if gap < 7:
            put_block(x, y, LIGHT)
            if gap in (2, 3):
                put_block(x, y - BLOCK, FOAM)

img.save("assets/tiles/water.png")
print("wrote assets/tiles/water.png", img.size)
