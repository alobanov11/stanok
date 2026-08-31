#!/usr/bin/env python3
"""Внутри одной группы хранимых свойств поднимает var над let."""

from __future__ import annotations

import re
import sys
from pathlib import Path

PROPERTY = re.compile(
    r"^(\s*)(?:(open|public|package|internal|fileprivate|private)(?:\(set\))?\s+)?"
    r"(?:(static|class)\s+)?(let|var)\s+(\w+)"
)

ATTRIBUTE = re.compile(r"^\s*@\w+")


class Declaration:

    def __init__(self, lines: list[str], access: str, scope: str, kind: str):
        self.lines = lines
        self.access = access
        self.scope = scope
        self.kind = kind


def blocks(lines: list[str]) -> list[tuple[int, int, list[Declaration]]]:
    """Идущие подряд однотипные хранимые свойства с одинаковым доступом."""
    found: list[tuple[int, int, list[Declaration]]] = []
    index = 0

    while index < len(lines):
        run: list[Declaration] = []
        start = index

        while index < len(lines):
            attributes: list[str] = []
            cursor = index

            while cursor < len(lines) and ATTRIBUTE.match(lines[cursor]):
                attributes.append(lines[cursor])
                cursor += 1

            if cursor >= len(lines):
                break

            match = PROPERTY.match(lines[cursor])
            body = lines[cursor].strip()
            if not match or body.endswith("{") or attributes:
                break

            _, access, scope, kind, _ = match.groups()
            declaration = Declaration(
                lines[index:cursor + 1], access or "internal", scope or "", kind
            )

            if run and (run[0].access, run[0].scope) != (declaration.access, declaration.scope):
                break

            run.append(declaration)
            index = cursor + 1

            if index < len(lines) and not lines[index].strip():
                index += 1
                declaration.lines.append(lines[index - 1])
            else:
                break

        if len(run) > 1:
            found.append((start, index, run))
        else:
            index = max(index + 1, start + 1)

    return found


def fixed(text: str) -> str:
    lines = text.splitlines(keepends=True)
    result = list(lines)
    shift = 0

    for start, end, run in blocks(lines):
        ordered = [item for item in run if item.kind == "var"]
        ordered += [item for item in run if item.kind == "let"]
        if ordered == run:
            continue

        replacement = [line for item in ordered for line in item.lines]
        original = [line for item in run for line in item.lines]

        # хвостовой пустой строки может не быть у последнего свойства блока
        if original and not original[-1].strip() and replacement[-1].strip():
            replacement.append(original[-1])
        while replacement and not replacement[-1].strip() and len(replacement) > len(original):
            replacement.pop()

        result[start + shift:start + shift + len(original)] = replacement
        shift += len(replacement) - len(original)

    return "".join(result)



def skips(path: Path) -> bool:
    """Структура без явного init: порядок свойств — это порядок аргументов."""
    text = path.read_text(encoding="utf-8")
    if not re.search(r"^\s*(?:[\w@\(\)]+\s+)*struct\s+\w", text, re.MULTILINE):
        return False

    return not re.search(r"^\s*(?:[\w@\(\)]+\s+)*init\s*\(", text, re.MULTILINE)


def main() -> int:
    changed = 0

    for name in sys.argv[1:]:
        path = Path(name)
        if skips(path):
            continue

        text = path.read_text(encoding="utf-8")
        updated = fixed(text)

        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed += 1
            print(f"fixed {path}")

    print(f"{changed} файлов поправлено")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
