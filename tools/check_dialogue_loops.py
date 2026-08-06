#!/usr/bin/env python3
"""Flags dialogue branches that can return to a node already visited.

Why this exists
---------------
Kaya's farm offer let you pick "What's the catch?", read the answer, and
land back on the same offer -- with "What's the catch?" still on it. You
could ask forever. Nothing was broken in code terms; the tree just had a
cycle, and a cycle in a conversation reads as the character forgetting
they already answered.

That is invisible to every other check in this repo and easy to
reintroduce whenever a node gains a "Continue" that points backwards, so
it gets its own check: walk each tree from its root and report any edge
that reaches a node already on the current path.

Not every cycle is a bug -- a hub node you can return to on purpose is a
normal shape -- so this reports rather than forbids, and known-good
cycles can be listed in ALLOWED below.

Usage:
    python3 tools/check_dialogue_loops.py

Exits non-zero if an unlisted cycle is found.
"""

from __future__ import annotations

import re
import sys

SOURCE = "src/ReplicatedStorage/Modules/Shared/DialogueData.lua"

# Cycles that are intentional, as "tree:from->to".
ALLOWED: set[str] = set()


def parse() -> dict[str, dict[str, list[str]]]:
    """Returns {treeName: {nodeId: [targetNodeId, ...]}}."""
    with open(SOURCE, "r", encoding="utf-8") as handle:
        source = handle.read()

    trees: dict[str, dict[str, list[str]]] = {}
    # DialogueData.Kaya = { ... } through to the next top-level assignment.
    for tree_match in re.finditer(r"DialogueData\.(\w+)\s*=\s*\{", source):
        name = tree_match.group(1)
        if name in ("Roots",):
            continue
        start = tree_match.end()
        depth = 1
        i = start
        while i < len(source) and depth > 0:
            if source[i] == "{":
                depth += 1
            elif source[i] == "}":
                depth -= 1
            i += 1
        body = source[start : i - 1]

        nodes: dict[str, list[str]] = {}
        # Each node is `id = {` at one indent level inside the tree.
        for node_match in re.finditer(r"\n\t(\w+)\s*=\s*\{", body):
            node_id = node_match.group(1)
            node_start = node_match.end()
            d = 1
            j = node_start
            while j < len(body) and d > 0:
                if body[j] == "{":
                    d += 1
                elif body[j] == "}":
                    d -= 1
                j += 1
            node_body = body[node_start : j - 1]
            targets = re.findall(r'next\s*=\s*"(\w+)"', node_body)
            targets += re.findall(r'ifTrue\s*=\s*"(\w+)"', node_body)
            targets += re.findall(r'ifFalse\s*=\s*"(\w+)"', node_body)
            nodes[node_id] = targets
        trees[name] = nodes
    return trees


def roots(source_trees: dict[str, dict[str, list[str]]]) -> dict[str, str]:
    with open(SOURCE, "r", encoding="utf-8") as handle:
        source = handle.read()
    found: dict[str, str] = {}
    block = re.search(r"DialogueData\.Roots\s*=\s*\{(.*?)\n\}", source, re.S)
    if block:
        for name, root in re.findall(r"(\w+)\s*=\s*\"(\w+)\"", block.group(1)):
            found[name] = root
    return found


def main() -> int:
    trees = parse()
    tree_roots = roots(trees)
    problems = []

    for name, nodes in trees.items():
        root = tree_roots.get(name)
        if not root or root not in nodes:
            continue

        def walk(node_id: str, path: list[str]):
            for target in nodes.get(node_id, []):
                key = f"{name}:{node_id}->{target}"
                if target in path:
                    if key not in ALLOWED:
                        problems.append(
                            f"{name}: '{node_id}' -> '{target}' returns to a node already on this path "
                            f"({' -> '.join(path + [target])})"
                        )
                    continue
                if target in nodes:
                    walk(target, path + [target])

        walk(root, [root])

    if problems:
        for problem in problems:
            print(problem)
        print(f"\n{len(problems)} dialogue cycle(s) found")
        return 1
    print(f"no dialogue cycles across {len(trees)} tree(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
