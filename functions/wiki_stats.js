/**
 * 攻略サイトの「みんなの統計」に出す集計を作る(GameDesign.md 32章 / Architecture.md 10.21節)。
 * match_records を全件読み直し、誰でも読める public_stats/ へ書き出す。
 */

const RECORD_FIELDS = ["build", "version", "kind", "winner", "end_reason", "turns", "deck_a", "deck_b"];
const END_REASONS = ["hp", "surrender", "timeout", "draw"];
const KINDS = ["ranked", "room"];
// 記録はランクマッチ(と統合前のランダムマッチ)を "random" で持つ(Architecture.md 10.9節)。
const KIND_ALIASES = {random: "ranked"};
const BATCH_LIMIT = 400;

function emptyKind() {
  const end = {};
  for (const reason of END_REASONS) end[reason] = 0;
  return {games: 0, decided: 0, first_wins: 0, turns: 0, end, cards: {}};
}

function emptyBucket() {
  const kinds = {};
  for (const kind of KINDS) kinds[kind] = emptyKind();
  return {kinds};
}

// MatchRecordService._count_deck() と同じく、同じカードの重複は1回として数える。
function countDeck(cards, ids, won) {
  for (const id of new Set((ids || []).map(String))) {
    if (!id) continue;
    const entry = cards[id] || (cards[id] = {g: 0, w: 0});
    entry.g += 1;
    if (won) entry.w += 1;
  }
}

function addRecord(bucket, record) {
  const kindKey = KIND_ALIASES[record.kind] || record.kind;
  const stats = bucket.kinds[kindKey];
  if (!stats) return;
  const reason = END_REASONS.includes(record.end_reason) ? record.end_reason : "hp";
  // 記録の winner は引き分けでも "b" になるため、end_reason で見分ける。
  const decided = reason !== "draw";
  stats.games += 1;
  stats.turns += Number(record.turns) || 0;
  stats.end[reason] += 1;
  if (decided) {
    stats.decided += 1;
    if (record.winner === "a") stats.first_wins += 1;
  }
  countDeck(stats.cards, record.deck_a, decided && record.winner === "a");
  countDeck(stats.cards, record.deck_b, decided && record.winner === "b");
}

function aggregate(records) {
  const all = emptyBucket();
  const builds = new Map();
  for (const record of records) {
    if (!record.build) continue;
    addRecord(all, record);
    if (!builds.has(record.build)) {
      builds.set(record.build, {version: record.version || "", games: 0, bucket: emptyBucket()});
    }
    const entry = builds.get(record.build);
    entry.games += 1;
    addRecord(entry.bucket, record);
  }
  return {all, builds};
}

async function publishWikiStats(db) {
  const snapshot = await db.collection("match_records").select(...RECORD_FIELDS).get();
  const {all, builds} = aggregate(snapshot.docs.map((doc) => doc.data()));
  const updatedAt = Date.now() / 1000;
  const index = {
    updated_at: updatedAt,
    games: snapshot.size,
    builds: [...builds.entries()]
        .map(([build, entry]) => ({build, version: entry.version, games: entry.games}))
        .sort((a, b) => b.build.localeCompare(a.build)),
  };

  const writes = [["wiki_all", {...all, updated_at: updatedAt}]];
  for (const [build, entry] of builds) {
    writes.push([`wiki_b${build}`, {...entry.bucket, updated_at: updatedAt}]);
  }
  for (let i = 0; i < writes.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const [id, data] of writes.slice(i, i + BATCH_LIMIT)) {
      batch.set(db.collection("public_stats").doc(id), data);
    }
    await batch.commit();
  }
  // 版ごとの文書を書き終えてから一覧を差し替え、サイトが存在しない版を引かないようにする。
  await db.collection("public_stats").doc("wiki_index").set(index);
  return index;
}

module.exports = {publishWikiStats, aggregate};
