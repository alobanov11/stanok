#!/usr/bin/env python3
"""Простые хранимые свойства идут подряд; пустая строка — только у украшенных."""

from __future__ import annotations

import re
import sys
from pathlib import Path

TYPE = re.compile(r"^\s*(?:[\w@\(\)]+\s+)*(?:struct|class|enum|actor|extension|protocol)\s+\w")

PROPERTY = re.compile(
    r"^\s*(?:(?:open|public|package|internal|fileprivate|private)(?:\(set\))?\s+)?"
    r"(?:(?:static|class|final|lazy|weak|unowned|nonisolated|override)\s+)*"
    r"(?:let|var)\s+\w+"
)

COMMENT = re.compile(r"^\s*(//|/\*|\*)")

ATTRIBUTE = re.compile(r"^\s*@\w+")


class Unit:

    def __init__(self, lines: list[str], simple: bool):
        self.lines = lines
        self.simple = simple


def balance(line: str) -> int:
    """Открытые скобки строки: пока их больше нуля, объявление не закончилось."""
    text = re.sub(r'"[^"]*"', "", line.split("//")[0])
    opened = text.count("{") + text.count("(") + text.count("[")
    closed = text.count("}") + text.count(")") + text.count("]")

    return opened - closed


def is_simple(lines: list[str]) -> bool:
    if len(lines) != 1:
        return False

    line = lines[0]
    body = line.split("//")[0].strip()

    return bool(PROPERTY.match(line)) and not body.endswith("{") and "//" not in line


def units(lines: list[str], start: int, depth: int) -> tuple[list[Unit], list[str], int]:
    """Разбирает тело типа на объявления, пока не закончится его область."""
    parsed: list[Unit] = []
    index = start

    while index < len(lines):
        while index < len(lines) and not lines[index].strip():
            index += 1

        if index >= len(lines) or balance(lines[index]) < 0:
            break

        collected = [lines[index]]
        level = balance(lines[index])
        index += 1

        while index < len(lines) and (level > 0 or ATTRIBUTE.match(collected[-1])
                                      or COMMENT.match(collected[-1])):
            collected.append(lines[index])
            level += balance(lines[index])
            index += 1

        parsed.append(Unit(collected, is_simple(collected)))

    return parsed, [], index


def rewrite(text: str) -> str:
    lines = text.splitlines()
    result: list[str] = []
    index = 0

    while index < len(lines):
        line = lines[index]
        result.append(line)
        index += 1

        if not (TYPE.match(line) and line.rstrip().endswith("{")):
            continue

        members, _, end = units(lines, index, 0)
        if not members:
            continue

        block: list[str] = []
        for position, unit in enumerate(members):
            if position:
                previous = members[position - 1]
                if not (previous.simple and unit.simple):
                    block.append("")
            block += unit.lines

        result.append("")
        result += block
        index = end

    return "\n".join(result) + "\n"


def main() -> int:
    for name in sys.argv[1:]:
        path = Path(name)
        text = path.read_text(encoding="utf-8")
        updated = rewrite(text)

        if updated == text:
            continue

        if [line for line in text.splitlines() if line.strip()] != \
           [line for line in updated.splitlines() if line.strip()]:
            print(f"error: {path} — правка меняет не только пустые строки", file=sys.stderr)
            return 1

        path.write_text(updated, encoding="utf-8")
        print(f"fixed {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
