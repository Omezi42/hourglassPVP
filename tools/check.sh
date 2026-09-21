#!/usr/bin/env bash
# 変更後の検証を1コマンドにまとめる: gdformat → gdlint → ヘッドレステスト → 起動スモーク。
# 引数なし: git で変更のある .gd だけを整形・lint する。 --all: scripts/ と tools/ の全 .gd。
# 出力は要点だけに絞る(ログ全文は logs/check_*.log)。
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
PY_SCRIPTS="C:/Users/omezi/AppData/Roaming/Python/Python314/Scripts"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

if [ "${1:-}" = "--all" ]; then
  FILES=$(git ls-files 'scripts/*.gd' 'tools/*.gd' 'tools/**/*.gd')
else
  FILES=$( (git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard) | sort -u | grep '\.gd$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
fi

status=0
if [ -n "$FILES" ]; then
  echo "== gdformat/gdlint ($(echo "$FILES" | wc -l) files)"
  "$PY_SCRIPTS/gdformat.exe" $FILES >/dev/null 2>&1 || true
  "$PY_SCRIPTS/gdlint.exe" $FILES > logs/check_lint.log 2>&1 || { status=1; cat logs/check_lint.log; }
else
  echo "== gdformat/gdlint: 変更された .gd なし"
fi

echo "== headless tests"
"$GODOT" --headless --path . --script res://tools/tests/run_tests.gd > logs/check_tests.log 2>&1
grep -E "tests passed|FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log | head -20
grep -qE "FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log && status=1

echo "== startup smoke"
"$GODOT" --headless --path . --quit-after 60 > logs/check_smoke.log 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10 | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10
  status=1
else
  echo "ok"
fi

[ $status -eq 0 ] && echo "== ALL OK" || echo "== NG (logs/check_*.log)"
exit $status
