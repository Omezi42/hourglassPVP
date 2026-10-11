#!/usr/bin/env bash
# カード1枚ごとの勝率(BalanceReport_v5.md 2章)を並列で測り、1つのCSVへまとめて目標外の一覧を出す。
# 長くかかるため裏で回す前提: nohup bash tools/balance/run_card_batch.sh > tools/balance/out/batch.log 2>&1 &
#
#   bash tools/balance/run_card_batch.sh [tag=all] [jobs=8] [ids=all] [games=800] [seed=42] [low=44] [high=56]
#   bash tools/balance/run_card_batch.sh report <csv> [low=44] [high=56]   # 一覧だけ出し直す
#
# 出力: tools/balance/out/card_batch_<tag>.csv(途中経過は card_batch_<tag>/shard_K.csv。再実行すると続きから測る)
# low/high: 目標の帯。整数の総量の分解能が±6pt(BalanceReport_v5.md 5.3節)のため 50±6。
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

report() {
  local csv="$1" low="$2" high="$3"
  echo "== 目標外(${low}〜${high}% の外): $csv"
  awk -F, -v low="$low" -v high="$high" 'NR > 1 && ($10 < low || $10 > high) {
      printf "  %-6s %-12s %-10s コスト%s 総量%s  %s%%\n", ($10 < low ? "弱い" : "強い"), $1, $2, $6, $7, $10 }' "$csv"
  awk -F, 'NR > 1 { n++; sum += $10 } END { if (n) printf "== %d枚・平均 %.1f%%\n", n, sum / n }' "$csv"
}

if [ "${1:-}" = "report" ]; then
  csv="$2"; shift 2
  low=44; high=56
  for arg in "$@"; do case "$arg" in low=*) low="${arg#low=}" ;; high=*) high="${arg#high=}" ;; esac; done
  report "$csv" "$low" "$high"
  exit 0
fi

tag=all; jobs=8; ids=all; games=800; seed=42; low=44; high=56
for arg in "$@"; do
  case "$arg" in
    tag=*) tag="${arg#tag=}" ;; jobs=*) jobs="${arg#jobs=}" ;; ids=*) ids="${arg#ids=}" ;;
    games=*) games="${arg#games=}" ;; seed=*) seed="${arg#seed=}" ;;
    low=*) low="${arg#low=}" ;; high=*) high="${arg#high=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

OUT_DIR="$ROOT/tools/balance/out/card_batch_$tag"
mkdir -p "$OUT_DIR"
echo "== ${games}戦ずつ・seed ${seed}・${jobs}並列・対象 ${ids} → $OUT_DIR"
for ((k = 0; k < jobs; k++)); do
  "$GODOT" --headless --path . --script res://tools/balance/run_card_batch.gd -- \
    out="$OUT_DIR/shard_$k.csv" ids="$ids" games="$games" seed="$seed" shard="$k/$jobs" \
    > "$OUT_DIR/shard_$k.log" 2>&1 &
done
wait

MERGED="$ROOT/tools/balance/out/card_batch_$tag.csv"
{
  head -n 1 "$OUT_DIR/shard_0.csv"
  for f in "$OUT_DIR"/shard_*.csv; do tail -n +2 "$f"; done | sort -t, -k3,3 -k5,5n
} > "$MERGED"
echo "== $(($(wc -l < "$MERGED") - 1))枚を書き出した: $MERGED"
grep -h "SCRIPT ERROR\|Parse Error\|unknown card id" "$OUT_DIR"/shard_*.log | head -5
report "$MERGED" "$low" "$high"
