#!/usr/bin/env bash
# Web(unityroom・itch.io・PLiCy)向けの書き出し。
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
# エディタで書き出すとフィルタが空へ戻る。毎回ここで揃え直してから書き出す。
python "$ROOT/tools/ensure_export_filters.py" "$ROOT/export_presets.cfg"

BUILD_ID="$(date -u +%Y%m%d-%H%M%S)"
python "$ROOT/tools/stamp_build_id.py" "$ROOT/project.godot" "$BUILD_ID"
echo "build_id = $BUILD_ID"

# Discord Bot(Cloud Functions)がカードを検索できるよう、最新のカード一覧を
# functions/data/cards.json へ書き出す(GameDesign.md 26章・Architecture.md 10.14節)。
"$GODOT" --headless --path "$ROOT" --script "$ROOT/tools/export_card_data_json.gd"

# 検査用(WebCheck): 本番と同じ中身に tools/ を残したpck。テストのスクリプトがpckの中に要るため、
# 本番(tools/ を外す)とは別に書き出して、こちらへテストを回す(Architecture.md 4.1.6節)。
CHECK="$ROOT/build/web_check"
mkdir -p "$CHECK"
"$GODOT" --headless --path "$ROOT" --export-release "WebCheck" "$CHECK/index.html" > "$ROOT/logs/export_web_check.log" 2>&1
"$GODOT" --headless --main-pack "$CHECK/index.pck" --script res://tools/tests/run_tests.gd 2>&1 | grep -E "tests passed|FAILED" || true
# 検査用pckのまま本物のFirebaseで2人をマッチングさせ、デッキと種の交換まで通す
"$GODOT" --headless --main-pack "$CHECK/index.pck" --script res://tools/tests/matchmaking_live_test.gd 2>&1 | grep -E "matchmaking live|NG:" || true

"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html" > "$ROOT/logs/export_web.log" 2>&1
# 本番のpckには tools/ が無いため、検査のスクリプトはディスクから渡してpckの中身を調べる
"$GODOT" --headless --main-pack "$OUT/index.pck" --script "$ROOT/tools/verify_web_pck.gd" 2>&1 | grep -E "pck check" || true

# pckの急増で止める(Architecture.md 4.1.6節)。前回通した大きさは tools/last_pck_size.txt に控えてコミットする。
# 増えるのが分かっている回は PCK_GROWTH_OK=1 を付けて回す。
PCK_SIZE_FILE="$ROOT/tools/last_pck_size.txt"
PCK_GROWTH_LIMIT=1048576
PCK_SIZE="$(wc -c < "$OUT/index.pck" | tr -d ' ')"
LAST_PCK_SIZE="$(cat "$PCK_SIZE_FILE" 2>/dev/null || echo "$PCK_SIZE")"
if [ $((PCK_SIZE - LAST_PCK_SIZE)) -gt "$PCK_GROWTH_LIMIT" ] && [ "${PCK_GROWTH_OK:-0}" != "1" ]; then
	echo "!!! index.pck が前回より1MB以上増えた($LAST_PCK_SIZE -> $PCK_SIZE)。意図した増加なら PCK_GROWTH_OK=1 で回し直す"
	exit 1
fi
echo "$PCK_SIZE" > "$PCK_SIZE_FILE"

# itch.io・PLiCy 向け(Architecture.md 4.6節)。起動部 build/portal.zip は Godot を上げたときだけ手で上げ直す。
ENGINE_VERSION="$("$GODOT" --version | cut -d. -f1-3 | tr -dc 0-9.)"
python "$ROOT/tools/make_portal.py" "$OUT" "$BUILD_ID" "$ENGINE_VERSION"
bash "$ROOT/tools/deploy_pages.sh" || echo "!!! Cloudflare Pages へのデプロイに失敗(npx wrangler login を確認)"

echo "--- unityroomへ上げるのはこれ ---"
ls -la "$OUT/index.pck" | awk '{print $5, $9}'
