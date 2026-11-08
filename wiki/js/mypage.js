// マイページ(GameDesign.md 32章 / Architecture.md 10.21節)。自分のオンライン対戦の全件とその分析。
import {el} from "./dom.js";
import {currentUser} from "./auth.js";
import {loadCards, openCardDialog, thumbUrl, compareByCost} from "./cards.js";
import {authedBatchGet, authedDoc, authedQuery} from "./firestore.js";
import {goToLogin} from "./login.js";
import {percent, tileNode} from "./stats.js";
import {CPU_KIND_KEY, KIND_LABELS, RECORD_FIELDS, analyze, deckKey, toMyGame} from "./mypage_stats.js";

const DEFAULT_NAME = "ゲスト";
const DEFAULT_DECK_NAME = "デッキ";
// 一覧に無いデッキは、コストの高い順にこの枚数のカード名で呼ぶ。
const DECK_HINT_CARDS = 3;
// batchGet へ一度に渡す文書の数。
const NAME_BATCH = 100;
const RESULT_LABELS = {win: "勝ち", lose: "負け", draw: "引き分け"};
const END_LABELS = {hp: "HP", surrender: "投了", timeout: "時間切れ", draw: "引き分け"};

async function myRecords(uid) {
  const select = {fields: RECORD_FIELDS.map((fieldPath) => ({fieldPath}))};
  const query = (side) => authedQuery({
    select,
    from: [{collectionId: "match_records"}],
    where: {fieldFilter: {field: {fieldPath: side}, op: "EQUAL", value: {stringValue: uid}}},
  });
  const [asFirst, asSecond] = await Promise.all([query("player_a"), query("player_b")]);
  if (asFirst === null || asSecond === null) return null;
  return [...asFirst, ...asSecond];
}

async function displayNames(uids) {
  const names = {};
  for (let i = 0; i < uids.length; i += NAME_BATCH) {
    const found = await authedBatchGet("players", uids.slice(i, i + NAME_BATCH), ["display_name"]);
    for (const [uid, fields] of Object.entries(found || {})) names[uid] = fields.display_name;
  }
  return names;
}

function dateLabel(seconds) {
  return new Date(seconds * 1000).toLocaleString("ja-JP", {
    timeZone: "Asia/Tokyo", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
  });
}

function rateCell(tally) {
  if (!tally.decided) return el("td", {class: "num", text: "—"});
  const rate = tally.wins / tally.decided;
  const color = rate >= 0.5 ? "var(--win)" : "var(--lose)";
  const bar = el("span", {class: "rate__bar"}, [el("span", {style: `width:${rate * 100}%;background:${color}`})]);
  return el("td", {class: "num"}, [el("span", {class: "rate"}, [bar, el("span", {text: percent(tally.wins, tally.decided)})])]);
}

function recordText(tally) {
  return `${tally.wins}勝 ${tally.decided - tally.wins}敗${tally.games > tally.decided ? ` ${tally.games - tally.decided}分` : ""}`;
}

function table(headers, rows) {
  return el("div", {class: "table-wrap"}, [el("table", {}, [
    el("thead", {}, [el("tr", {}, headers.map(([label, numeric]) => el("th", numeric ? {class: "num", text: label} : {text: label})))]),
    el("tbody", {}, rows),
  ])]);
}

function section(title, ...children) {
  return el("section", {class: "mypage-section"}, [el("h2", {text: title}), ...children]);
}

function cardCell(card) {
  const name = el("button", {type: "button", text: card.display_name});
  name.addEventListener("click", () => openCardDialog(card));
  return el("td", {}, [el("span", {class: "name-cell"}, [el("img", {src: thumbUrl(card), alt: "", loading: "lazy"}), name])]);
}

function deckLabel(ids, namesByKey, cardsById) {
  const name = namesByKey.get(deckKey(ids));
  if (name) return name;
  const hint = [...new Set(ids.map(String))]
    .map((id) => cardsById.get(id))
    .filter(Boolean)
    .sort((a, b) => compareByCost(b, a))
    .slice(0, DECK_HINT_CARDS)
    .map((card) => card.display_name);
  return `一覧に無いデッキ(${hint.join("・")}など)`;
}

