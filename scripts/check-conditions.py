#!/usr/bin/env python3
"""Булевы условия на функцию: `if`, `guard`, `while`, тернарник и каждое `,`/`&&`/`||` внутри.

Одно условие ничего не стоит. Восемь — это восемь неявных предусловий, которые
копятся к хвосту функции: каждое следующее молча зависит от того, что прошли
предыдущие, и порядок между ними нигде не записан.

К нарушению печатается подсказка, выведенная из самой функции: скрипт смотрит,
из-за чего именно набралось число, и называет подходящий приём.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from sources import MODULES as ROOTS
from swiftsource import plural, strip


class Limit:

    WARNING = 5
    ERROR = 7

    VIEW_WARNING = 4
    VIEW_ERROR = 6

    WIDE = 4
    DEEP = 3
    TERNARIES = 3
    FLAGS = 2
    EXITS = 4
    CHAIN = 4


DECLARATION = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:(?:public|internal|private|fileprivate|package|open|static|class|final|override"
    r"|mutating|nonisolated|convenience|required|lazy|dynamic)\s+)*"
    r"(?:func\s+(?P<func>[\w`]+)|(?P<init>init\b)|(?P<deinit>deinit\b)"
    r"|(?P<subscript>subscript\b))"
)

COMPUTED = re.compile(
    r"^\s*(?:(?:public|internal|private|fileprivate|package|open|static|class|final|override"
    r"|nonisolated|unowned)\s+)*"
    r"var\s+(?P<var>[\w`]+)\s*:[^={]+\{\s*$"
)

BRANCH = re.compile(r"(?<![\w.$])(if|guard|while)(?![\w])")

TERNARY = re.compile(r"(?<![?\w)\]>])\?(?![?.:\w])")

AWAIT = re.compile(r"(?<![\w.])await(?![\w])")

VIEW = re.compile(r"@ViewBuilder\b|:\s*some\s+View\b|->\s*some\s+View\b")

FLAG = re.compile(r"(?<![\w.])(is|has|should|needs|can|did|was)[A-Z]\w*")

SPACES = re.compile(r"\s+")

ATTRIBUTES = 3



class Branch:

    def __init__(self, keyword: str, line: int, count: int,
                 text: str, depth: int, delayed: bool) -> None:
        self.keyword = keyword
        self.line = line
        self.count = count
        self.text = text
        self.depth = depth
        self.delayed = delayed



def condition(text: str, start: int) -> tuple[int, int, str]:
    """Разбирает условие ветвления: (конец, число условий, текст)."""
    depth = 0
    count = 1
    cursor = start

    while cursor < len(text):
        char = text[cursor]

        if char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif depth == 0:
            if char == "{":
                break
            if char == ",":
                count += 1
            elif text.startswith("&&", cursor) or text.startswith("||", cursor):
                count += 1
                cursor += 1
            elif text.startswith("else", cursor) and not text[cursor - 1].isalnum():
                break

        cursor += 1

    return cursor, count, SPACES.sub(" ", text[start:cursor]).strip()


def branches(body: str, offset: int) -> list[Branch]:
    """Все ветвления тела с их глубиной и признаком «после await»."""
    found: list[Branch] = []
    opened: list[int] = []
    scopes: list[bool] = [False]
    depth = 0
    cursor = 0

    while cursor < len(body):
        char = body[cursor]

        if char == "{":
            depth += 1
            scopes.append(scopes[-1])
            cursor += 1
            continue

        if char == "}":
            depth -= 1
            if len(scopes) > 1:
                scopes.pop()
            while opened and depth <= opened[-1]:
                opened.pop()
            cursor += 1
            continue

        if AWAIT.match(body, cursor):
            scopes[-1] = True
            cursor += 5
            continue

        line = offset + body.count("\n", 0, cursor)
        match = BRANCH.match(body, cursor)
        if match:
            end, count, text = condition(body, match.end())
            found.append(Branch(match.group(1), line, count, text, len(opened), scopes[-1]))
            opened.append(depth)
            cursor = end
            continue

        if TERNARY.match(body, cursor):
            found.append(Branch("?:", line, 1, "?:", len(opened), scopes[-1]))

        cursor += 1

    return found


class Function:

    def __init__(self, name: str, line: int, view: bool, found: list[Branch]) -> None:
        self.name = name
        self.line = line
        self.view = view
        self.branches = found
        self.count = sum(branch.count for branch in found)

    def hints(self) -> list[str]:
        """Подсказки, выведенные из того, чем именно набралось число."""
        out: list[str] = []

        widest = max(self.branches, key=lambda branch: branch.count, default=None)
        if widest is not None and widest.count >= Limit.WIDE:
            out.append(f"одно ветвление из {plural(widest.count, 'условия', 'условий', 'условий')} — "
                       f"это столько же предусловий, нигде не названных; сузьте тип на входе "
                       f"или сравните одно значение вместо набора полей")

        repeats: dict[str, list[int]] = {}
        for branch in self.branches:
            if branch.keyword != "?:":
                repeats.setdefault(branch.text, []).append(branch.line + 1)

        twice = [lines for lines in repeats.values() if len(lines) > 1]
        if twice:
            where = ", ".join(str(line) for line in twice[0])
            out.append(f"одно и то же условие проверяется в строках {where} — значит, "
                       f"оно проверяется не там, где принимается решение")

        after = sum(1 for branch in self.branches if branch.delayed)
        if after >= Limit.WIDE:
            out.append(f"{plural(after, 'условие', 'условия', 'условий')} после `await` — "
                       f"это ручная перепроверка актуальности; её делает отмена Task, "
                       f"а не поля-эпохи и флаги")

        deepest = max((branch.depth for branch in self.branches), default=0)
        if deepest >= Limit.DEEP:
            out.append(f"вложенность {deepest} — вынесите тело внутренней ветки в функцию с именем")

        ternaries = sum(1 for branch in self.branches if branch.text == "?:")
        if ternaries >= Limit.TERNARIES:
            out.append(f"{plural(ternaries, 'тернарник', 'тернарника', 'тернарников')} — "
                       f"это таблица соответствий или вычисляемое свойство на модели")

        names = sorted({match.group(0) for branch in self.branches
                        for match in FLAG.finditer(branch.text)})
        if len(names) >= Limit.FLAGS:
            out.append(f"ветвление по флагам {', '.join(f'`{name}`' for name in names[:4])} — "
                       f"набор Bool просится в enum, и тогда это станет `switch`")

        exits = sum(1 for branch in self.branches if branch.keyword == "guard")
        if exits >= Limit.EXITS:
            out.append(f"{plural(exits, 'ранний выход', 'ранних выхода', 'ранних выходов')} — "
                       f"функция и отбирает, и делает; разнесите отбор и работу "
                       f"по разным функциям")

        chain = sum(1 for branch in self.branches if branch.keyword == "if" and branch.depth == 0)
        if chain >= Limit.CHAIN:
            out.append(f"{plural(chain, 'независимый', 'независимых', 'независимых')} `if` подряд — "
                       f"обычно это разбор одного значения; назовите его типом "
                       f"и сделайте `switch`")

        return out[:2] or ["разделите функцию на этапы, у каждого из которых есть имя"]


def functions(path: Path) -> list[Function]:
    lines = strip(path.read_text(encoding="utf-8")).split("\n")
    result: list[Function] = []
    index = 0

    while index < len(lines):
        match = DECLARATION.match(lines[index]) or COMPUTED.match(lines[index])
        if not match:
            index += 1
            continue

        opening = index
        while opening < len(lines) and "{" not in lines[opening]:
            if opening > index and (not lines[opening].strip() or "}" in lines[opening]):
                break
            opening += 1

        if opening >= len(lines) or "{" not in lines[opening]:
            index += 1
            continue

        depth = 0
        end = opening

        while end < len(lines):
            depth += lines[end].count("{") - lines[end].count("}")
            if depth <= 0:
                break
            end += 1

        name = next((value for value in match.groupdict().values() if value), "?")
        signature = "\n".join(lines[max(0, index - ATTRIBUTES):opening + 1])
        body = "\n".join(lines[index:end + 1])
        result.append(Function(name, index + 1, VIEW.search(signature) is not None,
                               branches(body, index)))
        index = end + 1

    return result


MEMO = (
    "памятка: число падает только тогда, когда условие исчезает — набор Bool стал enum,\n"
    "        несколько сравнений стали сравнением одного значения, невозможное состояние\n"
    "        перестало быть представимым. Вынести условия в `Bool`-свойство нельзя:\n"
    "        счётчик упадёт, читаемость нет, а флаг переживёт вас."
)


def main() -> int:
    every = [(function, path)
             for root in ROOTS
             for path in sorted(Path(root).rglob("*.swift"))
             for function in functions(path)]

    if "--report" in sys.argv:
        for label, wanted in (("обычные функции", False), ("SwiftUI-вью", True)):
            counts = sorted(function.count for function, _ in every if function.view is wanted)
            total = len(counts)
            print(f"\n=== {label}: {total} ===")
            print("распределение:", dict(sorted(Counter(counts).items())))
            for share in (0.5, 0.9, 0.95, 0.99):
                print(f"  p{int(share * 100)} = {counts[int(total * share)]}")
            for threshold in range(3, 13):
                over = sum(1 for value in counts if value > threshold)
                print(f"  порог {threshold:2d} → нарушений: {over:3d} ({over / total * 100:.1f}%)")
        return 0

    found: list[tuple[bool, str]] = []

    for function, path in sorted(every, key=lambda item: -item[0].count):
        error = Limit.VIEW_ERROR if function.view else Limit.ERROR
        warning = Limit.VIEW_WARNING if function.view else Limit.WARNING
        where = "во вью" if function.view else "в"

        if function.count > error:
            level, limit = "error", error
        elif function.count > warning:
            level, limit = "warning", warning
        else:
            continue

        report = [f"{path}:{function.line}:1: {level}: "
                  f"{plural(function.count, 'условие', 'условия', 'условий')} {where} "
                  f"`{function.name}` — больше {limit}"]
        report += [f"{path}:{function.line}:1: note: {hint}" for hint in function.hints()]
        found.append((level == "error", "\n".join(report)))

    if not found:
        print("conditions ok")
        return 0

    for _, report in found:
        print(report, file=sys.stderr)

    print("\n" + MEMO, file=sys.stderr)

    return 1 if any(fatal for fatal, _ in found) else 0


if __name__ == "__main__":
    raise SystemExit(main())
