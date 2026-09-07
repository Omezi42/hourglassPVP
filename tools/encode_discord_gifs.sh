#!/usr/bin/env bash
# tools/export_discord_effect_gifs.sh が書き出したPNG連番を、カードごとに1本のGIFへ
# エンコードする(GameDesign.md 26章・Architecture.md 10.14節)。
#
# クロップ矩形(600x340+340+190)は record_effect_gif.gd の PANEL 定数と、それを
# 1280x720の中央へ置く計算式から来ている(同ファイルの冒頭コメントと同じ値)。
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES_DIR="$ROOT/scratchpad/discord_fx"
OUT_DIR="$ROOT/functions/data/effect_gifs"

mkdir -p "$OUT_DIR"

count=0
for dir in "$FRAMES_DIR"/*/; do
	id="$(basename "$dir")"
	echo "encoding $id..."
	magick -delay 6.67 -loop 0 "$dir"f0*.png -crop 600x340+340+190 +repage \
		-colors 64 -layers OptimizeFrame "$OUT_DIR/$id.gif"
	count=$((count + 1))
done

echo "done encoding $count cards to $OUT_DIR"
