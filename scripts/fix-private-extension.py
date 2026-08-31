#!/usr/bin/env python3
"""Три и больше private-функции подряд в конце типа уезжают в private extension."""

from __future__ import annotations

import re
import sys
from pathlib import Path

RUN = 3

TYPE = re.compile(
    r"^(?:[\w@\(\)]+\s+)*(struct|class|enum|actor)\s+(\w+)[^{]*\{\s*$"
)

PRIVATE_FUNC = re.compile(r"^    (?:@\w+.*\n)?\s*private\s+(?:static\s+|final\s+)*func\s+\w")

ATTRIBUTE = re.compile(r"^\s{4}@\w+")

MEMBER = re.compile(r"^\s{4}\S")


def blocks(lines: list[str]) -> list[tuple[int, int]]:
    """Границы объявлений внутри тела типа: (начало, конец).

    Объявление кончается там, где закрывается его тело; пока фигурная скобка
    не встретилась, продолжается сигнатура — она может переноситься.
    """
    found: list[tuple[int, int]] = []
    index = 0

    while index < len(lines):
        if not MEMBER.match(lines[index]):
            index += 1
            continue

        start = index
        level = 0
        opened = False

        while index < len(lines):
            level += lines[index].count("{") - lines[index].count("}")
            opened = opened or "{" in lines[index]
            index += 1

            if opened and level <= 0:
                break

            if not opened and MEMBER.match(lines[index - 1]) and lines[index - 1].rstrip().endswith(
                ("?", "!", ")", "]", "String", "Int", "Bool", "Void", "Double", "CGFloat")
            ) and index < len(lines) and (not lines[index].strip() or MEMBER.match(lines[index])):
                break

        found.append((start, index))

    return found



def has_private_type(text: str) -> bool:
    """Вынести нельзя: private-тип внутри виден только телу типа."""
    return bool(re.search(r"^\s+private\s+(?:struct|enum|class|actor)\s+\w", text, re.MULTILINE))


def extracted(text: str) -> str | None:
    if has_private_type(text):
        return None

    lines = text.splitlines()
    opening = next((i for i, line in enumerate(lines) if TYPE.match(line)), None)
    if opening is None:
        return None

    name = TYPE.match(lines[opening]).group(2)
    closing = next((i for i in range(len(lines) - 1, opening, -1) if lines[i] == "}"), None)
    if closing is None:
        return None

    body = lines[opening + 1:closing]
    members = blocks(body)
    private = [
        (start, end) for start, end in members
        if re.search(r"private\s+(?:static\s+|final\s+)*func\s", "\n".join(body[start:end][:2]))
    ]

    if len(private) < RUN:
        return None

    moved: list[str] = []
    for start, end in private:
        for line in body[start:end]:
            moved.append(re.sub(r"^(\s*)private\s+", r"\1", line, count=1))
        moved.append("")

    keep = set()
    for start, end in private:
        keep.update(range(start, end))

    kept = [line for index, line in enumerate(body) if index not in keep]
    while kept and not kept[-1].strip():
        kept.pop()

    while moved and not moved[-1].strip():
        moved.pop()

    return "\n".join(
        lines[:opening + 1] + kept + ["}", "", f"private extension {name} {{", ""]
        + moved + ["}"] + lines[closing + 1:]
    ) + "\n"


def main() -> int:
    for name in sys.argv[1:]:
        path = Path(name)
        text = path.read_text(encoding="utf-8")
        updated = extracted(text)

        if updated and updated != text:
            path.write_text(updated, encoding="utf-8")
            print(f"fixed {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
