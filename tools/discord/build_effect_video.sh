#!/usr/bin/env bash
# カードの能力の実演(図鑑と同じもの。本物の対局画面の切り抜き)をMP4にする。
#   tools/discord/build_effect_video.sh drill        # 1枚
#   tools/discord/build_effect_video.sh              # 全カード
# 出力: functions/data/effect_videos/<id>.mp4(コミットし、jsDelivr経由で /card と
# 正午のカードスポットライトが読む。Architecture.md 10.14節)
#
# GIFでなくMP4にするのは、盤面の数字が読める大きさ・色数でもGIFの1/10程度の大きさに収まるため。
# 実際にレンダリングしたピクセルを読むため --headless では動かない。
set -euo pipefail
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
FRAMES="scratchpad/fx"
OUT_DIR="functions/data/effect_videos"
FPS=30
# 画質(x264 の CRF。小さいほど高画質で大きい)。
CRF=23
# 1周を録りきれずに固まったときの打ち切り(秒)。
TIMEOUT=180

if [ "$#" -gt 0 ]; then
  IDS="$*"
else
  # Windows版Pythonの標準出力はCRLFになるため \r を落とす
  IDS=$(python tools/list_card_ids.py | tr -d '\r')
fi

mkdir -p "$FRAMES" "$OUT_DIR"
for CARD in $IDS; do
  OUT="$OUT_DIR/${CARD}.mp4"
  rm -f "${FRAMES:?}"/*.png "${FRAMES:?}"/*.wav "${FRAMES:?}"/crop.txt
  # 固定デルタで書き出すため --write-movie と --fixed-fps は必須
  timeout "$TIMEOUT" "$GODOT" --path . --write-movie "$FRAMES/f.png" --fixed-fps "$FPS" \
    res://tools/record_effect_video.tscn -- "$CARD" "$FRAMES/crop.txt" >/dev/null || true
  # 撮影ツールが書いた切り抜く矩形(WxH+X+Y)と、録り始めのコマ番号(それより前は準備中の空のコマ)
  CROP=$(sed -n 1p "$FRAMES/crop.txt" | tr -d '\r')
  START=$(sed -n 2p "$FRAMES/crop.txt" | tr -d '\r')
  read -r W H X Y <<<"$(echo "$CROP" | tr 'x+' '  ')"
  ffmpeg -loglevel error -y -framerate "$FPS" -start_number "$START" -i "$FRAMES/f%08d.png" \
    -vf "crop=$W:$H:$X:$Y,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -crf "$CRF" -preset slow -pix_fmt yuv420p -movflags +faststart -an "$OUT"
  printf '%s (%.0f KB)\n' "$OUT" "$(stat -c%s "$OUT" | awk '{print $1/1024}')"
done
rm -f "${FRAMES:?}"/*.png "${FRAMES:?}"/*.wav "${FRAMES:?}"/crop.txt
