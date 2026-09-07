#!/usr/bin/env bash
# カードごとの効果実演を、既存の record_effect_gif.gd/.tscn を使ってPNG連番として
# 書き出す(GameDesign.md 26章・Architecture.md 10.14節)。
#
# 実際にレンダリングしたピクセルを読む必要があるため --headless では動かない。
# tools/export_web.sh(全工程が --headless)には組み込まず、カードを追加・変更した
# ときに手動で実行する(add-hourglass Skillの手順の一部として使う)。
#
# 撮影が終わったら tools/encode_discord_gifs.sh でGIFへエンコードすること。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES_DIR="$ROOT/scratchpad/discord_fx"

mkdir -p "$FRAMES_DIR"

# Windows版Pythonの標準出力はCRLFになるため、末尾の \r を落としてから単語分割する
# (\r が残るとGodotへ渡すパスが壊れ、"d.is_null()" で撮影が丸ごと失敗した)。
IDS=$(python "$ROOT/tools/list_card_ids.py" | tr -d '\r')

for id in $IDS; do
	out_dir="$FRAMES_DIR/$id"
	rm -rf "$out_dir"
	mkdir -p "$out_dir"
	echo "recording $id..."
	"$GODOT" --path "$ROOT" --write-movie "$out_dir/f.png" --fixed-fps 15 \
		"$ROOT/tools/record_effect_gif.tscn" -- "$id" > /dev/null
done

echo "done recording $(echo "$IDS" | wc -l) cards. run tools/encode_discord_gifs.sh next."
