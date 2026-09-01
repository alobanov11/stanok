#!/usr/bin/env python3
"""В длинном блоке хранимых свойств родственные держатся вместе: флаги к флагам,
одноимённые по смыслу — рядом. Порядок групп задаёт первое появление."""

from __future__ import annotations

import re
import sys
from pathlib import Path

MINIMUM = 4

TYPE = re.compile(r"^(\s*)(?:[\w@\(\)]+\s+)*(?:struct|class|enum|actor|extension)\s+\w")

PROPERTY = re.compile(
    r"^(\s*)(?:(open|public|package|internal|fileprivate|private)(?:\(set\))?\s+)?"
    r"((?:(?:static|class|final|lazy|weak|unowned|nonisolated|override)\s+)*)"
    r"(let|var)\s+(\w+)"
)

ATTRIBUTE = re.compile(r"^\s*@\w+")

WORD = re.compile(r"[A-Z]+(?![a-z])|[A-Z][a-z]+|[a-z]+|\d+")

FLAG_PREFIX = ("is", "has", "should", "can", "will", "did", "does", "needs", "was", "are")

NOISE = {
    "last", "latest", "previous", "next", "current", "pending", "applied", "desired",
    "held", "cached", "initial", "default", "first", "new", "old", "temp", "handled",
    "the", "my", "own",
}


class Property:

    def __init__(self, line: str, index: int, group: tuple[str, str, str], name: str):
        self.line = line
        self.index = index
        self.group = group
        self.name = name
        self.key = ""


def words(name: str) -> list[str]:
    return [word.lower() for word in WORD.findall(name)]


def flag(item: Property) -> bool:
    """Флаг — булево свойство: по типу, по значению или по приставке имени."""
    body = item.line.split("//")[0]
    if re.search(r":\s*Bool\b", body) or re.search(r"=\s*(?:true|false)\s*$", body.rstrip()):
        return True

    parts = words(item.name)

    return bool(parts) and parts[0] in FLAG_PREFIX


def keyed(run: list[Property]) -> None:
    """Ключ группы: первое значимое слово имени, встречающееся ещё у кого-то в блоке."""
    shared: dict[str, int] = {}
    for item in run:
        if flag(item):
            continue

        for word in {word for word in words(item.name) if word not in NOISE}:
            shared[word] = shared.get(word, 0) + 1

    for item in run:
        if flag(item):
            item.key = "flag"
            continue

        item.key = next(
            (word for word in words(item.name) if shared.get(word, 0) > 1),
            f"self:{item.name}",
        )


def regrouped(run: list[Property]) -> list[Property]:
    keyed(run)
    order: list[str] = []
    for item in run:
        if item.key not in order:
            order.append(item.key)

    return [item for key in order for item in run if item.key == key]


def runs(lines: list[str]) -> list[list[Property]]:
    """Блоки идущих подряд простых свойств в теле типа — без вложенных областей."""
    found: list[list[Property]] = []
    run: list[Property] = []
    depth = 0
    type_depth: int | None = None
    decorated = False

    for index, raw in enumerate(lines):
        line = raw.split("//")[0]
        body = line.strip()

        if TYPE.match(line) and line.rstrip().endswith("{"):
            type_depth = depth

        match = PROPERTY.match(line)
        simple = (
            match
            and type_depth is not None
            and depth == type_depth + 1
            and "{" not in body
            and "}" not in body
            and "//" not in raw
            and not decorated
        )

        if simple:
            _, access, scope, kind, name = match.groups()
            group = (access or "internal", " ".join(scope.split()), kind)
            item = Property(raw, index, group, name)
            if run and (run[-1].group != group or run[-1].index != index - 1):
                if len(run) >= MINIMUM:
                    found.append(run)
                run = []
            run.append(item)
        elif run:
            if len(run) >= MINIMUM:
                found.append(run)
            run = []

        if body:
            decorated = bool(ATTRIBUTE.match(line))

        depth += line.count("{") - line.count("}")
        if type_depth is not None and depth <= type_depth:
            type_depth = None

    if len(run) >= MINIMUM:
        found.append(run)

    return found


def scattered(run: list[Property]) -> list[str]:
    """Свойства, оторванные от своей группы: их ключ уже встречался выше не вплотную."""
    seen: dict[str, int] = {}
    found: list[str] = []

    for position, item in enumerate(run):
        if item.key in seen and seen[item.key] != position - 1:
            found.append(item.name)
        seen[item.key] = position

    return found


def rewrite(text: str) -> tuple[str, list[str]]:
    lines = text.splitlines()
    result = list(lines)
    complaints: list[str] = []

    for run in runs(lines):
        ordered = regrouped(run)
        if ordered == run:
            continue

        moved = scattered(run)
        complaints.append(
            f"{run[0].index + 1}:1: error: {', '.join(moved)} — оторваны от своей группы; "
            f"родственные объявляются подряд (make format)"
        )

        for position, item in enumerate(ordered):
            result[run[position].index] = item.line

    return "\n".join(result) + "\n", complaints


def skips(path: Path) -> bool:
    """Структура без явного init: порядок свойств — это порядок аргументов."""
    text = path.read_text(encoding="utf-8")
    if not re.search(r"^\s*(?:[\w@\(\)]+\s+)*struct\s+\w", text, re.MULTILINE):
        return False

    return not re.search(r"^\s*(?:[\w@\(\)]+\s+)*init\s*\(", text, re.MULTILINE)


def main() -> int:
    check = "--check" in sys.argv
    names = [name for name in sys.argv[1:] if name != "--check"]
    unsorted: list[str] = []

    for name in names:
        path = Path(name)
        if skips(path):
            continue

        text = path.read_text(encoding="utf-8")
        updated, complaints = rewrite(text)

        if updated == text:
            continue

        if sorted(text.split()) != sorted(updated.split()):
            print(f"error: {path} — правка меняет не только порядок строк", file=sys.stderr)
            return 1

        if check:
            unsorted += [f"{path}:{complaint}" for complaint in complaints]
            continue

        path.write_text(updated, encoding="utf-8")
        print(f"fixed {path}")

    for complaint in unsorted:
        print(complaint, file=sys.stderr)

    return 1 if unsorted else 0


if __name__ == "__main__":
    raise SystemExit(main())
