#!/usr/bin/env python3
"""Порядок объявлений: var перед let, а три private-функции подряд — в private extension."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from sources import MODULES as ROOTS

ACCESS = ["open", "public", "package", "internal", "fileprivate", "private"]

PRIVATE_RUN = 3

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


PRIVATE_FUNC = re.compile(r"^\s{4}private\s+(?:static\s+|final\s+)*func\s+(\w+)")

ANY_FUNC = re.compile(r"^\s{4}(?:[\w@\(\)]+\s+)*func\s+\w")

OPENS_TYPE = re.compile(r"^(?:[\w@\(\)]+\s+)*(?:struct|class|enum|actor)\s+\w[^{]*\{\s*$")



def has_private_type(text: str) -> bool:
    """Вынести нельзя: private-тип внутри виден только телу типа."""
    return bool(re.search(r"^\s+private\s+(?:struct|enum|class|actor)\s+\w", text, re.MULTILINE))


def private_runs(path: Path) -> list[str]:
    """Три private-функции подряд в теле типа просятся в private extension."""
    text = path.read_text(encoding="utf-8")
    if has_private_type(text):
        return []

    found: list[str] = []
    inside = False
    run: list[tuple[int, str]] = []

    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.split("//")[0]

        if OPENS_TYPE.match(line):
            inside = True
            run = []
            continue

        if not inside or not ANY_FUNC.match(line):
            continue

        match = PRIVATE_FUNC.match(line)
        if not match:
            run = []
            continue

        run.append((number, match.group(1)))
        if len(run) == PRIVATE_RUN:
            names = ", ".join(name for _, name in run)
            found.append(
                f"{path}:{run[0][0]}:1: error: {PRIVATE_RUN} private-функции подряд "
                f"({names}) — вынесите их в private extension"
            )
            run = []

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



def skips(path: Path) -> bool:
    """Структура без явного init: порядок свойств — это порядок аргументов."""
    text = path.read_text(encoding="utf-8")
    if not re.search(r"^\s*(?:[\w@\(\)]+\s+)*struct\s+\w", text, re.MULTILINE):
        return False

    return not re.search(r"^\s*(?:[\w@\(\)]+\s+)*init\s*\(", text, re.MULTILINE)


def main() -> int:
    found: list[str] = []
    for root in ROOTS:
        for path in sorted(Path(root).rglob("*.swift")):
            if skips(path):
                continue

            found += violations(path)
            found += private_runs(path)

    if not found:
        print("declaration order ok")
        return 0

    for line in found:
        print(line if ": error: " in line else f"error: {line}", file=sys.stderr)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
