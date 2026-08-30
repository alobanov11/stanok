#!/usr/bin/env python3
"""Inserts the blank line after a type's opening brace that swiftformat cannot add."""
import re
import sys

DECL = re.compile(r"\b(?:struct|class|enum|protocol|extension|actor)\b[^\n]*\{\s*$")


def fix(path: str) -> bool:
    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()

    out: list[str] = []
    changed = False
    for index, line in enumerate(lines):
        out.append(line)
        if not DECL.search(line):
            continue
        nxt = lines[index + 1] if index + 1 < len(lines) else ""
        if nxt.strip() and not nxt.lstrip().startswith("}"):
            out.append("\n")
            changed = True

    if changed:
        with open(path, "w", encoding="utf-8") as handle:
            handle.writelines(out)
    return changed


if __name__ == "__main__":
    touched = [p for p in sys.argv[1:] if fix(p)]
    for path in touched:
        print(f"fixed {path}")
