#!/usr/bin/env python3
"""Flags calls to locals that were never declared in the same file.

Why this exists
---------------
A HUD edit deleted a helper (`topbarOffset`) while removing the function
next to it, and nothing caught it. It is not a syntax error -- the file
parsed fine -- so `luau-compile` passed. It is a *runtime* error, raised
only when that line executes, which in this case was during HUD
construction: the error aborted the builder before any panel was
parented and the entire HUD vanished from the screen.

luau-analyze would catch it in principle, but without Roblox's type
definitions it reports every one of `game`, `Instance`, `Enum`, `UDim2`
and friends as an unknown global too, and the real finding is lost in
hundreds of false positives.

So this checks one specific, high-signal thing: an identifier used in
CALL position, spelled like a local (lower-case first letter), that is
never declared anywhere in the file and isn't a known global. That is
exactly the shape of the bug above, and it is cheap to run before every
commit in a project whose author cannot execute the code.

Deliberately conservative -- it only looks at call sites, and only at
lower-case names, because the cost of a false positive here is someone
learning to ignore the output.

Usage:
    python3 tools/check_undefined_locals.py          # whole src/ tree
    python3 tools/check_undefined_locals.py FILE...

Exits non-zero if anything is flagged, so it can gate a commit.
"""

from __future__ import annotations

import os
import re
import sys

# Lua/Luau standard library plus the Roblox globals available to every
# script. Services don't belong here: those arrive via game:GetService
# and so are locals the file must declare itself.
KNOWN = {
    # Lua stdlib
    "assert", "collectgarbage", "error", "getmetatable", "ipairs", "next",
    "pairs", "pcall", "print", "rawequal", "rawget", "rawlen", "rawset",
    "require", "select", "setmetatable", "tonumber", "tostring", "type",
    "unpack", "xpcall",
    # Luau / Roblox globals
    "typeof", "warn", "tick", "time", "wait", "spawn", "delay", "elapsedTime",
    "gcinfo", "newproxy", "settings", "version", "loadstring",
    # Roblox datatype constructors and namespaces
    "game", "workspace", "script", "shared", "plugin",
    "task", "os", "math", "string", "table", "coroutine", "bit32", "utf8",
    "debug", "buffer", "vector",
    # Literals. These show up in call position for a statement like
    #     active = false
    #     (screenGui :: ScreenGui).Enabled = false
    # where the regex sees `false (`. In older Lua that really was an
    # ambiguity -- the parser would continue the expression and call the
    # boolean -- but Luau's parser is newline-aware and treats the paren
    # as starting a new statement. Verified by running the pattern under
    # the Luau interpreter, not assumed. So this is a false positive to
    # suppress, NOT a bug to go fix.
    "true", "false", "nil",
}

# `local x`, `local x, y`, `local function f`, and function parameters.
LOCAL_DECL = re.compile(r"\blocal\s+(?:function\s+)?([A-Za-z_][\w]*(?:\s*,\s*[A-Za-z_][\w]*)*)")
FUNC_PARAMS = re.compile(r"\bfunction\s*(?:[\w.:]*)\s*\(([^)]*)\)")
# for i = ..., for k, v in ...
FOR_VARS = re.compile(r"\bfor\s+([A-Za-z_][\w]*(?:\s*,\s*[A-Za-z_][\w]*)*)\s*(?:=|\bin\b)")
# A call: an identifier not preceded by . or : (which would make it a
# field/method, resolved at runtime and none of our business).
CALL_SITE = re.compile(r"(?<![\w.:])([a-z_][\w]*)\s*\(")


def strip_noise(source: str) -> str:
    """Remove comments and string literals so their contents can't be
    mistaken for code. Long brackets first, since they can contain
    anything including quotes and newlines."""
    source = re.sub(r"--\[(=*)\[.*?\]\1\]", " ", source, flags=re.S)  # long comment
    source = re.sub(r"\[(=*)\[.*?\]\1\]", " ", source, flags=re.S)  # long string
    source = re.sub(r"--[^\n]*", " ", source)  # line comment
    source = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', source)
    source = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", source)
    source = re.sub(r"`(?:\\.|[^`\\])*`", "``", source, flags=re.S)  # interpolated string
    return source


def declared_names(code: str) -> set[str]:
    names: set[str] = set()
    for pattern in (LOCAL_DECL, FOR_VARS):
        for match in pattern.finditer(code):
            for name in match.group(1).split(","):
                names.add(name.strip())
    for match in FUNC_PARAMS.finditer(code):
        for param in match.group(1).split(","):
            # Strip Luau type annotations and defaults: `dt: number`
            param = param.split(":")[0].strip().lstrip("...")
            if param:
                names.add(param)
    # `function Module.name(...)` / `function Module:name(...)` define
    # fields, and code calls them qualified, so they need no entry here.
    return names


def check(path: str) -> list[str]:
    with open(path, "r", encoding="utf-8") as handle:
        code = strip_noise(handle.read())
    declared = declared_names(code) | KNOWN
    problems = []
    seen: set[str] = set()
    for match in CALL_SITE.finditer(code):
        name = match.group(1)
        if name in declared or name in seen:
            continue
        # Luau keywords that can be followed by a paren.
        if name in {"if", "while", "return", "and", "or", "not", "then", "do", "end", "elseif", "until", "for", "in", "local", "function", "repeat", "else"}:
            continue
        seen.add(name)
        line = code[: match.start()].count("\n") + 1
        problems.append(f"{path}:{line}: calls '{name}', which is never declared in this file")
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
        print(f"\n{len(problems)} undefined local call(s) across {len(targets)} file(s)")
        return 1
    print(f"no undefined local calls across {len(targets)} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
