#!/usr/bin/env python3
"""Хранимые свойства: сперва доступ пошире, внутри группы var перед let."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOTS = ["Stanok", "StanokKit/Sources", "StanokKit/Terminal", "StanokKit/Agents"]

ACCESS = ["open", "public", "package", "internal", "fileprivate", "private"]

TYPE = re.compile(r"^(\s*)(?:[\w@\(\)]+\s+)*(?:struct|class|enum|actor|extension)\s+\w")

PROPERTY = re.compile(
    r"^(\s*)(?:(open|public|package|internal|fileprivate|private)(?:\(set\))?\s+)?"
    r"(?:(static|class)\s+)?(let|var)\s+(\w+)"
)


ATTRIBUTE = re.compile(r"^\s*@\w+")


class Property:

    def __init__(self, owner: int, line: int, access: str, scope: str, kind: str, name: str):
        self.owner = owner
        self.line = line
        self.access = access
        self.scope = scope
        self.kind = kind
        self.name = name


def stored(text: str, indent: str) -> bool:
    """Хранимое свойство: без тела и без ключей вычисляемого."""
    body = text.strip()

    return not body.endswith("{") and " { " not in body


def properties(path: Path) -> list[Property]:
    found: list[Property] = []
    depth = 0
    type_depth: int | None = None
    owner = 0
    wrapped = False

    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.split("//")[0]

        if TYPE.match(line) and line.rstrip().endswith("{"):
            type_depth = depth
            owner = number

        match = PROPERTY.match(line)
        if match and type_depth is not None and depth == type_depth + 1:
            indent, access, scope, kind, name = match.groups()
            # свойства с обёрткой (@State, @Binding) формирует swiftformat, их не трогаем
            if stored(line, indent) and not wrapped:
                found.append(
                    Property(owner, number, access or "internal", scope or "", kind, name)
                )

        if line.strip():
            wrapped = bool(ATTRIBUTE.match(line))

        depth += line.count("{") - line.count("}")
        if type_depth is not None and depth <= type_depth:
            type_depth = None

    return found


def violations(path: Path) -> list[str]:
    found: list[str] = []
    seen_let: dict[tuple[int, str, str], int] = {}
    widest: dict[tuple[int, str], int] = {}

    for item in properties(path):
        rank = ACCESS.index(item.access)
        group = (item.owner, item.access, item.scope)
        scope = (item.owner, item.scope)

        if rank < widest.get(scope, 0):
            found.append(
                f"{path}:{item.line}: {item.name} — доступ {item.access} стоит после более "
                f"узкого; группируйте свойства по уровню доступа"
            )
        widest[scope] = max(widest.get(scope, 0), rank)

        if item.kind == "let":
            seen_let.setdefault(group, item.line)
        elif group in seen_let:
            found.append(
                f"{path}:{item.line}: {item.name} — var после let (строка "
                f"{seen_let[group]}); внутри группы var идут первыми"
            )

    return found


def main() -> int:
    found: list[str] = []
    for root in ROOTS:
        for path in sorted(Path(root).rglob("*.swift")):
            found += violations(path)

    if not found:
        print("declaration order ok")
        return 0

    for line in found:
        print(f"error: {line}", file=sys.stderr)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
