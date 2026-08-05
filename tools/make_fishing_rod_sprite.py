#!/usr/bin/env python3
"""Generates assets/sprites/fishing_rod.png — a 32x32 pixel-art fishing rod.

The Farm RPG asset pack has no rod/tool sprite, so this draws one in a
matching style (chunky 16x16-era pixels, dark outline, 3-tone wood ramp)
sized to the same 32x32 cell the character sheets use. Committed as a
script rather than just the PNG so the art is reproducible/tweakable
without an image editor — same spirit as the earlier placeholder-art
generation pass.
"""
from PIL import Image

S = 32
OUTLINE = (46, 27, 16, 255)
WOOD_DARK = (90, 58, 34, 255)
WOOD_MID = (169, 113, 63, 255)
WOOD_LIGHT = (200, 154, 99, 255)
LINE = (232, 236, 240, 255)
BOB_RED = (198, 62, 52, 255)
BOB_WHITE = (240, 240, 240, 255)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
px = img.load()


def plot(x, y, c):
    if 0 <= x < S and 0 <= y < S:
        px[x, y] = c


def stroke(x0, y0, x1, y1, color, thickness=1):
    """Bresenham with a square brush, so diagonals read as solid pixel art."""
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    x, y = x0, y0
    while True:
        for ox in range(thickness):
            for oy in range(thickness):
                plot(x + ox, y + oy, color)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy


# Rod runs bottom-left (grip) to top-right (tip).
grip = ((7, 27), (12, 22))
shaft = ((12, 22), (26, 7))

# Outline pass first, then the fill drawn inside it.
stroke(grip[0][0], grip[0][1], shaft[1][0], shaft[1][1], OUTLINE, thickness=3)
stroke(shaft[0][0], shaft[0][1], shaft[1][0], shaft[1][1], WOOD_MID, thickness=2)
stroke(shaft[0][0], shaft[0][1], shaft[1][0] - 1, shaft[1][1] + 1, WOOD_LIGHT, thickness=1)
# Grip is darker + fatter than the shaft so the hand end reads distinctly.
stroke(grip[0][0], grip[0][1], grip[1][0], grip[1][1], WOOD_DARK, thickness=2)

# Reel: a small dark nub just above the grip.
for x in range(11, 15):
    for y in range(20, 23):
        plot(x, y, WOOD_DARK)
plot(11, 20, OUTLINE)
plot(14, 22, OUTLINE)

# Line: from the tip, out and down, with a slight slack curve.
stroke(26, 8, 29, 14, LINE, thickness=1)
stroke(29, 14, 28, 21, LINE, thickness=1)

# Bobber at the end of the line.
for x, y in [(27, 22), (28, 22), (27, 23), (28, 23)]:
    plot(x, y, BOB_RED)
for x, y in [(27, 24), (28, 24)]:
    plot(x, y, BOB_WHITE)
plot(26, 23, OUTLINE)
plot(29, 23, OUTLINE)
plot(27, 25, OUTLINE)
plot(28, 25, OUTLINE)

img.save("assets/sprites/fishing_rod.png")
print("wrote assets/sprites/fishing_rod.png", img.size)
