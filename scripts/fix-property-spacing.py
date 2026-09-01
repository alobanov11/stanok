#!/usr/bin/env python3
"""Простые хранимые свойства идут подряд; пустая строка — только у украшенных."""

from __future__ import annotations

import re
import sys
from pathlib import Path

TYPE = re.compile(r"^\s*(?:[\w@\(\)]+\s+)*(?:struct|class|enum|actor|extension|protocol)\s+\w")

ACCESS = {"open", "public", "package", "internal", "fileprivate", "private"}

PROPERTY = re.compile(
    r"^\s*(?:(?:open|public|package|internal|fileprivate|private)(?:\(set\))?\s+)?"
    r"(?:(?:static|class|final|lazy|weak|unowned|nonisolated|override)\s+)*"
    r"(?:let|var)\s+\w+"
)

CASE = re.compile(r"^\s*(?:indirect\s+)?case\s+\w")

COMMENT = re.compile(r"^\s*(//|/\*|\*)")

ATTRIBUTE = re.compile(r"^\s*@\w+")


class Unit:

    def __init__(self, lines: list[str], group: tuple[str, ...] | None):
        self.lines = lines
        self.group = group

    @property
    def simple(self) -> bool:
        return self.group is not None


def balance(line: str) -> int:
    """Открытые скобки строки: пока их больше нуля, объявление не закончилось."""
    text = re.sub(r'"[^"]*"', "", line.split("//")[0])
    opened = text.count("{") + text.count("(") + text.count("[")
    closed = text.count("}") + text.count(")") + text.count("]")

    return opened - closed


def group_of(lines: list[str]) -> tuple[str, ...] | None:
    """Ключ группы: подряд пишутся только объявления одного вида и доступа."""
    if len(lines) != 1:
        return None

    line = lines[0]
    body = line.split("//")[0].strip()
    if "{" in body or "}" in body or "//" in line:
        return None

    if CASE.match(line):
        return ("case",)

    match = PROPERTY.match(line)
    if not match:
        return None

    words = body.split()
    access = next((w for w in words if w.split("(")[0] in ACCESS), "internal")
    scope = "static" if "static" in words or "class" in words else "instance"
    kind = "var" if " var " in f" {body} " or body.startswith("var ") else "let"

    return (access, scope, kind)


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

        parsed.append(Unit(collected, group_of(collected)))

    return parsed, [], index


def opens_type(line: str) -> bool:
    return bool(TYPE.match(line)) and line.rstrip().endswith("{")


def packed(lines: list[str]) -> list[str]:
    """Пакует объявления в каждом теле типа, включая вложенные."""
    result: list[str] = []
    index = 0

    while index < len(lines):
        line = lines[index]
        result.append(line)
        index += 1

        if not opens_type(line):
            continue

        members, _, end = units(lines, index, 0)
        if not members:
            continue

        block: list[str] = []
        for position, unit in enumerate(members):
            if position:
                previous = members[position - 1]
                if previous.group is None or previous.group != unit.group:
                    block.append("")

            block += packed(unit.lines) if opens_type(unit.lines[0]) else unit.lines

        result.append("")
        result += block
        index = end

    return result


def rewrite(text: str) -> str:
    return "\n".join(packed(text.splitlines())) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    names = [name for name in sys.argv[1:] if name != "--check"]
    unformatted: list[Path] = []

    for name in names:
        path = Path(name)
        text = path.read_text(encoding="utf-8")
        updated = rewrite(text)

        if updated == text:
            continue

        if [line for line in text.splitlines() if line.strip()] != \
           [line for line in updated.splitlines() if line.strip()]:
            print(f"error: {path} — правка меняет не только пустые строки", file=sys.stderr)
            return 1

        if check:
            unformatted.append(path)
            continue

        path.write_text(updated, encoding="utf-8")
        print(f"fixed {path}")

    for path in unformatted:
        print(
            f"{path}:1:1: error: простые хранимые свойства пишутся подряд, пустая строка — "
            f"только вокруг свойств с обёрткой или комментарием (make format)",
            file=sys.stderr
        )

    return 1 if unformatted else 0


if __name__ == "__main__":
    raise SystemExit(main())
