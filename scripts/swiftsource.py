#!/usr/bin/env python3
"""Общий разбор Swift-исходников для чекеров: очистка текста и мелкие утилиты."""

from __future__ import annotations

import re

LITERAL = re.compile(r'"""|"(?:[^"\\\n]|\\.)*"|//[^\n]*|/\*.*?\*/', re.S)

TYPE = re.compile(
    r"^\s*(?:(?:public|internal|private|fileprivate|package|open|final|indirect)\s+)*"
    r"(?P<keyword>struct|class|enum|actor|extension|protocol)\s+(?P<name>[\w`]+)"
)


def strip(source: str) -> str:
    """Убирает строковые литералы и комментарии, сохраняя разбиение на строки."""
    out: list[str] = []
    index = 0
    inside = False

    for match in LITERAL.finditer(source):
        if match.group(0) == '"""':
            if not inside:
                out.append(source[index:match.start()])
                index = match.start()
            else:
                index = match.end()
            inside = not inside
            continue

        if inside:
            continue

        out.append(source[index:match.start()])
        out.append("\n" * match.group(0).count("\n"))
        index = match.end()

    out.append(source[index:])

    return "".join(out)


def plural(number: int, one: str, few: str, many: str) -> str:
    """Согласует существительное с числом: 1 условие, 3 условия, 7 условий."""
    tail, hundred = number % 10, number % 100

    if tail == 1 and hundred != 11:
        return f"{number} {one}"

    if 2 <= tail <= 4 and not 12 <= hundred <= 14:
        return f"{number} {few}"

    return f"{number} {many}"
