#!/usr/bin/env python3
"""Flags UIStroke instances parented to a text object without an explicit
ApplyStrokeMode.

Why this exists
---------------
UIStroke.ApplyStrokeMode defaults to Contextual, which means:

    parented to a Frame/ImageLabel  -> outlines the BORDER
    parented to a TextLabel,
      TextButton or TextBox         -> outlines the GLYPHS

That second case is almost never what a panel-styling helper wants. The
dialogue box's option buttons went through a helper that adds a 2px dark
UIStroke -- correct for the panels it was written for, but on a
TextButton it drew a 2px outline around every letter of 11px pixel text
and smeared them into unreadable blobs. Every plain TextLabel on screen
stayed crisp, which made it look like a font problem rather than a stroke
problem, and it survived two rounds of "the text is unreadable".

So: any UIStroke whose parent is a text object should say what it means.
Setting ApplyStrokeMode = Border is a no-op on Frames, so helpers shared
between panels and buttons can just always set it.

Usage:
    python3 tools/check_text_strokes.py            # whole src/ tree
    python3 tools/check_text_strokes.py FILE...

Exits non-zero if anything is flagged.
"""

from __future__ import annotations

import os
import re
import sys

STROKE_DECL = re.compile(r"local\s+(\w+)\s*=\s*Instance\.new\(\s*[\"']UIStroke[\"']\s*\)")
TEXT_CLASSES = ("TextLabel", "TextButton", "TextBox")


def check(path: str) -> list[str]:
    with open(path, "r", encoding="utf-8") as handle:
        lines = handle.readlines()
    source = "".join(lines)

    # Map variable name -> the class it was constructed as, so a
    # `stroke.Parent = someLabel` can be resolved.
    declared_class: dict[str, str] = {}
    for match in re.finditer(r"local\s+(\w+)\s*=\s*Instance\.new\(\s*[\"'](\w+)[\"']\s*\)", source):
        declared_class[match.group(1)] = match.group(2)
    # Also pick up annotated locals: `local plaqueLabel: TextLabel`
    for match in re.finditer(r"local\s+(\w+)\s*:\s*(\w+)", source):
        declared_class.setdefault(match.group(1), match.group(2))

    problems = []
    for match in STROKE_DECL.finditer(source):
        name = match.group(1)
        # Everything written about this stroke, up to the next blank line
        # after its Parent assignment.
        region = source[match.start():]
        parent_match = re.search(rf"{re.escape(name)}\.Parent\s*=\s*([\w.]+)", region)
        if not parent_match:
            continue
        region = region[: parent_match.end()]
        if "ApplyStrokeMode" in region:
            continue  # explicit, whatever it says

        parent = parent_match.group(1).split(".")[0]
        parent_class = declared_class.get(parent)
        line = source[: match.start()].count("\n") + 1

        if parent_class in TEXT_CLASSES:
            problems.append(
                f"{path}:{line}: UIStroke '{name}' is parented to {parent} ({parent_class}) "
                f"without ApplyStrokeMode - it will outline the TEXT, not the border"
            )
        elif parent_class is None:
            # The parent's class can't be resolved here, which in practice
            # means it's a function parameter -- i.e. this is a shared
            # styling helper, and helpers are precisely what get reused on
            # a TextButton later by someone who has no idea a UIStroke
            # behaves differently there. That is exactly how the dialogue
            # buttons broke. Setting ApplyStrokeMode = Border costs
            # nothing on a Frame, so these should always be explicit.
            problems.append(
                f"{path}:{line}: UIStroke '{name}' is parented to '{parent}', whose class isn't "
                f"knowable here (a styling helper?) - set ApplyStrokeMode explicitly so it can't "
                f"silently outline text when reused on a button"
            )
    return problems


def main() -> int:
    targets = sys.argv[1:]
    if not targets:
        targets = []
        for root, _dirs, files in os.walk("src"):
            for name in sorted(files):
                if name.endswith(".lua"):
                    targets.append(os.path.join(root, name))

    problems = []
    for path in targets:
        problems.extend(check(path))

    if problems:
        for problem in problems:
            print(problem)
        print(f"\n{len(problems)} text-stroke issue(s) across {len(targets)} file(s)")
        return 1
    print(f"no ambiguous text strokes across {len(targets)} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
