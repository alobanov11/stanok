#!/usr/bin/env python3
"""Требует папку для трёх и более файлов с общим префиксом в одном каталоге."""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

THRESHOLD = 3

ROOTS = [
    "Stanok",
    "StanokKit/Sources",
    "StanokKit/Terminal",
    "StanokKit/Agents",
]

WORDS = re.compile(r"[A-Z]+(?![a-z])|[A-Z][a-z0-9]*|[a-z0-9]+")

KEEP_TRAILING_S = ("ss", "us", "is")

DROPS_ES = ("ches", "shes", "sses", "xes", "zes")


def singular(word: str) -> str:
    lowered = word.lower()
    if lowered.endswith(DROPS_ES):
        return word[:-2]

    if not lowered.endswith("s") or lowered.endswith(KEEP_TRAILING_S):
        return word

    return word[:-1]


def tokens(path: Path) -> list[str]:
    return WORDS.findall(path.stem.split("+")[0])


def named_by_folders(word: str, folders: set[str]) -> bool:
    return singular(word).lower() in folders


def collect(paths: list[Path], depth: int, folders: set[str]) -> dict[str, list[Path]]:
    """Группирует по слову на позиции depth, ныряя глубже под именами папок."""
    buckets: dict[str, list[Path]] = defaultdict(list)

    for path in paths:
        words = tokens(path)
        if len(words) > depth:
            buckets[singular(words[depth])].append(path)

    groups: dict[str, list[Path]] = {}

    for name, group in buckets.items():
        if named_by_folders(name, folders):
            groups.update(collect(group, depth + 1, folders))
        else:
            groups[name] = group

    return groups


def merged(groups: dict[str, list[Path]]) -> dict[str, list[Path]]:
    """CodeFold и CodeFolding — один префикс: короткое слово начинает длинное."""
    result: dict[str, list[Path]] = defaultdict(list)

    for name, paths in groups.items():
        base = min(
            (other for other in groups if len(other) >= 4 and name.startswith(other)),
            key=len,
            default=name
        )
        result[base] += paths

    return result


def violations(root: Path) -> list[str]:
    found: list[str] = []

    for directory in sorted({path.parent for path in root.rglob("*.swift")}):
        folders = {singular(part).lower() for part in directory.parts}
        groups = merged(collect(sorted(directory.glob("*.swift")), depth=0, folders=folders))

        for name, paths in sorted(groups.items()):
            if len(paths) < THRESHOLD:
                continue

            files = ", ".join(path.name for path in sorted(paths))
            found.append(
                f"{directory}: {len(paths)} файла с префиксом {name} — "
                f"вынести в {directory}/{name}/ ({files})"
            )

    return found


def main() -> int:
    found: list[str] = []
    for root in ROOTS:
        found += violations(Path(root))

    if not found:
        print("file groups ok")
        return 0

    for line in found:
        print(f"error: {line}", file=sys.stderr)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
