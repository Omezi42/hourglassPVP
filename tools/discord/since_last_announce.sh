#!/usr/bin/env bash
# 前回のお知らせ以降のコミットを並べる。お知らせの下書きを作る材料。
#   tools/discord/since_last_announce.sh          … 差分を表示
#   tools/discord/since_last_announce.sh --mark   … 現在のHEADを「告知済み」として記録
#
# 記録はリポジトリの外に置く。commitのたびに差分が出て履歴が汚れるのを避けるため。
set -euo pipefail
STATE="${HOURGLASS_ANNOUNCE_STATE:-$HOME/.hourglass_announce_state}"

if [ "${1:-}" = "--mark" ]; then
  git rev-parse HEAD > "$STATE"
  echo "告知済みとして記録しました: $(cat "$STATE")"
  exit 0
fi

if [ -f "$STATE" ] && git cat-file -e "$(cat "$STATE")^{commit}" 2>/dev/null; then
  RANGE="$(cat "$STATE")..HEAD"
else
  # 初回、または記録されたコミットが見つからない場合は直近20件を見る
  RANGE="HEAD~20..HEAD"
  echo "(記録が無いため直近20件を表示します)" >&2
fi

git log --no-merges --reverse --pretty=format:'%h  %ad  %s' --date=short "$RANGE"
