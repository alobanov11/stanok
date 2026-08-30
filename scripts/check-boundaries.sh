#!/bin/sh
# Architectural invariants that a code review would otherwise have to catch by eye.
set -e

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
status=0

leaked=$(grep -rl "import GhosttyKit" Stanok | grep -v "^Stanok/Terminal/" || true)
if [ -n "$leaked" ]; then
  echo "error: GhosttyKit imported outside Stanok/Terminal/:"
  echo "$leaked" | sed 's/^/  /'
  status=1
fi

providers=$(grep -rlniE "\bclaude\b|\bcodex\b|\bgemini\b|\bcursor-agent\b|\bopencode\b" Stanok StanokKit/Sources \
  | grep -vE "^(Stanok|StanokKit/Sources)/Features/Agents/" || true)
if [ -n "$providers" ]; then
  echo "error: provider names outside Stanok/Features/Agents/:"
  echo "$providers" | sed 's/^/  /'
  status=1
fi

[ "$status" -eq 0 ] && echo "boundaries ok"
exit "$status"
