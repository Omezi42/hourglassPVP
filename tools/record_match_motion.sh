#!/usr/bin/env bash
# 対局の動き(攻撃・決着・反転権)を縦横で撮り、GIF・MP4・要所の静止画にする。
#   tools/record_match_motion.sh <出力先>                     # 3場面 x 縦横
#   tools/record_match_motion.sh <出力先> finale portrait     # 場面と向きを絞る
# 出力先/<場面>_<向き>.gif / .mp4 と、出力先/stills/<場面>_<向き>_<イベント>.png ができる。
# 撮影そのものは tools/record_match_motion.gd(実際に描画するため --headless では動かない)。
# 連番PNGは変換が済んだら消す。
set -euo pipefail
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
OUT="${1:?usage: record_match_motion.sh <out_dir> [scene] [orientation]}"
SCENES="${2:-attack finale flip_right}"
ORIENTS="${3:-landscape portrait}"
FPS=30
# GIFは軽くするため間引き、縦横とも高さ720から縮める。
GIF_FPS=20
GIF_WIDTH_LANDSCAPE=960
GIF_WIDTH_PORTRAIT=540
CRF=20
# 撮りきれずに固まったときの打ち切り(秒)。
TIMEOUT=240
# 静止画に取るイベント(events.txt の名前)。「名前+N」はそのNコマ後。無いものは飛ばす。
STILL_EVENTS="select_own press_target press_face press_flip_right impact impact+4 impact+10 strike_settled vessel_shatter_started vessel_shatter_started+10 vessel_shatter_started+20 result_shown remaining_decreased remaining_decreased+10 flip_landed flip_settled"

mkdir -p "$OUT/stills" "$OUT/_work"
for SCENE in $SCENES; do
  for ORIENT in $ORIENTS; do
    TAG="${SCENE}_${ORIENT}"
    WORK="$OUT/_work/$TAG"
    rm -rf "$WORK"
    # 固定デルタで書き出すため --write-movie と --fixed-fps を付ける(映像そのものは使わない)
    timeout "$TIMEOUT" "$GODOT" --path . --write-movie "$OUT/_work/${TAG}_movie.avi" \
      --fixed-fps "$FPS" res://tools/record_match_motion.tscn -- "$WORK" "$SCENE" "$ORIENT" \
      >/dev/null 2>&1 || true
    if [ ! -f "$WORK/events.txt" ]; then
      echo "撮れなかった: $TAG" >&2
      continue
    fi
    if [ "$ORIENT" = "portrait" ]; then WIDTH=$GIF_WIDTH_PORTRAIT; else WIDTH=$GIF_WIDTH_LANDSCAPE; fi
    ffmpeg -loglevel error -y -framerate "$FPS" -i "$WORK/frames/%05d.png" \
      -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
      -c:v libx264 -crf "$CRF" -preset slow -pix_fmt yuv420p -movflags +faststart -an "$OUT/$TAG.mp4"
    ffmpeg -loglevel error -y -framerate "$FPS" -i "$WORK/frames/%05d.png" \
      -vf "fps=$GIF_FPS,scale=$WIDTH:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
      "$OUT/$TAG.gif"
    # 静止画: イベントのコマと、その少し後(演出の山)
    for EV in $STILL_EVENTS; do
      NAME="${EV%%+*}"
      OFFSET=0
      [ "$NAME" = "$EV" ] || OFFSET="${EV##*+}"
      N=$(awk -v e="$NAME" '$1==e {print $2}' "$WORK/events.txt" | tr -d '\r')
      [ -n "$N" ] || continue
      FILE=$(printf '%05d.png' $(( N + OFFSET )))
      [ -f "$WORK/frames/$FILE" ] && cp "$WORK/frames/$FILE" "$OUT/stills/${TAG}_${EV/+/_plus}.png"
    done
    cp "$WORK/events.txt" "$OUT/${TAG}_events.txt"
    rm -rf "$WORK" "$OUT/_work/${TAG}_movie.avi" "$OUT/_work/${TAG}_movie.wav"
    printf '%s (mp4 %s KB / gif %s KB)\n' "$TAG" \
      "$(( $(stat -c%s "$OUT/$TAG.mp4") / 1024 ))" "$(( $(stat -c%s "$OUT/$TAG.gif") / 1024 ))"
  done
done
rmdir "$OUT/_work" 2>/dev/null || true
