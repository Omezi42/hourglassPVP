#!/usr/bin/env bash
# Web(unityroom)向けの書き出し。
# unityroomへ上げるのは build/web/index.pck だけ。
# BGMはpckへ入れず(export_presets.cfg の exclude_filter)、実行時に
# MusicPlayer がリポジトリからCDN経由で取りに行く(Architecture.md 4.1.6節)。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"

# バージョンが違う相手とマッチングしないための「ビルドID」を刻む
# (GameDesign.md 11章・Architecture.md 6.4節)。書き出しのたびに切り替わる値を
# ここで1度だけ書き込むことで、手で更新する値を増やさずに済ませている。
# 書き込んだ値はそのままコミットする(直近のビルドがどれかを追えるようにするため)。
BUILD_ID="$(date -u +%Y%m%d-%H%M%S)"
python "$ROOT/tools/stamp_build_id.py" "$ROOT/project.godot" "$BUILD_ID"
echo "build_id = $BUILD_ID"

"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html" > "$ROOT/logs/export_web.log" 2>&1
"$GODOT" --headless --main-pack "$OUT/index.pck" --script res://tools/tests/run_tests.gd 2>&1 | grep -E "tests passed|FAILED" || true

echo "--- unityroomへ上げるのはこれ ---"
ls -la "$OUT/index.pck" | awk '{print $5, $9}'
