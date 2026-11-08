// マイページの分析(GameDesign.md 32章)。自分の対局の記録(match_records)から数える。DOMは触らない。
// 記録の a は先手(Architecture.md 10.9節)。winner は引き分けでも "b" になるため end_reason で見分ける。
export const END_REASONS = ["hp", "surrender", "timeout", "draw"];
export const RECORD_FIELDS = ["kind", "finished_at", "winner", "end_reason", "turns", "deck_a", "deck_b", "player_a", "player_b"];
// 記録の種別キー(ランクマッチは "random"。Architecture.md 10.9節)。
export const KIND_LABELS = {random: "ランク", room: "ルーム"};

/** 1件の記録を、自分の側から見た形にする。 */
export function toMyGame(record, uid) {
  const first = record.player_a === uid;
  const mySide = first ? "a" : "b";
  const draw = record.end_reason === "draw";
  return {
    id: record.id,
    kind: record.kind,
    finishedAt: Number(record.finished_at) || 0,
    first,
    result: draw ? "draw" : (record.winner === mySide ? "win" : "lose"),
    endReason: END_REASONS.includes(record.end_reason) ? record.end_reason : "hp",
    turns: Number(record.turns) || 0,
    myDeck: (first ? record.deck_a : record.deck_b) || [],
    opponentDeck: (first ? record.deck_b : record.deck_a) || [],
    opponentUid: (first ? record.player_b : record.player_a) || "",
  };
}

function emptyTally() {
  return {games: 0, decided: 0, wins: 0};
}

function addTo(tally, game) {
  tally.games += 1;
  if (game.result === "draw") return;
  tally.decided += 1;
  if (game.result === "win") tally.wins += 1;
}

/** 同じ30枚のデッキを同じものとして数えるための鍵(並びを無視する)。 */
export function deckKey(ids) {
  return ids.map(String).sort().join(",");
}

// 期間は日本時間の月で区切る(ランクマッチのシーズンと同じ単位)。
function monthKey(seconds) {
  const date = new Date(seconds * 1000 + 9 * 60 * 60 * 1000);
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

function grouped(games, keyOf) {
  const groups = new Map();
  for (const game of games) {
    for (const key of keyOf(game)) {
      if (!groups.has(key)) groups.set(key, {key, ...emptyTally(), sample: game});
      addTo(groups.get(key), game);
    }
  }
  return [...groups.values()];
}

export function analyze(games) {
  const total = emptyTally();
  const first = emptyTally();
  const second = emptyTally();
  const end = Object.fromEntries(END_REASONS.map((reason) => [reason, {win: 0, lose: 0, draw: 0}]));
  for (const game of games) {
    addTo(total, game);
    addTo(game.first ? first : second, game);
    end[game.endReason][game.result] += 1;
  }
  const byGames = (a, b) => b.games - a.games || b.wins - a.wins;
  return {
    total,
    first,
    second,
    end,
    decks: grouped(games, (game) => (game.myDeck.length ? [deckKey(game.myDeck)] : [])).sort(byGames),
    // 相手のデッキの同じカードの重複は1回として数える(みんなの統計と同じ数え方)。
    opponentCards: grouped(games, (game) => new Set(game.opponentDeck.map(String))).sort(byGames),
    months: grouped(games, (game) => [monthKey(game.finishedAt)]).sort((a, b) => b.key.localeCompare(a.key)),
  };
}

/** CPU戦の通算(players/{uid}.stats_kinds の CurrencyRules.MatchKind.CPU)。 */
export const CPU_KIND_KEY = "3";
