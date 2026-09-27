#!/usr/bin/env bash
# 変更後の検証を1コマンドにまとめる: gdformat → gdlint → ヘッドレステスト → 誘導対局の通し → 初回起動の直行 → 起動スモーク。
# 引数なし: git で変更のある .gd だけを整形・lint する。 --all: scripts/ と tools/ の全 .gd。
# 出力は要点だけに絞る(ログ全文は logs/check_*.log)。
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
# 1回の実行の上限(秒)。コンパイルに失敗したスクリプトは quit() まで届かず終わらないため。
GODOT_TIMEOUT="${GODOT_TIMEOUT:-600}"
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

# class_name の登録(.godot はgit管理外)が古いと、テストはコンパイルに失敗したまま一部だけ走り、
# 関係ないテストの名前が付いたエラーを残して終わらずに固まる。足りなければ登録し直す。
CLASS_CACHE=.godot/global_script_class_cache.cfg
missing=$(git ls-files 'scripts/*.gd' 'tools/*.gd' 'tools/**/*.gd' | xargs grep -h '^class_name ' | awk '{print $2}'   | while read -r c; do grep -q "\"class\": &\"$c\"" "$CLASS_CACHE" 2>/dev/null || echo "$c"; done)
if [ -n "$missing" ]; then
  echo "== class_name の登録を更新 ($(echo "$missing" | wc -l) 件)"
  timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --import > logs/check_import.log 2>&1
fi

echo "== headless tests"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/tests/run_tests.gd > logs/check_tests.log 2>&1
grep -E "tests passed|FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log | head -20
grep -qE "FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log && status=1
grep -q "tests passed" logs/check_tests.log || status=1

echo "== tutorial flow"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/tests/tutorial_flow_smoke.gd > logs/check_flow.log 2>&1
grep -E "tutorial flow|SCRIPT ERROR|Parse Error" logs/check_flow.log | head -10
grep -q "tutorial flow passed" logs/check_flow.log || status=1

echo "== first launch"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/tests/first_launch_smoke.gd > logs/check_first.log 2>&1
grep -E "first launch|SCRIPT ERROR|Parse Error" logs/check_first.log | head -10
grep -q "first launch passed" logs/check_first.log || status=1

echo "== startup smoke"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --quit-after 60 > logs/check_smoke.log 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10 | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10
  status=1
else
  echo "ok"
fi

[ $status -eq 0 ] && echo "== ALL OK" || echo "== NG (logs/check_*.log)"
exit $status
