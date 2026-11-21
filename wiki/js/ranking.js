// ランキング(GameDesign.md 32章)。ゲーム内のランキング(28章)と同じ上位30人を public_stats/wiki_ranking から出す。
import {el} from "./dom.js";
import {readPublicStats} from "./firestore.js";

// RankRules(scripts/logic/rank_rules.gd)の段位名と、昇段に要る★の数。
const BRACKET_NAMES = {bronze: "ブロンズ", silver: "シルバー", gold: "ゴールド"};
const BRACKET_STAR_REQUIREMENT = {bronze: 2, silver: 3, gold: 4};
const PLATINUM_KEY = "platinum";
const PLATINUM_NAME = "プラチナ";
const TIER_PATTERN = /^([a-z]+)(\d+)$/;
const MEDAL_RANKS = 3;

let profilePromise = null;

function loadProfile() {
  if (!profilePromise) profilePromise = fetch("data/profile.json").then((response) => response.json()).catch(() => ({titles: {}}));
  return profilePromise;
}

function tierParts(tier) {
  if (tier === PLATINUM_KEY) return {bracket: PLATINUM_KEY, label: PLATINUM_NAME};
  const match = TIER_PATTERN.exec(tier) || [];
  const bracket = BRACKET_NAMES[match[1]] ? match[1] : "bronze";
  return {bracket, label: `${BRACKET_NAMES[bracket]}${match[2] || 1}`};
}

function progressCell(row, bracket) {
  if (bracket === PLATINUM_KEY) return el("td", {class: "num", text: `レート ${row.rating}`});
  const need = BRACKET_STAR_REQUIREMENT[bracket];
  const filled = Math.min(row.stars, need);
  return el("td", {class: "ranking__stars", "aria-label": `★${row.stars}`}, [
    el("span", {class: "ranking__star-on", text: "★".repeat(filled)}),
    el("span", {class: "ranking__star-off", text: "★".repeat(need - filled)}),
  ]);
}

function rankCell(rank) {
  const medal = rank <= MEDAL_RANKS ? ` ranking__rank--${rank}` : "";
  return el("td", {class: "num"}, [el("span", {class: `ranking__rank${medal}`, text: String(rank)})]);
}

function rowNode(row, index, titles) {
  const {bracket, label} = tierParts(row.tier);
  const title = titles[row.title] || "";
  return el("tr", {}, [
    rankCell(index + 1),
    el("td", {}, [el("span", {class: "ranking__player"}, [
      el("img", {src: `icons/${encodeURIComponent(row.icon)}.webp`, alt: "", loading: "lazy"}),
      el("span", {}, [
        title ? el("span", {class: "ranking__title", text: title}) : "",
        el("span", {class: "ranking__name", text: row.name}),
      ]),
    ])]),
    el("td", {}, [el("span", {class: `ranking__tier ranking__tier--${bracket}`, text: label})]),
    progressCell(row, bracket),
  ]);
}

export async function renderRankingPage(root) {
  const heading = el("h1", {text: "ランキング"});
  root.replaceChildren(heading, el("p", {class: "notice", text: "読み込んでいます"}));
  let ranking;
  try {
    ranking = await readPublicStats("wiki_ranking");
  } catch (error) {
    ranking = undefined;
  }
  if (ranking === undefined) {
    root.replaceChildren(heading, el("p", {class: "notice", text: "読み込めませんでした"}));
    return;
  }
  const {titles} = await loadProfile();
  const rows = ranking?.rows || [];
  const [year, month] = (ranking?.season || "").split("-");
  const lead = el("p", {class: "lead", text: year ? `ランクマッチ ${year}年${Number(month)}月のシーズンの上位${rows.length}人` : "ランクマッチの今シーズンの上位"});
  const updated = ranking ?
    el("p", {class: "updated", text: `最終更新 ${new Date(ranking.updated_at * 1000).toLocaleString("ja-JP", {timeZone: "Asia/Tokyo"})}(毎日5時に更新)`}) : "";
  if (rows.length === 0) {
    root.replaceChildren(heading, lead, el("p", {class: "notice", text: "まだ今シーズンの対局記録がありません"}), updated);
    return;
  }
  root.replaceChildren(
    heading,
    lead,
    el("div", {class: "table-wrap"}, [el("table", {class: "ranking"}, [
      el("thead", {}, [el("tr", {}, [
        el("th", {class: "num", text: "順位"}), el("th", {text: "プレイヤー"}), el("th", {text: "段位"}), el("th", {text: ""}),
      ])]),
      el("tbody", {}, rows.map((row, index) => rowNode(row, index, titles))),
    ])]),
    updated,
  );
}
