#!/usr/bin/env bash
# カードの能力の実演(詳細パネルと同じもの)をGIFにする。
#   tools/discord/build_effect_gif.sh drill
# 出力: assets/mascot/effect_<id>.gif
set -euo pipefail
CARD="${1:?カードのidを指定してください (例: drill)}"
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
FRAMES="scratchpad/fx"
OUT="assets/mascot/effect_${CARD}.gif"

mkdir -p "$FRAMES"
rm -f "$FRAMES"/*.png "$FRAMES"/*.wav
# 固定デルタで書き出すため --write-movie と --fixed-fps は必須
"$GODOT" --path . --write-movie "$FRAMES/f.png" --fixed-fps 15 \
  res://tools/record_effect_gif.tscn -- "$CARD" >/dev/null

# 書き出しは1280x720で行われるため、中央のパネルだけを切り抜く
magick -delay 7 -loop 0 "$FRAMES"/f0*.png -crop 600x340+340+190 +repage \
  -colors 64 -layers OptimizeFrame -layers OptimizeTransparency "$OUT"
rm -f "$FRAMES"/*.png "$FRAMES"/*.wav
printf '%s (%.0f KB)\n' "$OUT" "$(stat -c%s "$OUT" | awk '{print $1/1024}')"
