#!/usr/bin/env bash
# Pre-commit checks for the Luau source.
#
# This project's author cannot run the game from the environment the code
# is written in -- it only executes inside Roblox Studio on his machine --
# so every mistake costs a full round trip. These are the checks that can
# run here, and they exist because each one has already caught a real bug
# that shipped:
#
#   1. Parse.   luau-compile on every file. Catches syntax errors, which
#               in Roblox surface as a module silently failing to load.
#   2. Locals.  check_undefined_locals.py. Catches calling a local that
#               was never declared -- a RUNTIME error, so the parser is
#               happy and the file loads, then blows up mid-execution.
#               A HUD edit deleted a helper this way and took the entire
#               HUD off screen, because the error aborted the builder
#               before any panel was parented.
#
# Usage:  bash tools/verify.sh
# Exits non-zero if anything fails, so it can gate a commit.

set -uo pipefail
cd "$(dirname "$0")/.."

status=0

echo "== parse =="
if command -v luau-compile >/dev/null 2>&1; then
    LUAU_COMPILE=luau-compile
elif [ -x "${LUAU_COMPILE:-}" ]; then
    : # caller supplied a path
else
    LUAU_COMPILE=""
fi

if [ -n "${LUAU_COMPILE:-}" ]; then
    parse_failed=0
    while IFS= read -r file; do
        if ! out=$("$LUAU_COMPILE" --binary "$file" 2>&1 >/dev/null) || [ -n "$out" ]; then
            echo "$out"
            parse_failed=1
        fi
    done < <(find src -name '*.lua' | sort)
    if [ "$parse_failed" -eq 0 ]; then
        echo "all files parse cleanly"
    else
        status=1
    fi
else
    # Not fatal: the parse check is a bonus, the locals check below is
    # the one that catches the bug class we actually keep hitting.
    echo "luau-compile not on PATH and LUAU_COMPILE unset - skipping parse check"
    echo "  (get it from https://github.com/luau-lang/luau/releases, or set LUAU_COMPILE=/path/to/luau-compile)"
fi

echo
echo "== undefined locals =="
python3 tools/check_undefined_locals.py || status=1

echo
if [ "$status" -eq 0 ]; then
    echo "OK"
else
    echo "FAILED"
fi
exit "$status"
