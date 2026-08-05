#!/usr/bin/env python3
"""Draw a real side-profile row into the player sheets.

Why this exists
---------------
assets/sprites/player_idle.png and player_walk.png came from an asset
pack laid out as three rows, and the code assumed the standard
down / up / side order. The row ORDER is right -- row 0 faces the
camera, row 1 faces away -- but row 2 is NOT a side view. It is a
second front-facing pose: both eyes visible, face square to the camera.

Measured on the walk sheet (mean abs difference, 0-255 per channel):

    row 0 vs its own mirror   9.0
    row 1 vs its own mirror   7.4
    row 2 vs its own mirror  11.2      <- a true profile scores 30+
    row 2 vs row 0            7.0      <- barely different from front

So the sheet had no left-facing or right-facing art at all. That is the
whole reason walking sideways looked like moonwalking, and why flipping
CharacterSpriteController's mirror binding never helped -- both
directions were drawing the same forward-facing sprite either way. The
pre-mirrored sheets were mirroring a symmetric pose.

This script draws an actual profile (facing RIGHT) over row 2 of both
sheets, in the pack's own palette and proportions sampled from row 0, so
it sits next to the original art without looking pasted in. Run
make_mirrored_player_sheets.py afterwards to regenerate the left-facing
copies from the new row.

Usage:
    python3 tools/make_player_side_rows.py
    python3 tools/make_mirrored_player_sheets.py
"""

from __future__ import annotations

import math
import os

from PIL import Image

CELL = 32
ROW_SIDE = 2
IDLE_COLUMNS = 4
WALK_COLUMNS = 6

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")

# Sampled from the pack's own frames, so the profile matches the front
# and back rows exactly rather than approximating them.
OUTLINE = (28, 10, 24, 255)
HAIR_DARK = (14, 14, 14, 255)
HAIR_MID = (29, 29, 29, 255)
HAIR_LIGHT = (47, 47, 47, 255)
HAIR_SHEEN = (78, 78, 78, 255)
HAIR_HILITE = (123, 123, 123, 255)
SKIN = (255, 198, 139, 255)
EYE = (0, 0, 0, 255)
EYE_WHITE = (138, 157, 184, 255)
SHIRT = (46, 175, 199, 255)
OVERALLS = (26, 52, 115, 255)
SHOE = (239, 123, 85, 255)
CLEAR = (0, 0, 0, 0)

# Vertical layout copied from row 0: hair starts at y=7, chin at y=16,
# shoulders at y=18, feet at y=25. Keeping these identical is what stops
# the character bobbing when the direction changes.
HEAD_TOP = 7
CHIN = 16
SHOULDER = 18
HIP = 22
FOOT = 25


class Cell:
    """A 32x32 pixel buffer with painting order that respects outlines."""

    def __init__(self) -> None:
        self.px: dict[tuple[int, int], tuple[int, int, int, int]] = {}

    def set(self, x: int, y: int, color: tuple[int, int, int, int]) -> None:
        if 0 <= x < CELL and 0 <= y < CELL:
            self.px[(x, y)] = color

    def rect(self, x0: int, y0: int, x1: int, y1: int, color) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, color)

    def outline(self) -> None:
        """Wrap every filled pixel's empty 4-neighbours in the pack's
        outline color -- the same chunky single-pixel keyline the front
        and back rows use."""
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


