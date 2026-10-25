// みんなの統計(GameDesign.md 32章)。public_stats/ の集計を版と対局の種別で絞って出す。
import {el} from "./dom.js";
import {loadCards, openCardDialog, thumbUrl} from "./cards.js";
import {readPublicStats} from "./firestore.js";

// これより少ない局数の勝率は数字を出さない(GameDesign.md 32章)。
const MIN_GAMES = 20;
const ALL_BUILDS = "all";
const END_REASONS = [
  ["hp", "HP", "#d9a441"],
  ["surrender", "投了", "#8a6a4a"],
  ["timeout", "時間切れ", "#6d7a8c"],
  ["draw", "引き分け", "#b9b0a0"],
];
const SORT_KEYS = {
  name: (row) => row.card.pool_index,
  pick: (row) => row.pick,
  games: (row) => row.g,
  rate: (row) => (row.g >= MIN_GAMES ? row.rate : -1),
};

// build_id は書き出した時刻(UTC)の "YYYYMMDD-HHMMSS"。
function buildLabel(build) {
  const match = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})$/.exec(build);
  if (!match) return build;
  const [, y, mo, d, h, mi, s] = match;
  const date = new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +s));
  return date.toLocaleString("ja-JP", {timeZone: "Asia/Tokyo", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit"});
}

function percent(numerator, denominator) {
  return denominator > 0 ? `${(numerator / denominator * 100).toFixed(1)}%` : "—";
}

function mergeKinds(doc, kinds) {
  const merged = {games: 0, decided: 0, first_wins: 0, turns: 0, end: {}, cards: {}};
  for (const kind of kinds) {
    const stats = doc?.kinds?.[kind];
    if (!stats) continue;
    for (const key of ["games", "decided", "first_wins", "turns"]) merged[key] += stats[key] || 0;
    for (const [reason, count] of Object.entries(stats.end || {})) merged.end[reason] = (merged.end[reason] || 0) + count;
    for (const [id, entry] of Object.entries(stats.cards || {})) {
      const target = merged.cards[id] || (merged.cards[id] = {g: 0, w: 0});
      target.g += entry.g || 0;
      target.w += entry.w || 0;
    }
  }
  return merged;
}

function tileNode(label, value, sub) {
  return el("div", {class: "tile"}, [
    el("div", {class: "tile__label", text: label}),
    el("div", {class: "tile__value", text: value}),
    el("div", {class: "tile__sub", text: sub}),
  ]);
}

function endsNode(stats) {
  const bar = el("div", {class: "ends", role: "img"});
  const legend = el("div", {class: "ends-legend"});
  const parts = [];
  for (const [key, label, color] of END_REASONS) {
    const count = stats.end[key] || 0;
    if (!count) continue;
    bar.append(el("span", {style: `width:${count / stats.games * 100}%;background:${color}`}));
    const item = el("span", {text: `${label} ${percent(count, stats.games)}`});
    item.prepend(el("i", {style: `background:${color}`}));
    legend.append(item);
    parts.push(`${label} ${count}局`);
  }
  bar.setAttribute("aria-label", parts.join("、"));
  return el("div", {class: "tile"}, [el("div", {class: "tile__label", text: "決着の要因"}), bar, legend]);
}

function rateNode(row) {
  if (row.g < MIN_GAMES) return el("span", {text: "—"});
  const color = row.rate >= 0.5 ? "var(--win)" : "var(--lose)";
  const bar = el("span", {class: "rate__bar"}, [el("span", {style: `width:${row.rate * 100}%;background:${color}`})]);
  return el("span", {class: "rate"}, [bar, el("span", {text: `${(row.rate * 100).toFixed(1)}%`})]);
}

function cardTable(stats, cards, sort, onSort) {
  const sides = stats.games * 2;
  const rows = cards.map((card) => {
    const entry = stats.cards[card.id] || {g: 0, w: 0};
    return {card, g: entry.g, pick: sides ? entry.g / sides : 0, rate: entry.g ? entry.w / entry.g : 0};
  });
  const key = SORT_KEYS[sort.key];
  // 同じ値どうしは採用の多い順に並べる(勝率を出せないカードが並び順を失わないため)。
  rows.sort((a, b) => (sort.ascending ? key(a) - key(b) : key(b) - key(a)) || b.g - a.g || a.card.pool_index - b.card.pool_index);

  const header = (sortKey, label, numeric) => {
    const button = el("button", {type: "button", text: label});
    if (sort.key === sortKey) button.setAttribute("aria-sort", sort.ascending ? "ascending" : "descending");
    button.addEventListener("click", () => onSort(sortKey));
    return el("th", numeric ? {class: "num"} : {}, [button]);
  };
  const body = el("tbody", {}, rows.map((row) => {
    const name = el("button", {type: "button", text: row.card.display_name});
    name.addEventListener("click", () => openCardDialog(row.card));
    return el("tr", row.g < MIN_GAMES ? {class: "few"} : {}, [
      el("td", {}, [el("span", {class: "name-cell"}, [el("img", {src: thumbUrl(row.card), alt: "", loading: "lazy"}), name])]),
      el("td", {class: "num", text: percent(row.g, sides)}),
      el("td", {class: "num", text: String(row.g)}),
      el("td", {class: "num"}, [rateNode(row)]),
    ]);
  }));
  return el("div", {class: "table-wrap"}, [el("table", {}, [
    el("thead", {}, [el("tr", {}, [
      header("name", "カード", false),
      header("pick", "採用率", true),
      header("games", "採用した局", true),
      header("rate", "入れたデッキの勝率", true),
    ])]),
    body,
  ])]);
}

export async function renderStatsPage(root) {
  root.replaceChildren(el("p", {class: "notice", text: "集計を読み込んでいます…"}));
  let index;
  try {
    index = await readPublicStats("wiki_index");
  } catch (error) {
    root.replaceChildren(el("p", {class: "notice", text: "集計を読み込めませんでした。時間をおいて開き直してください。"}));
    return;
  }
  if (!index || !index.builds?.length) {
    root.replaceChildren(el("p", {class: "notice", text: "まだ集計がありません。"}));
    return;
  }
  const cards = await loadCards();
  const state = {build: index.builds[0].build, includeRoom: false, sort: {key: "rate", ascending: false}};

  const select = el("select", {"aria-label": "版"});
  select.append(el("option", {value: ALL_BUILDS, text: `全期間(${index.games}局)`}));
  index.builds.forEach((entry, i) => {
    const label = `${i === 0 ? "最新の版 " : ""}${buildLabel(entry.build)}(${entry.games}局)`;
    select.append(el("option", {value: entry.build, text: label}));
  });
  select.value = state.build;
  const segmented = el("div", {class: "segmented", role: "group", "aria-label": "対局の種別"});
  const kindButtons = [[false, "ランクマッチだけ"], [true, "ルームマッチも含める"]].map(([value, label]) => {
    const button = el("button", {type: "button", text: label});
    button.addEventListener("click", () => { state.includeRoom = value; render(); });
    segmented.append(button);
    return [value, button];
  });
  const body = el("div");

  async function render() {
    for (const [value, button] of kindButtons) button.setAttribute("aria-pressed", value === state.includeRoom);
    const docId = state.build === ALL_BUILDS ? "wiki_all" : `wiki_b${state.build}`;
    const doc = await readPublicStats(docId);
    const stats = mergeKinds(doc, state.includeRoom ? ["ranked", "room"] : ["ranked"]);
    if (!stats.games) {
      body.replaceChildren(el("p", {class: "notice", text: "この条件の対局はまだありません。"}));
      return;
    }
    const onSort = (key) => {
      state.sort = state.sort.key === key ? {key, ascending: !state.sort.ascending} : {key, ascending: key === "name"};
      render();
    };
    body.replaceChildren(
      el("div", {class: "tiles"}, [
        tileNode("対局数", String(stats.games), state.includeRoom ? "ランクマッチ・ルームマッチ" : "ランクマッチ"),
        tileNode("先手の勝率", percent(stats.first_wins, stats.decided), "引き分けを除く"),
        tileNode("平均手数", (stats.turns / stats.games).toFixed(1), "1局あたりのターン数"),
        endsNode(stats),
      ]),
      el("p", {class: "caveat", text: `「入れたデッキの勝率」は、そのカードを入れたデッキで戦った勝率です。カードの強さそのものではありません。採用した局が${MIN_GAMES}未満のカードは勝率を出していません。`}),
      cardTable(stats, cards, state.sort, onSort),
    );
  }

  select.addEventListener("change", () => { state.build = select.value; render(); });
  root.replaceChildren(
    el("h1", {text: "みんなの統計"}),
    el("p", {class: "lead", text: "人どうしのオンライン対戦から集めた数字です。CPU戦は含みません。"}),
    el("div", {class: "toolbar"}, [select, segmented]),
    body,
    el("p", {class: "updated", text: `最終更新 ${new Date(index.updated_at * 1000).toLocaleString("ja-JP", {timeZone: "Asia/Tokyo"})}(毎日5時に更新)`}),
  );
  await render();
}
