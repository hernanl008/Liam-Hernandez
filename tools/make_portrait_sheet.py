#!/usr/bin/env python3
"""Generates assets/sprites/portrait_sheet.png — NPC dialogue portraits.

The dialogue box showed the speaker's first letter in a coloured box
("K" for Kaya), which is a placeholder that reads as one. These are
head-and-shoulders busts instead.

One sheet, not six files: every separate PNG is a separate manual upload
(see AssetIds.generated.lua), so the whole cast rides on one asset and
PortraitSheet.lua crops per character at render time — same arrangement
as the fish roster in make_fish_sheet.py.

Cells are 32x32, 3 across. Keep the ORDER here in sync with the CELLS
table in PortraitSheet.lua.

Drawn in the player sprite's palette (sampled in
make_player_side_rows.py) so the cast looks like it belongs to the same
game as the character you walk around as.

Usage:
    python3 tools/make_portrait_sheet.py
"""

from __future__ import annotations

import os

from PIL import Image

CELL = 32
COLS = 3

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")

OUTLINE = (28, 10, 24, 255)
EYE = (24, 18, 22, 255)
CLEAR = (0, 0, 0, 0)
MOUTH = (150, 84, 74, 255)


class Cell:
    def __init__(self) -> None:
        self.px: dict[tuple[int, int], tuple[int, int, int, int]] = {}

    def set(self, x: int, y: int, color) -> None:
        if 0 <= x < CELL and 0 <= y < CELL:
            self.px[(x, y)] = color

    def rect(self, x0: int, y0: int, x1: int, y1: int, color) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, color)

    def outline(self) -> None:
        """Single-pixel keyline around the whole bust, matching the
        character sprite's treatment."""
        filled = set(self.px)
        for (x, y) in filled:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.px:
                    self.set(n[0], n[1], OUTLINE)

    def to_image(self) -> Image.Image:
        img = Image.new("RGBA", (CELL, CELL), CLEAR)
        for (x, y), color in self.px.items():
            img.putpixel((x, y), color)
        return img


def bust(
    skin,
    skin_shadow,
    hair,
    hair_light,
    cloth,
    *,
    style: str = "short",
    accent=None,
    eye_color=EYE,
) -> Image.Image:
    """One head-and-shoulders portrait.

    Every character shares this geometry -- same head box, same eye line,
    same shoulder line -- and differs only in colour, hair silhouette and
    one accessory. Consistent framing is what makes a cast read as one
    set rather than a pile of unrelated sprites, and it means the
    dialogue box never has to reposition per speaker.
    """
    c = Cell()

    # Shoulders first, so the head overlaps them.
    c.rect(5, 25, 26, 31, cloth)
    c.rect(9, 24, 22, 24, cloth)

    # Neck.
    c.rect(14, 22, 17, 25, skin_shadow)

    # Head: 14 wide, rounded by shortening the top and bottom rows.
    c.rect(10, 8, 21, 22, skin)
    c.rect(11, 7, 20, 7, skin)
    c.rect(12, 6, 19, 6, skin)
    c.rect(11, 23, 20, 23, skin)
    # Shade the right side of the face so it reads as lit from the left.
    c.rect(19, 9, 21, 22, skin_shadow)

    # Eyes on a shared line, with a highlight pixel each.
    c.rect(12, 14, 13, 15, eye_color)
    c.rect(18, 14, 19, 15, eye_color)
    c.set(13, 14, (232, 240, 248, 255))
    c.set(19, 14, (232, 240, 248, 255))
    # Mouth.
    c.rect(15, 19, 17, 19, MOUTH)

    # --- hair / headwear ------------------------------------------
    if style == "long":
        c.rect(9, 5, 22, 12, hair)
        c.rect(10, 4, 21, 4, hair)
        c.rect(8, 10, 9, 24, hair)  # falls past the shoulders
        c.rect(22, 10, 23, 24, hair)
        c.rect(11, 11, 20, 12, hair)  # fringe over the brow
        c.rect(12, 5, 17, 6, hair_light)
    elif style == "short":
        c.rect(9, 5, 22, 11, hair)
        c.rect(10, 4, 21, 4, hair)
        c.rect(11, 12, 15, 12, hair)  # swept fringe, one side only
        c.rect(12, 5, 16, 6, hair_light)
    elif style == "elder":
        # Receding hairline, and a beard framing the jaw.
        c.rect(9, 6, 22, 10, hair)
        c.rect(12, 5, 19, 5, hair)
        c.rect(9, 17, 10, 23, hair)
        c.rect(21, 17, 22, 23, hair)
        c.rect(11, 21, 20, 24, hair)  # beard
        c.rect(15, 19, 17, 19, hair)  # moustache covers the mouth
        c.rect(12, 6, 17, 7, hair_light)
    elif style == "chef":
        c.rect(9, 8, 22, 11, hair)
        # Toque: a tall white block, wider than the head.
        c.rect(8, 1, 23, 6, (246, 244, 238, 255))
        c.rect(9, 0, 22, 0, (246, 244, 238, 255))
        c.rect(9, 7, 22, 7, (214, 210, 202, 255))  # band
        c.rect(11, 2, 16, 3, (255, 255, 252, 255))
    elif style == "cap":
        c.rect(9, 7, 22, 11, hair)
        # Merchant's flat cap with a brim.
        c.rect(8, 3, 23, 7, cloth)
        c.rect(9, 2, 22, 2, cloth)
        c.rect(7, 8, 24, 8, hair_light)  # brim
        c.rect(11, 3, 16, 4, accent or cloth)
    elif style == "hood":
        c.rect(6, 3, 25, 12, cloth)
        c.rect(8, 2, 23, 2, cloth)
        c.rect(10, 9, 21, 13, hair)
        c.rect(6, 12, 7, 24, cloth)
        c.rect(24, 12, 25, 24, cloth)

    # Optional hair accent -- Kaya's blossom, and anything else that
    # needs one distinguishing mark at a glance.
    if accent is not None and style in ("long", "short"):
        c.rect(21, 6, 23, 8, accent)
        c.set(22, 7, (255, 250, 226, 255))

    c.outline()
    return c.to_image()