def draw_side(bob: int, front_leg: int, back_leg: int, arm: int) -> Image.Image:
    """One right-facing frame.

    bob        vertical body offset in px (walk bounce)
    front_leg  how far the leading leg reaches forward, px
    back_leg   how far the trailing leg reaches back, px
    arm        forward swing of the visible (near) arm, px
    """
    c = Cell()

    # --- head -------------------------------------------------------
    # Profile: the hair bulk fills the back of the skull and the crown,
    # skin shows only along the leading edge as brow, nose and chin.
    # That silhouette is what row 2 was missing entirely -- the pack's
    # original row 2 drew a full front-facing face.
    hy = HEAD_TOP + bob
    # Back-weighted hair mass. Shading follows row 0's scheme: darkest at
    # the keyline edges, mid tone as the fill, two lighter tones for the
    # crown sheen -- an evenly dark blob reads as a helmet next to the
    # pack's other rows.
    hair_rows = [
        (11, 17),
        (10, 19),
        (9, 20),
        (9, 20),
        (9, 20),
        (9, 19),
        (9, 16),
        (9, 14),
        (10, 13),
    ]
    for i, (x0, x1) in enumerate(hair_rows):
        y = hy + i
        c.rect(x0, y, x1, y, HAIR_LIGHT)
        c.set(x0, y, HAIR_DARK)
        c.set(x1, y, HAIR_MID)
    # Crown sheen, offset toward the back of the head the way the front
    # row lights its hair from above. Two tones, not one: the pack's
    # hair carries a 123-grey highlight, and without it the profile's
    # larger unbroken hair mass flattens into a solid black helmet next
    # to the other rows.
    c.rect(12, hy + 1, 15, hy + 1, HAIR_SHEEN)
    c.rect(13, hy + 1, 14, hy + 1, HAIR_HILITE)
    c.rect(11, hy + 2, 14, hy + 2, HAIR_SHEEN)
    c.set(12, hy + 2, HAIR_HILITE)
    c.rect(11, hy + 3, 12, hy + 3, HAIR_SHEEN)
    # The pack's side tuft, which in profile reads as hair kicking out
    # behind the head.
    c.set(8, hy + 3, HAIR_MID)
    c.set(8, hy + 4, HAIR_DARK)

    # Face: a wedge on the leading (right) edge, tapering to the chin.
    c.rect(17, hy + 5, 21, hy + 5, SKIN)  # brow
    c.rect(17, hy + 6, 21, hy + 6, SKIN)  # eye line, nose tip at 21
    c.rect(15, hy + 7, 20, hy + 7, SKIN)
    c.rect(14, hy + 8, 19, hy + 8, SKIN)
    c.rect(15, hy + 9, 18, hy + 9, SKIN)  # chin tucks back under

    # A single eye set behind the nose -- the single strongest cue that
    # this is a profile and not another front view.
    c.set(18, hy + 6, EYE)
    c.set(19, hy + 6, EYE_WHITE)
    c.set(18, hy + 7, EYE)

    # Fringe overhangs the brow, drawn last so it sits over the skin.
    c.rect(14, hy + 4, 19, hy + 4, HAIR_LIGHT)
    c.set(19, hy + 4, HAIR_MID)
    c.set(17, hy + 5, HAIR_MID)

    # Neck, so the head doesn't read as floating over the shoulders.
    c.rect(15, hy + 10, 17, hy + 10, SKIN)

    # --- body -------------------------------------------------------
    sy = SHOULDER + bob
    # Front torso is 7px across, so side-on it reads at 6.
    c.rect(14, sy, 19, sy, SHIRT)
    c.rect(14, sy + 1, 19, sy + 1, SHIRT)
    c.rect(14, sy + 2, 19, sy + 2, OVERALLS)
    c.rect(14, sy + 3, 19, sy + 3, OVERALLS)

    # Near arm, swinging. Drawn after the torso so it reads as being in
    # front of the body -- the only depth cue a side view gets.
    ax = 16 + arm
    c.rect(ax, sy + 1, ax + 1, sy + 1, SHIRT)
    c.rect(ax, sy + 2, ax + 1, sy + 2, SKIN)

    # --- legs -------------------------------------------------------
    ly = HIP + bob
    # Leading leg reaches forward, trailing leg pushes back. Their base
    # positions are 2px apart before any reach is applied, so the two
    # legs stay visually distinct even on the passing pose where both
    # reaches are zero -- the first pass placed both at the same x and
    # they collapsed into a single leg on two frames of the cycle.
    for base_x, reach, foot_dir in ((17, front_leg, 1), (14, -back_leg, -1)):
        lx = base_x + reach
        c.rect(lx, ly, lx + 1, ly + 1, OVERALLS)
        c.rect(lx, ly + 2, lx + 1, ly + 2, SKIN)
        # Foot points the way the character faces, and extends an extra
        # pixel so the stride reads at this size.
        toe = lx + (2 if foot_dir > 0 else -1)
        c.rect(min(lx, toe), FOOT + bob, max(lx + 1, toe), FOOT + bob, SHOE)

    c.outline()
    return c.to_image()


def walk_frames() -> list[Image.Image]:
    """Six-frame cycle: contact, passing, up, contact (mirrored gait),
    passing, up -- the standard pixel-art walk, with the bounce peaking
    on the passing poses."""
    poses = [
        # bob, front_leg, back_leg, arm
        (0, 2, 2, 2),
        (-1, 1, 1, 1),
        (-1, 0, 0, 0),
        (0, 2, 2, -1),
        (-1, 1, 1, 0),
        (-1, 0, 0, 1),
    ]
    return [draw_side(*p) for p in poses]


def idle_frames() -> list[Image.Image]:
    """Four-frame idle: a slow breath, feet planted. The bob is half the
    walk's so standing still never looks like marching in place."""
    poses = [
        (0, 1, 1, 0),
        (0, 1, 1, 0),
        (-1, 1, 1, 0),
        (0, 1, 1, 0),
    ]
    return [draw_side(*p) for p in poses]


def patch(path: str, frames: list[Image.Image], columns: int) -> None:
    sheet = Image.open(path).convert("RGBA")
    expected = (columns * CELL, 3 * CELL)
    if sheet.size != expected:
        raise SystemExit(f"{path}: expected {expected}, got {sheet.size}")
    for col in range(columns):
        box = (col * CELL, ROW_SIDE * CELL, (col + 1) * CELL, (ROW_SIDE + 1) * CELL)
        # Clear first: paste alone would leave the old front-facing pose
        # showing through wherever the new profile is transparent.
        sheet.paste(Image.new("RGBA", (CELL, CELL), CLEAR), box)
        sheet.paste(frames[col % len(frames)], box)
    sheet.save(path)
    print(f"patched row {ROW_SIDE} of {os.path.basename(path)} ({columns} frames)")


def main() -> None:
    patch(os.path.join(ASSETS, "player_walk.png"), walk_frames(), WALK_COLUMNS)
    patch(os.path.join(ASSETS, "player_idle.png"), idle_frames(), IDLE_COLUMNS)
    print("now run: python3 tools/make_mirrored_player_sheets.py")


if __name__ == "__main__":
    main()