function summaryTiles(result, cpu) {
  return el("div", {class: "tiles"}, [
    tileNode("通算の勝率", percent(result.total.wins, result.total.decided), `${result.total.games}局 ${recordText(result.total)}`),
    tileNode("先手の勝率", percent(result.first.wins, result.first.decided), `${result.first.games}局`),
    tileNode("後手の勝率", percent(result.second.wins, result.second.decided), `${result.second.games}局`),
    tileNode("CPU戦の通算", percent(cpu.wins || 0, cpu.games || 0), `${cpu.games || 0}局 ${cpu.wins || 0}勝`),
  ]);
}

function endTable(end) {
  const rows = Object.entries(end)
    .filter(([, counts]) => counts.win + counts.lose + counts.draw > 0)
    .map(([reason, counts]) => el("tr", {}, [
      el("td", {text: END_LABELS[reason]}),
      el("td", {class: "num", text: String(reason === "draw" ? counts.draw : counts.win)}),
      el("td", {class: "num", text: reason === "draw" ? "" : String(counts.lose)}),
    ]));
  return table([["決着", false], ["勝ち", true], ["負け", true]], rows);
}

function tallyRows(groups, labelCell) {
  return groups.map((group) => el("tr", {}, [labelCell(group), el("td", {class: "num", text: String(group.games)}), rateCell(group)]));
}

function gameList(games, names) {
  const rows = games.map((game) => el("tr", {class: `result-${game.result}`}, [
    el("td", {text: dateLabel(game.finishedAt)}),
    el("td", {text: KIND_LABELS[game.kind] || game.kind}),
    el("td", {text: game.first ? "先手" : "後手"}),
    el("td", {text: names[game.opponentUid] || DEFAULT_NAME}),
    el("td", {class: "result", text: RESULT_LABELS[game.result]}),
    el("td", {class: "num", text: String(game.turns)}),
  ]));
  return table([["日時", false], ["種別", false], ["先後", false], ["相手", false], ["勝敗", false], ["手数", true]], rows);
}

export async function renderMypagePage(root) {
  const user = currentUser();
  if (!user) {
    goToLogin();
    return;
  }
  const heading = el("h1", {text: "マイページ"});
  const lead = el("p", {class: "lead", text: "自分が指したオンライン対戦(ランクマッチ・ルームマッチ)の全件です。CPU戦は通算だけを出します。"});
  root.replaceChildren(heading, lead, el("p", {class: "notice", text: "読み込んでいます"}));
  const [records, player, cards] = await Promise.all([myRecords(user.uid), authedDoc(`players/${user.uid}`), loadCards()]);
  if (records === null || player === null) {
    root.replaceChildren(heading, lead, el("p", {class: "notice", text: "読み込めませんでした"}));
    return;
  }
  const cpu = player.stats_kinds?.[CPU_KIND_KEY] || {};
  const games = records.map((record) => toMyGame(record, user.uid)).sort((a, b) => b.finishedAt - a.finishedAt);
  if (games.length === 0) {
    root.replaceChildren(heading, lead, summaryTiles(analyze([]), cpu), el("p", {class: "notice", text: "オンライン対戦の記録はまだありません"}));
    return;
  }
  const result = analyze(games);
  const names = await displayNames([...new Set(games.map((game) => game.opponentUid).filter(Boolean))]);
  const cardsById = new Map(cards.map((card) => [card.id, card]));
  const namesByKey = new Map((player.decks || []).map((deck) => [deckKey(deck.ids || []), deck.name || DEFAULT_DECK_NAME]));
  const opponentCards = result.opponentCards.filter((group) => cardsById.has(group.key));

  root.replaceChildren(
    heading,
    lead,
    summaryTiles(result, cpu),
    section("決着の要因", endTable(result.end)),
    section("月ごとの勝率", table([["月", false], ["対局", true], ["勝率", true]],
      tallyRows(result.months, (group) => el("td", {text: `${group.key.slice(0, 4)}年${Number(group.key.slice(5))}月`})))),
    section("自分のデッキ別の勝率", table([["デッキ", false], ["対局", true], ["勝率", true]],
      tallyRows(result.decks, (group) => el("td", {text: deckLabel(group.sample.myDeck, namesByKey, cardsById)})))),
    section("相手が入れていたカード別の勝率",
      el("p", {class: "caveat", text: "そのカードを入れた相手と戦ったときの、自分の勝率です。"}),
      table([["カード", false], ["対局", true], ["勝率", true]],
        tallyRows(opponentCards, (group) => cardCell(cardsById.get(group.key))))),
    section(`対局の一覧(${games.length}局)`, gameList(games, names)),
  );
}
