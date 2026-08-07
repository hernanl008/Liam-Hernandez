#!/usr/bin/env python3
"""Generates assets/sprites/perk_icons.png — one icon per skill-tree perk.

Nine perks, one sheet, 3 across at 32x32. Every separate PNG is a
separate manual upload (see AssetIds.generated.lua), so the whole tree
rides on one asset and SkillTreeUI crops per perk at render time — same
arrangement as the fish roster and the NPC portraits.

Keep the ORDER here in sync with PERK_ICON_CELLS in SkillTreeUI.lua.

Each icon is a flat pictograph on transparent background, drawn in the
tree's own bronze/parchment palette rather than full colour: the node
tints them at render time (unlocked bronze, locked grey), and an icon
carrying its own colours would fight that.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

CELL = 32
COLS = 3

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")

INK = (44, 26, 16, 255)
MID = (110, 74, 44, 255)
LIGHT = (176, 128, 76, 255)
CLEAR = (0, 0, 0, 0)


def new_cell() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (CELL, CELL), CLEAR)
    return img, ImageDraw.Draw(img)


# --- Farming ---------------------------------------------------------


def green_thumb() -> Image.Image:
    """A sprout with two leaves — the bonus-crop perk."""
    img, d = new_cell()
    d.rectangle([15, 14, 16, 26], fill=INK)  # stem
    d.ellipse([7, 11, 15, 19], fill=MID)  # left leaf
    d.ellipse([16, 8, 24, 16], fill=LIGHT)  # right leaf
    d.rectangle([10, 26, 21, 28], fill=INK)  # soil line
    return img


def no_till() -> Image.Image:
    """A hoe over furrowed ground — harvesting leaves the plot tilled."""
    img, d = new_cell()
    d.line([9, 8, 20, 17], fill=INK, width=3)  # handle
    d.rectangle([18, 15, 25, 19], fill=MID)  # blade
    for y in (23, 27):
        d.rectangle([5, y, 26, y + 1], fill=LIGHT)  # furrows
    return img


def market_savvy() -> Image.Image:
    """A coin with an upward arrow — crops sell for more."""
    img, d = new_cell()
    d.ellipse([6, 12, 22, 28], fill=MID, outline=INK, width=2)
    d.rectangle([13, 18, 15, 24], fill=INK)
    d.line([21, 14, 27, 6], fill=INK, width=3)  # arrow shaft
    d.polygon([(24, 4), (29, 4), (29, 9)], fill=INK)  # arrow head
    return img


# --- Fishing ---------------------------------------------------------


def quick_hands() -> Image.Image:
    """A hook with speed lines."""
    img, d = new_cell()
    d.rectangle([18, 5, 20, 16], fill=INK)  # shank
    d.arc([12, 13, 26, 26], start=0, end=180, fill=INK, width=3)  # bend
    d.rectangle([12, 18, 14, 21], fill=INK)  # barb
    for i, y in enumerate((9, 13, 17)):
        d.rectangle([4 + i, y, 13, y + 1], fill=LIGHT)  # motion lines
    return img


def treasure_hunter() -> Image.Image:
    """A chest — better odds on treasure pulls."""
    img, d = new_cell()
    d.rectangle([5, 14, 26, 26], fill=MID, outline=INK, width=2)
    d.arc([5, 8, 26, 20], start=180, end=360, fill=INK, width=2)
    d.rectangle([5, 18, 26, 19], fill=INK)  # lid seam
    d.rectangle([14, 17, 17, 22], fill=LIGHT)  # clasp
    return img


def steady_hands() -> Image.Image:
    """A level bubble — a wider timing window."""
    img, d = new_cell()
    d.rounded_rectangle([4, 12, 27, 21], radius=4, fill=MID, outline=INK, width=2)
    d.ellipse([13, 14, 19, 20], fill=LIGHT, outline=INK, width=1)
    d.rectangle([11, 12, 12, 21], fill=INK)
    d.rectangle([20, 12, 21, 21], fill=INK)
    return img


# --- Cooking ---------------------------------------------------------


def efficient_cook() -> Image.Image:
    """A pot with a flame beneath."""
    img, d = new_cell()
    d.rectangle([6, 12, 25, 24], fill=MID, outline=INK, width=2)
    d.rectangle([4, 10, 27, 13], fill=INK)  # rim
    d.polygon([(13, 30), (16, 25), (19, 30)], fill=LIGHT)  # flame
    return img


def show_stopper() -> Image.Image:
    """A star burst — the spectacle perk."""
    img, d = new_cell()
    d.polygon([(16, 3), (19, 13), (29, 16), (19, 19), (16, 29), (13, 19), (3, 16), (13, 13)], fill=LIGHT, outline=INK)
    d.ellipse([13, 13, 19, 19], fill=INK)
    return img


def signature_dish() -> Image.Image:
    """A covered plate — the capstone."""
    img, d = new_cell()
    d.arc([4, 8, 27, 26], start=180, end=360, fill=INK, width=3)
    d.rectangle([5, 16, 26, 18], fill=MID)
    d.rectangle([3, 22, 28, 25], fill=INK)  # plate
    d.rectangle([15, 5, 17, 9], fill=LIGHT)  # handle
    return img


# Order IS the sheet order (row-major, 3 per row).
PERKS = [
    ("GreenThumb", green_thumb),
    ("NoTillNeeded", no_till),
    ("MarketSavvy", market_savvy),
    ("QuickHands", quick_hands),
    ("TreasureHunter", treasure_hunter),
    ("SteadyHands", steady_hands),
    ("EfficientCook", efficient_cook),
    ("ShowStopper", show_stopper),
    ("SignatureDish", signature_dish),
]


def main() -> None:
    rows = (len(PERKS) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), CLEAR)
    for i, (_name, draw) in enumerate(PERKS):
        sheet.paste(draw(), ((i % COLS) * CELL, (i // COLS) * CELL))
    path = os.path.join(ASSETS, "perk_icons.png")
    sheet.save(path)
    print(f"wrote assets/sprites/perk_icons.png {sheet.size} — order: {[n for n, _ in PERKS]}")


if __name__ == "__main__":
    main()
