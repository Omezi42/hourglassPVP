#!/usr/bin/env bash
# Web(unityroom)向けの書き出し。
# unityroomへ上げるのは build/web/index.pck だけ。
# BGMはpckへ入れず(export_presets.cfg の exclude_filter)、実行時に
# MusicPlayer がリポジトリからCDN経由で取りに行く(Architecture.md 4.1.6節)。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"

"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html" > "$ROOT/logs/export_web.log" 2>&1
"$GODOT" --headless --main-pack "$OUT/index.pck" --script res://tools/tests/run_tests.gd 2>&1 | grep -E "tests passed|FAILED" || true

echo "--- unityroomへ上げるのはこれ ---"
ls -la "$OUT/index.pck" | awk '{print $5, $9}'
