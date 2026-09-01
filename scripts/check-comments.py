#!/usr/bin/env python3
"""Комментарий в коде один: `// Почему: …` отдельной строкой перед тем, что объясняет.

Каждое такое объяснение печатается предупреждением: комментарий появляется там, где кодом
проблему закрыть не вышло, и держит на себе потенциальный баг. Список предупреждений — это
список мест, которые стоит переписать так, чтобы объяснение стало не нужно.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from sources import ROOTS

MARKER = re.compile(r"^// (Почему): \S")

DIRECTIVE = re.compile(r"^//\s*swiftlint:")

LINE_COMMENT = re.compile(r"^//")

BLOCK_COMMENT = re.compile(r"/\*")

TRAILING = re.compile(r"\S\s*//")

LIMIT = 100

MULTILINE = re.compile(r'#*"""')


def code(line: str) -> str:
    """Строка без строковых литералов: `//` внутри URL — не комментарий."""
    return re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)


def closes(line: str) -> bool:
    body = line.strip()

    return not body or body.startswith("}") or body.startswith(")")


def violations(path: Path) -> tuple[list[str], list[str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    found: list[str] = []
    notes: list[str] = []
    previous = ""
    inside = False

    for number, raw in enumerate(lines, start=1):
        if len(MULTILINE.findall(raw)) % 2 == 1:
            inside = not inside
            continue

        if inside:
            continue

        body = code(raw).strip()

        if BLOCK_COMMENT.search(body):
            found.append(f"{path}:{number}:1: error: блочный комментарий не нужен, "
                         f"объяснение пишется как `// Почему: …`")
            previous = body
            continue

        if not LINE_COMMENT.match(body):
            if TRAILING.search(body):
                found.append(f"{path}:{number}:1: error: комментарий в хвосте строки — "
                             f"объяснение выносится отдельной строкой `// Почему: …`")
            previous = body
            continue

        if DIRECTIVE.match(body):
            previous = body
            continue

        if not MARKER.match(body):
            found.append(f"{path}:{number}:1: error: комментарий только как "
                         f"`// Почему: …` — остальное говорит сам код")
        elif MARKER.match(previous):
            found.append(f"{path}:{number}:1: error: на объяснение отводится одна строка; "
                         f"если не умещается — упростите код")
        elif len(body) > LIMIT:
            found.append(f"{path}:{number}:1: error: объяснение длиннее {LIMIT} символов — "
                         f"упростите код или вынесите знание в ARCHITECTURE.md")
        elif number == len(lines) or closes(lines[number]):
            found.append(f"{path}:{number}:1: error: объяснение стоит в пустоте — "
                         f"оно пишется прямо перед тем, что объясняет")
        else:
            notes.append(f"{path}:{number}:1: warning: здесь комментарием закрыт "
                         f"потенциальный баг — костыль держится на этом объяснении")

        previous = body

    return found, notes


def main() -> int:
    found: list[str] = []
    notes: list[str] = []
    for root in ROOTS:
        for path in sorted(Path(root).rglob("*.swift")):
            errors, warnings = violations(path)
            found += errors
            notes += warnings

    for line in notes:
        print(line, file=sys.stderr)

    if not found:
        print(f"comments ok ({len(notes)} объяснений)")
        return 0

    for line in found:
        print(line, file=sys.stderr)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
