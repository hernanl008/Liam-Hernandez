#!/usr/bin/env python3
"""Generates assets/sprites/fish_sheet.png — every fish + pull item on ONE sheet.

One sheet instead of 11 separate PNGs because each upload is a manual,
human-only step (see tarmac.toml): a single Image asset covers the whole
roster, and FishingRig crops the right cell at runtime via a SurfaceGui
ImageLabel's ImageRectOffset (Decals/Textures can't crop; ImageLabels
can, and a SurfaceGui puts one on a world part). Cell map lives in
src/ReplicatedStorage/Modules/Shared/FishSpriteSheet.lua — keep the two
in sync if cells move.

Layout: 4 columns x 3 rows of 32x16 cells (128x48 total), row-major in
the order listed in SPECIES below. Style matches the rest of the
generated art: chunky pixels, dark outline, small palettes.
"""
from PIL import Image

CELL_W, CELL_H = 32, 16
COLS = 4

OUTLINE = (30, 24, 34, 255)


def px_put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c if len(c) == 4 else c + (255,))


def draw_fish(img, body, belly, fin, *, length=24, height=9, tail=6, eye_bright=True,
              serpent=False, angler=False, stripes=None):
    """Draws one fish into a CELL_W x CELL_H image, facing left."""
    cx0, cy = 2, CELL_H // 2
    body_w = length - tail
    # Body: horizontal ellipse-ish mass, or a thin wavy ribbon for serpents.
    for x in range(body_w):
        if serpent:
            wave = round(2.2 * __import__("math").sin(x * 0.55))
            half = 2
            yc = cy + wave
        else:
            t = x / max(body_w - 1, 1)
            half = max(1, round((height / 2) * (1 - (2 * t - 1) ** 2) ** 0.5)) if 0 < t < 1 else 1
            yc = cy
        for dy in range(-half, half + 1):
            shade = belly if dy > half // 2 else body
            px_put(img, cx0 + x, yc + dy, shade)
        # outline top/bottom
        px_put(img, cx0 + x, yc - half - 1, OUTLINE)
        px_put(img, cx0 + x, yc + half + 1, OUTLINE)
    # Tail: triangle at the right end.
    for i in range(tail):
        half = 1 + i // 2
        for dy in range(-half, half + 1):
            px_put(img, cx0 + body_w + i, cy + dy, fin)
        px_put(img, cx0 + body_w + i, cy - half - 1, OUTLINE)
        px_put(img, cx0 + body_w + i, cy + half + 1, OUTLINE)
    # Nose + eye at the left.
    px_put(img, cx0 - 1, cy, OUTLINE)
    eye = (250, 250, 250, 255) if eye_bright else (200, 190, 160, 255)
    px_put(img, cx0 + 3, cy - 1, eye)
    px_put(img, cx0 + 4, cy - 1, OUTLINE)
    # Dorsal fin bump.
    if not serpent:
        for x in range(body_w // 3, body_w // 3 + 4):
            px_put(img, cx0 + x, cy - height // 2 - 1, fin)
            px_put(img, cx0 + x, cy - height // 2 - 2, OUTLINE)
    # Vertical stripes.
    if stripes:
        for sx in range(6, body_w - 2, 5):
            for dy in range(-2, 3):
                px_put(img, cx0 + sx, cy + dy, stripes)
    # Anglerfish lure: stalk + glowing bulb over the head.
    if angler:
        for i in range(3):
            px_put(img, cx0 + 2, cy - height // 2 - 2 - i, OUTLINE)
        px_put(img, cx0 + 1, cy - height // 2 - 5, (255, 246, 170, 255))
        px_put(img, cx0 + 2, cy - height // 2 - 5, (255, 220, 90, 255))


def draw_driftwood(img):
    for x in range(4, 28):
        for dy in (-2, -1, 0, 1, 2):
            c = (120, 84, 48, 255) if dy in (-1, 0) else (96, 64, 36, 255)
            px_put(img, x, 8 + dy + (1 if x > 20 else 0), c)
        px_put(img, x, 5 + (1 if x > 20 else 0), OUTLINE)
        px_put(img, x, 11 + (1 if x > 20 else 0), OUTLINE)
    for x in range(8, 26, 6):  # grain lines
        px_put(img, x, 8, (78, 52, 30, 255))


def draw_boot(img):
    for y in range(3, 12):  # shaft
        for x in range(12, 18):
            px_put(img, x, y, (88, 60, 40, 255))
    for y in range(9, 13):  # foot
        for x in range(12, 24):
            px_put(img, x, y, (72, 48, 32, 255))
    for x in range(11, 25):  # sole
        px_put(img, x, 13, OUTLINE)
    for x in range(12, 18):
        px_put(img, x, 2, OUTLINE)


def draw_locket(img):
    import math
    for a in range(0, 360, 12):  # chain arc
        x = 16 + round(9 * math.cos(math.radians(a)))
        y = 5 + round(3 * math.sin(math.radians(a)))
        px_put(img, x, y, (180, 160, 120, 255))
    for dy in range(-3, 4):  # pendant
        for dx in range(-3, 4):
            if dx * dx + dy * dy <= 9:
                c = (212, 175, 96, 255) if dx - dy < 1 else (170, 130, 60, 255)
                px_put(img, 16 + dx, 10 + dy, c)
    px_put(img, 16, 10, (250, 236, 180, 255))


def draw_coin_pouch(img):
    for dy in range(-4, 5):  # bag
        half = round((1 - (dy / 5.5) ** 2) ** 0.5 * 6)
        for dx in range(-half, half + 1):
            c = (168, 128, 82, 255) if dx < 2 else (140, 104, 64, 255)
            px_put(img, 15 + dx, 9 + dy, c)
    for dx in range(-2, 3):  # tie
        px_put(img, 15 + dx, 4, (96, 64, 36, 255))
    for i, (dx, dy) in enumerate(((-6, 3), (7, 4), (8, 1))):  # spilled coins
        px_put(img, 15 + dx, 9 + dy, (255, 214, 90, 255))
        px_put(img, 16 + dx, 9 + dy, (212, 165, 60, 255))


# Order here IS the sheet order (row-major, 4 per row) — mirrored in
# FishSpriteSheet.lua.
SPECIES = [
    ("SilverMinnow", lambda im: draw_fish(im, (176, 196, 214, 255), (226, 236, 244, 255), (140, 160, 180, 255), length=16, height=6, tail=4)),
    ("MoonfinKoi", lambda im: draw_fish(im, (240, 240, 236, 255), (252, 252, 250, 255), (235, 130, 80, 255), stripes=(235, 130, 80, 255))),
    ("MoonlitSerpent", lambda im: draw_fish(im, (74, 96, 172, 255), (130, 150, 220, 255), (180, 200, 255, 255), length=27, serpent=True)),
    ("TrenchEel", lambda im: draw_fish(im, (96, 116, 88, 255), (140, 158, 128, 255), (70, 88, 66, 255), length=26, serpent=True)),
    ("BlightscaleCarp", lambda im: draw_fish(im, (122, 96, 140, 255), (150, 170, 110, 255), (90, 66, 108, 255), stripes=(104, 140, 80, 255))),
    ("AbyssalAnglerfish", lambda im: draw_fish(im, (52, 48, 66, 255), (84, 78, 102, 255), (40, 36, 52, 255), length=18, height=10, tail=4, angler=True)),
    ("GuardiansEcho", lambda im: draw_fish(im, (232, 202, 110, 255), (250, 232, 170, 255), (210, 170, 80, 255), height=10)),
    ("Generic", lambda im: draw_fish(im, (90, 170, 230, 255), (150, 210, 250, 255), (70, 140, 200, 255))),
    ("Driftwood", draw_driftwood),
    ("OldBoot", draw_boot),
    ("TarnishedLocket", draw_locket),
    ("SunkenCoinPouch", draw_coin_pouch),
]

rows = (len(SPECIES) + COLS - 1) // COLS
sheet = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H), (0, 0, 0, 0))
for i, (name, draw) in enumerate(SPECIES):
    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    draw(cell)
    sheet.paste(cell, ((i % COLS) * CELL_W, (i // COLS) * CELL_H))

sheet.save("assets/sprites/fish_sheet.png")
print(f"wrote assets/sprites/fish_sheet.png {sheet.size} — {len(SPECIES)} cells, order: {[n for n, _ in SPECIES]}")
