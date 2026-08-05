#!/usr/bin/env python3
"""Generates horizontally-mirrored copies of the player sprite sheets.

The pack's character sheets only contain ONE side profile — facing
RIGHT (established by live observation: moving right looks correct,
moving left moonwalks; two earlier pixel-analysis attempts called it
left and were both wrong). Roblox has no way to mirror an ImageLabel at
runtime (a negative Size renders nothing rather than flipping), so
walking left moonwalked. These pre-mirrored sheets are the fix: the
controller picks the mirrored sheet when moving left.

Each 32x32 CELL is flipped individually, NOT the sheet as a whole —
flipping the whole image would also reverse column order, scrambling the
animation into playing backwards.
"""
from PIL import Image

CELL = 32

for name in ("player_idle", "player_walk"):
    src = Image.open(f"assets/sprites/{name}.png").convert("RGBA")
    cols, rows = src.width // CELL, src.height // CELL
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for r in range(rows):
        for c in range(cols):
            box = (c * CELL, r * CELL, c * CELL + CELL, r * CELL + CELL)
            cell = src.crop(box).transpose(Image.FLIP_LEFT_RIGHT)
            out.paste(cell, box)
    out.save(f"assets/sprites/{name}_mirror.png")
    print(f"wrote assets/sprites/{name}_mirror.png {out.size} ({cols}x{rows} cells)")
