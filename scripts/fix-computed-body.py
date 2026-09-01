#!/usr/bin/env python3
"""Тело вычисляемого свойства пишется с новой строки, а не в одну строку со скобками."""

from __future__ import annotations

import re
import sys
from pathlib import Path

SINGLE_LINE = re.compile(
    r"^(?P<indent>\s*)(?P<head>(?:[\w@\(\):]+\s+)*var\s+\w+\s*:\s*[^={]+?)\s*"
    r"\{\s*(?P<body>[^{}]+?)\s*\}\s*$"
)

KEYWORDS = {"get", "get set", "set", "get async", "get throws", "get async throws"}


def expanded(text: str) -> str:
    lines = text.splitlines()
    result: list[str] = []

    for line in lines:
        match = SINGLE_LINE.match(line)
        body = match.group("body").strip() if match else ""

        if not match or body in KEYWORDS or "//" in line:
            result.append(line)
            continue

        indent = match.group("indent")
        result.append(f"{indent}{match.group('head').rstrip()} {{")
        result.append(f"{indent}    {body}")
        result.append(f"{indent}}}")

    return "\n".join(result) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    names = [name for name in sys.argv[1:] if name != "--check"]
    pending: list[Path] = []

    for name in names:
        path = Path(name)
        text = path.read_text(encoding="utf-8")
        updated = expanded(text)

        if updated == text:
            continue

        if check:
            pending.append(path)
            continue

        path.write_text(updated, encoding="utf-8")
        print(f"fixed {path}")

    for path in pending:
        print(
            f"{path}:1:1: error: тело вычисляемого свойства пишется с новой строки (make format)",
            file=sys.stderr
        )

    return 1 if pending else 0


if __name__ == "__main__":
    raise SystemExit(main())
