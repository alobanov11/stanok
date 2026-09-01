#!/usr/bin/env python3
"""Бюджет булевых на тип: хранимые `Bool` плюс вычисляемые `Bool`.

N хранимых флагов — это 2^N представимых состояний, из которых валидны единицы;
остальные не проверяет никто. Вычисляемые `Bool` считаются вместе с ними: иначе
условия из check-conditions просто переезжают в новое свойство, счётчик падает,
а флаг остаётся навсегда.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from sources import MODULES as ROOTS
from swiftsource import TYPE, plural, strip


class Limit:

    WARNING = 2
    ERROR = 3

    PARAMETERS = 1


MODIFIERS = (r"(?:(?:public|internal|private|fileprivate|package|open|static|class|final"
             r"|lazy|weak|unowned|nonisolated|override|mutating)\s+)*")

STORED = re.compile(rf"^\s*(?!.*\boverride\b){MODIFIERS}var\s+(?P<name>[\w`]+)\s*"
                    rf"(?::\s*Bool\b|=\s*(?:true|false)\s*$)")

DERIVED = re.compile(rf"^\s*(?!.*\boverride\b){MODIFIERS}var\s+(?P<name>[\w`]+)\s*:\s*Bool\s*\{{")

PREDICATE = re.compile(rf"^\s*(?!.*\boverride\b){MODIFIERS}func\s+(?P<name>[\w`]+)\s*"
                       rf"\(\s*\)\s*(?:async\s+)?(?:throws\s+)?->\s*Bool\b")

PARAMETER = re.compile(r"(?P<label>_|\w+)\s+(?P<name>\w+)\s*:\s*Bool\b\s*"
                       r"(?P<default>=\s*(?:true|false)\s*)?[,)]"
                       r"|(?P<single>\w+)\s*:\s*Bool\b\s*(?P<fallback>=\s*(?:true|false)\s*)?[,)]")

SIGNATURE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*[\w\s]*\bfunc\s+(?P<name>[\w`]+)\s*"
                       r"(?:<[^>]*>)?\s*\((?P<parameters>[^)]*)\)")

LATCH = re.compile(r"^(is|has)(Opening|Loading|Syncing|Updating|Refreshing|Reloading"
                   r"|Scanning|Applying|Running|Busy|Pending|InFlight)$")


class Kind:

    STORED = "хранимое"
    DERIVED = "вычисляемое"


class Type:

    def __init__(self, name: str, line: int) -> None:
        self.name = name
        self.line = line
        self.members: list[tuple[str, str]] = []

    @property
    def count(self) -> int:
        return len(self.members)

    def named(self, kind: str) -> list[str]:
        return [name for name, own in self.members if own == kind]

    def hints(self) -> list[str]:
        out: list[str] = []
        stored = self.named(Kind.STORED)
        derived = self.named(Kind.DERIVED)

        latches = [name for name in stored if LATCH.match(name)]
        if latches:
            out.append(f"`{latches[0]}` — защёлка вокруг асинхронной работы; она появляется, "
                       f"когда поток данных зациклился, и лечится владением задачей, а не флагом")

        if len(stored) >= 2:
            out.append(f"{plural(len(stored), 'хранимый флаг', 'хранимых флага', 'хранимых флагов')}"
                       f" — это {plural(2 ** len(stored), 'представимое состояние', 'представимых состояния', 'представимых состояний')}, "
                       f"из которых валидны единицы; сведите их в один `enum` состояния")

        if len(derived) >= 2:
            out.append(f"{plural(len(derived), 'вычисляемый', 'вычисляемых', 'вычисляемых')} "
                       f"`Bool` ({', '.join(f'`{name}`' for name in derived[:3])}) — обычно это "
                       f"спрятанные условия: они не исчезли, а стали невидимыми")

        return out[:2] or ["назовите состояние типом: `Bool` отвечает «да/нет», "
                           "а читателю нужно «в каком мы состоянии»"]


def types(path: Path) -> tuple[list[Type], list[tuple[str, int, list[str]]]]:
    lines = strip(path.read_text(encoding="utf-8")).split("\n")
    found: list[Type] = []
    flagged: list[tuple[str, int, list[str]]] = []
    stack: list[tuple[Type, int]] = []
    depth = 0

    for number, line in enumerate(lines, start=1):
        while stack and depth <= stack[-1][1]:
            stack.pop()

        signature = SIGNATURE.match(line)
        if signature:
            names = [(match.group("name") or match.group("single"),
                      match.group("label") == "_",
                      bool(match.group("default") or match.group("fallback")))
                     for match in PARAMETER.finditer(signature.group("parameters") + ")")]
            hidden = [name for name, unlabelled, defaulted in names if unlabelled or defaulted]
            if hidden:
                flagged.append((signature.group("name"), number, hidden))

        if stack and depth == stack[-1][1] + 1:
            owner = stack[-1][0]
            derived = DERIVED.match(line) or PREDICATE.match(line)
            if derived:
                owner.members.append((derived.group("name"), Kind.DERIVED))
            elif STORED.match(line) and not line.rstrip().endswith("{"):
                owner.members.append((STORED.match(line).group("name"), Kind.STORED))

        declaration = TYPE.match(line)
        if declaration and "{" in line:
            entry = Type(declaration.group("name"), number)
            found.append(entry)
            stack.append((entry, depth))

        depth += line.count("{") - line.count("}")

    return found, flagged


def main() -> int:
    every: list[tuple[Type, Path]] = []
    parameters: list[tuple[str, int, list[str], Path]] = []

    for root in ROOTS:
        for path in sorted(Path(root).rglob("*.swift")):
            found, flagged = types(path)
            merged: dict[str, Type] = {}
            for entry in found:
                if entry.name in merged:
                    merged[entry.name].members += entry.members
                else:
                    merged[entry.name] = entry

            every += [(entry, path) for entry in merged.values() if entry.count]
            parameters += [(name, line, names, path) for name, line, names in flagged]

    if "--report" in sys.argv:
        counts = sorted(entry.count for entry, _ in every)
        print(f"типов с булевыми: {len(counts)}")
        print("распределение:", dict(sorted(Counter(counts).items())))
        for threshold in range(1, 8):
            over = sum(1 for value in counts if value > threshold)
            print(f"  порог {threshold} → нарушений: {over}")
        print("\nтоп:")
        for entry, path in sorted(every, key=lambda item: -item[0].count)[:12]:
            print(f"  {entry.count:3d}  {path}:{entry.line}  {entry.name}  "
                  f"{[name for name, _ in entry.members]}")
        print(f"\nфункций с Bool-параметрами: {len(parameters)}")
        print("распределение:", dict(sorted(Counter(len(names) for _, _, names, _ in parameters).items())))
        for name, line, names, path in sorted(parameters, key=lambda item: -len(item[2]))[:10]:
            print(f"  {len(names)}  {path}:{line}  {name}({', '.join(names)})")
        return 0

    found: list[tuple[bool, str]] = []

    for entry, path in sorted(every, key=lambda item: -item[0].count):
        if entry.count > Limit.ERROR:
            level, limit = "error", Limit.ERROR
        elif entry.count > Limit.WARNING:
            level, limit = "warning", Limit.WARNING
        else:
            continue

        report = [f"{path}:{entry.line}:1: {level}: "
                  f"{plural(entry.count, 'булево', 'булевых', 'булевых')} в `{entry.name}` "
                  f"— больше {limit}"]
        report += [f"{path}:{entry.line}:1: note: {hint}" for hint in entry.hints()]
        found.append((level == "error", "\n".join(report)))

    for name, line, names, path in sorted(parameters, key=lambda item: (str(item[3]), item[1])):
        if len(names) < Limit.PARAMETERS:
            continue

        listed = ", ".join(f"`{value}`" for value in names)
        found.append((False, f"{path}:{line}:1: warning: `Bool` в параметрах `{name}`: {listed} — "
                             f"на месте вызова это `f(true)` без единого намёка на смысл; "
                             f"два метода или `enum` вместо флага"))

    if not found:
        print("booleans ok")
        return 0

    for _, report in found:
        print(report, file=sys.stderr)

    return 1 if any(fatal for fatal, _ in found) else 0


if __name__ == "__main__":
    raise SystemExit(main())
