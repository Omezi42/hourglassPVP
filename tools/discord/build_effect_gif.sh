#!/usr/bin/env bash
# カードの能力の実演(詳細パネルと同じもの)をGIFにする。
#   tools/discord/build_effect_gif.sh drill        # 1枚
#   tools/discord/build_effect_gif.sh              # 全カード
# 出力: functions/data/effect_gifs/<id>.gif(コミットし、jsDelivr経由で /card と
# 正午のカードスポットライトが読む。Architecture.md 10.14節)
#
# 実際にレンダリングしたピクセルを読むため --headless では動かない。
set -euo pipefail
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
FRAMES="scratchpad/fx"
OUT_DIR="functions/data/effect_gifs"

if [ "$#" -gt 0 ]; then
  IDS="$*"
else
  # Windows版Pythonの標準出力はCRLFになるため \r を落とす
  IDS=$(python tools/list_card_ids.py | tr -d '\r')
fi

mkdir -p "$FRAMES" "$OUT_DIR"
for CARD in $IDS; do
  OUT="$OUT_DIR/${CARD}.gif"
  rm -f "$FRAMES"/*.png "$FRAMES"/*.wav
  # 固定デルタで書き出すため --write-movie と --fixed-fps は必須
  "$GODOT" --path . --write-movie "$FRAMES/f.png" --fixed-fps 15 \
    res://tools/record_effect_gif.tscn -- "$CARD" >/dev/null
  # 書き出しは1280x720で行われるため、中央のパネルだけを切り抜く
  magick -delay 7 -loop 0 "$FRAMES"/f0*.png -crop 600x340+340+190 +repage \
    -colors 64 -layers OptimizeFrame -layers OptimizeTransparency "$OUT"
  printf '%s (%.0f KB)\n' "$OUT" "$(stat -c%s "$OUT" | awk '{print $1/1024}')"
done
rm -f "$FRAMES"/*.png "$FRAMES"/*.wav
