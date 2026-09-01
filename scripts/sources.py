#!/usr/bin/env python3
"""Единственное место, где перечислены корни исходников.

Запуск без аргументов печатает их через пробел — так их берёт Makefile.
"""

from __future__ import annotations

import sys
from pathlib import Path

MODULES = ["Stanok", "StanokKit/Sources", "StanokKit/Terminal", "StanokKit/Agents"]

TESTS = ["StanokTests"]

ROOTS = MODULES + TESTS


def swift(roots: list[str]) -> list[Path]:
    return sorted(path for root in roots for path in Path(root).rglob("*.swift"))


if __name__ == "__main__":
    print(" ".join(ROOTS))
    sys.exit(0)
