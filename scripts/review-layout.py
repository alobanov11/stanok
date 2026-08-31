#!/usr/bin/env python3
"""Подсказки по раскладке файлов: кандидаты на папку, на схлопывание и на переименование.

Сборку не ломает: это вопросы к автору, а не правила.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path


class Limit:

    GROUP = 3           # столько файлов с общим началом уже просят папку
    DIRECTORY = 6       # в каталоге меньше файлов — папка только добавит вложенности
    REST = 2            # столько файлов должно остаться снаружи, иначе это переименование
    DEPTH = 3           # уровней ниже корня модуля
    FOLDER = 2          # папка меньше — кандидат на схлопывание


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


def group_hints(directory: Path, files: list[Path], folders: set[str]) -> list[str]:
    """Просится ли внутри каталога отдельная папка.

    Смотрим только на первое слово имени: если оно уже названо папкой выше,
    группа сложилась, и вторым уровнем вложенности имена короче не станут.
    """
    if len(files) < Limit.DIRECTORY:
        return []

    hints: list[str] = []

    for name, paths in sorted(merged(collect(files, 0, set())).items()):
        if named_by_folders(name, folders):
            continue

        outside = len(files) - len(paths)
        if len(paths) < Limit.GROUP or outside < Limit.REST:
            continue

        names = ", ".join(path.name for path in paths)
        hints.append(
            f"{directory}: {len(paths)} файла начинаются на {name}, рядом ещё {outside} "
            f"— точно ли им место в одном каталоге? Кандидат на {directory}/{name}/ ({names})"
        )

    return hints


def folder_hints(root: Path, directory: Path, files: list[Path]) -> list[str]:
    """Не слишком ли дробно и не слишком ли глубоко."""
    hints: list[str] = []
    depth = len(directory.relative_to(root).parts)
    children = [path for path in directory.iterdir() if path.is_dir()]

    if directory != root and not children and len(files) < Limit.FOLDER:
        hints.append(
            f"{directory}: папка из {len(files)} файла — точно ли она нужна? "
            f"Кандидат на переезд в {directory.parent}"
        )

    if depth > Limit.DEPTH:
        hints.append(
            f"{directory}: вложенность {depth} уровня — точно ли файлы должны лежать "
            f"так глубоко?"
        )

    return hints


def name_hints(root: Path, directory: Path, files: list[Path]) -> list[str]:
    """Имя, повторяющее сразу две папки, — кандидат на переименование.

    Одну папку имя повторяет законно: swiftlint требует, чтобы файл звался
    как тип внутри него.
    """
    if directory == root:
        return []

    folders = [singular(part).lower() for part in directory.relative_to(root).parts]
    hints: list[str] = []

    for path in files:
        words = tokens(path)
        repeated = 0
        while repeated < len(words) and singular(words[repeated]).lower() in folders:
            repeated += 1

        if repeated < 2 or repeated == len(words):
            continue

        shorter = "".join(words[repeated:]) + path.suffix
        hints.append(
            f"{path}: имя повторяет папку {'/'.join(directory.relative_to(root).parts)} "
            f"— точно ли не {shorter}?"
        )

    return hints


def hints(root: Path) -> list[str]:
    found: list[str] = []

    for directory in sorted({path.parent for path in root.rglob("*.swift")}):
        files = sorted(directory.glob("*.swift"))
        folders = {singular(part).lower() for part in directory.parts}

        found += folder_hints(root, directory, files)
        found += group_hints(directory, files, folders)
        found += name_hints(root, directory, files)

    return found


def main() -> int:
    found: list[str] = []
    for root in ROOTS:
        found += hints(Path(root))

    if not found:
        print("layout ok")
        return 0

    for line in found:
        print(f"warning: {line}")

    print(f"{len(found)} кандидатов на рефакторинг — сборку это не ломает")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