# Order IS the sheet order (row-major, 3 per row) — mirrored in
# PortraitSheet.lua.
CAST = [
    (
        "Kaya",
        lambda: bust(
            (255, 205, 158, 255), (226, 170, 122, 255),
            (74, 44, 36, 255), (118, 74, 56, 255),
            (206, 96, 118, 255),
            style="long", accent=(250, 178, 206, 255),
        ),
    ),
    (
        "ElderSouta",
        lambda: bust(
            (232, 190, 148, 255), (200, 158, 118, 255),
            (206, 206, 202, 255), (238, 238, 234, 255),
            (92, 108, 132, 255),
            style="elder",
        ),
    ),
    (
        "Ren",
        lambda: bust(
            (244, 198, 152, 255), (212, 166, 122, 255),
            (30, 34, 52, 255), (66, 74, 104, 255),
            (58, 72, 96, 255),
            style="hood",
        ),
    ),
    (
        "Hinano",
        lambda: bust(
            (250, 202, 156, 255), (220, 172, 126, 255),
            (44, 30, 26, 255), (84, 60, 48, 255),
            (222, 214, 200, 255),
            style="chef",
        ),
    ),
    (
        "Kaleb",
        lambda: bust(
            (226, 176, 126, 255), (196, 148, 102, 255),
            (58, 40, 28, 255), (150, 106, 62, 255),
            (150, 106, 62, 255),
            style="cap", accent=(198, 150, 78, 255),
        ),
    ),
    (
        "Generic",
        lambda: bust(
            (238, 196, 152, 255), (206, 166, 122, 255),
            (58, 48, 44, 255), (96, 82, 74, 255),
            (120, 116, 110, 255),
            style="short",
        ),
    ),
]


def main() -> None:
    rows = (len(CAST) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), CLEAR)
    for i, (_name, draw) in enumerate(CAST):
        sheet.paste(draw(), ((i % COLS) * CELL, (i // COLS) * CELL))
    path = os.path.join(ASSETS, "portrait_sheet.png")
    sheet.save(path)
    print(f"wrote assets/sprites/portrait_sheet.png {sheet.size} — order: {[n for n, _ in CAST]}")


if __name__ == "__main__":
    main()
