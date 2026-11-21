/**
 * 攻略サイトのランキング(GameDesign.md 32章 / Architecture.md 10.21節)。
 * ゲーム内のランキング(CardRankScreen)と同じ並び・同じ範囲を、誰でも読める public_stats/wiki_ranking へ書き出す。
 */

// CardRankScreen.LEADERBOARD_LIMIT と同じ。
const LIMIT = 30;
const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
// CardRankScreen._row_from_fields() と同じ既定。
const NAMELESS = "(名無し)";
const DEFAULT_ICON = "sand";
const DEFAULT_TITLE = "novice";
const INITIAL_TIER = "bronze1";
const PLATINUM_START_RATING = 1000;

/** RankProgress.current_season_key() と同じ、JSTの "YYYY-MM"。 */
function currentSeasonKey(now = Date.now()) {
  const jst = new Date(now + JST_OFFSET_MS);
  return `${jst.getUTCFullYear()}-${String(jst.getUTCMonth() + 1).padStart(2, "0")}`;
}

function toRow(data) {
  return {
    name: data.display_name || NAMELESS,
    icon: data.icon_id || DEFAULT_ICON,
    title: data.title_id || DEFAULT_TITLE,
    tier: data.rank_tier || INITIAL_TIER,
    stars: Number(data.rank_stars) || 0,
    rating: data.rank_rating === undefined ? PLATINUM_START_RATING : Number(data.rank_rating),
  };
}

async function publishWikiRanking(db, updatedAt) {
  const season = currentSeasonKey();
  const snapshot = await db.collection("players")
      .where("rank_season", "==", season)
      .orderBy("rank_progress_score", "desc")
      .limit(LIMIT)
      .select("display_name", "icon_id", "title_id", "rank_tier", "rank_stars", "rank_rating")
      .get();
  const rows = snapshot.docs.map((doc) => toRow(doc.data()));
  await db.collection("public_stats").doc("wiki_ranking").set({updated_at: updatedAt, season, rows});
  return rows.length;
}

module.exports = {publishWikiRanking, currentSeasonKey, toRow};
