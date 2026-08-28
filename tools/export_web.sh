#!/usr/bin/env bash
# Web(unityroom)向けの書き出し。
# BGMはpckへ入れず(export_presets.cfg の exclude_filter)、index.htmlと同じ階層へ
# 素のoggとして置き、実行時にMusicPlayerが取りに行く(Architecture.md 4.1.6節)。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"

mkdir -p "$OUT/bgm"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html" > "$ROOT/logs/export_web.log" 2>&1
cp "$ROOT"/assets/bgm/*.ogg "$OUT/bgm/"

echo "--- build/web ---"
ls -la "$OUT" "$OUT/bgm" | awk '{print $5, $9}'
