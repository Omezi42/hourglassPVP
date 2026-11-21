// リプレイ(GameDesign.md 32章 / Architecture.md 10.21節)。自分の対局(#replay/{match_id})と共有リンク(/r/{id})。
// 再生はゲーム本体(アプリ版の起動部)を iframe で開き、記録を postMessage で渡す。サイトで再生の仕組みを作り直さない。
import {el} from "./dom.js";
import {currentUser, idToken} from "./auth.js";
import {authedBatchGet, authedDoc} from "./firestore.js";
import {goToLogin} from "./login.js";
import {KIND_LABELS} from "./mypage_stats.js";

// Cloudflare Pages は1ファイル25MiBまでで wasm が載らないため、ゲームはアプリ版(GitHub Pages)の起動部で動かす。
const APP_URL = "https://omezi42.github.io/sunadokei-arena-app/";
const APP_ORIGIN = new URL(APP_URL).origin;
// 版ごとの pck の一覧(Architecture.md 4.6節)。
const BUILDS_URL = "https://sunadokei-arena.pages.dev/builds.json";
const SHARE_URL = "https://us-central1-hourglasspvp.cloudfunctions.net/wikiReplayShare";
const COPIED_MS = 1500;
const DEFAULT_NAME = "ゲスト";
const DEFAULT_ICON = "sand";
const DEFAULT_TITLE = "novice";
const RESULT_LABELS = {win: "勝ち", lose: "負け", draw: "引き分け"};

export const REPLAY_PATH = /^\/r\/([A-Za-z0-9]{10})$/;
export const REPLAY_HASH = /^replay\/([A-Za-z0-9_-]+)$/;

let buildsPromise = null;

function replayableBuilds() {
  if (!buildsPromise) {
    buildsPromise = fetch(BUILDS_URL, {cache: "no-store"})
      .then((response) => (response.ok ? response.json() : {builds: {}}))
      .catch(() => ({builds: {}}));
  }
  return buildsPromise;
}

function dateLabel(seconds) {
  return new Date(seconds * 1000).toLocaleString("ja-JP", {
    timeZone: "Asia/Tokyo", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
  });
}

function resultOf(record, side) {
  if (record.end_reason === "draw") return RESULT_LABELS.draw;
  return record.winner === side ? RESULT_LABELS.win : RESULT_LABELS.lose;
}

/** ゲームへ渡す形(scripts/net/replay_launch.gd)。 */
function gameRecord(record, view, players) {
  return {deck_a: record.deck_a, deck_b: record.deck_b, seed: record.seed, actions: record.actions, view, players};
}

/** ゲームを iframe で開き、準備ができたと言ってきたら記録を渡す。 */
async function player(build, record) {
  const builds = await replayableBuilds();
  if (!builds.builds?.[build]) return el("p", {class: "notice", text: "この版の対局は再生できません"});
  const frame = el("iframe", {
    class: "replay-player__frame",
    src: `${APP_URL}?replay=1&build=${encodeURIComponent(build)}`,
    title: "リプレイ",
    allow: "fullscreen; autoplay",
  });
  const onMessage = (event) => {
    if (!frame.isConnected) {
      window.removeEventListener("message", onMessage);
      return;
    }
    if (event.origin !== APP_ORIGIN || event.source !== frame.contentWindow) return;
    if (event.data?.type !== "hourglass-replay-ready") return;
    frame.contentWindow.postMessage({type: "hourglass-replay", record}, APP_ORIGIN);
  };
  window.addEventListener("message", onMessage);
  const fullscreen = el("button", {class: "action action--quiet", type: "button", text: "全画面で見る"});
  fullscreen.addEventListener("click", () => frame.requestFullscreen?.());
  return el("div", {class: "replay-player"}, [el("div", {class: "replay-player__screen"}, [frame]), fullscreen]);
}

function notFound(root) {
  root.replaceChildren(el("h1", {text: "リプレイ"}), el("p", {class: "notice", text: "見つかりませんでした"}));
}

async function profiles(uids) {
  const found = await authedBatchGet("players", uids.filter(Boolean), ["display_name", "icon_id", "title_id"]) || {};
  return Object.fromEntries(uids.map((uid) => {
    const fields = found[uid] || {};
    return [uid, {name: fields.display_name || DEFAULT_NAME, icon: fields.icon_id || DEFAULT_ICON, title: fields.title_id || DEFAULT_TITLE}];
  }));
}

async function callShare(action, matchId) {
  const token = await idToken();
  if (!token) return {message: "ログインが切れました。もう一度ログインしてください"};
  const response = await fetch(SHARE_URL, {
    method: "POST",
    headers: {"Authorization": `Bearer ${token}`, "Content-Type": "application/json"},
    body: JSON.stringify({action, match_id: matchId}),
  }).catch(() => null);
  if (!response) return {message: "通信に失敗しました。接続を確認してください"};
  const body = await response.json().catch(() => ({}));
  return response.ok ? body : {message: body.message || "共有できませんでした"};
}

/** 「共有リンクをコピー」と「共有を取り消す」。同じ対局には同じリンクを返す(GameDesign.md 32章)。 */
function shareControls(matchId) {
  const copy = el("button", {class: "action", type: "button", text: "共有リンクをコピー"});
  const revoke = el("button", {class: "action action--quiet", type: "button", text: "共有を取り消す", hidden: ""});
  const note = el("span", {class: "action-note", text: "リンクを知っている人は、ログインせずに再生できます。相手の名前は「対戦相手」になります"});
  const setShared = (id) => {
    revoke.hidden = !id;
  };
  callShare("status", matchId).then((body) => setShared(body.id || ""));
  copy.addEventListener("click", async () => {
    copy.disabled = true;
    const body = await callShare("share", matchId);
    copy.disabled = false;
    if (!body.id) {
      note.textContent = body.message || "共有できませんでした";
      return;
    }
    setShared(body.id);
    await navigator.clipboard.writeText(`${location.origin}/r/${body.id}`);
    copy.textContent = "コピーしました";
    setTimeout(() => { copy.textContent = "共有リンクをコピー"; }, COPIED_MS);
  });
  revoke.addEventListener("click", async () => {
    revoke.disabled = true;
    const body = await callShare("revoke", matchId);
    revoke.disabled = false;
    if (body.message) {
      note.textContent = body.message;
      return;
    }
    setShared("");
    note.textContent = "共有を取り消しました。リンクは「見つかりませんでした」になります";
  });
  return el("div", {class: "deck-code"}, [copy, revoke, note]);
}

/** 自分の対局(マイページの一覧から開く)。 */
export async function renderReplayPage(root, matchId) {
  const user = currentUser();
  if (!user) {
    goToLogin();
    return;
  }
  root.replaceChildren(el("h1", {text: "リプレイ"}), el("p", {class: "notice", text: "読み込んでいます"}));
  const record = await authedDoc(`match_records/${matchId}`);
  if (record === null) {
    root.replaceChildren(el("h1", {text: "リプレイ"}), el("p", {class: "notice", text: "読み込めませんでした"}));
    return;
  }
  const view = record.player_a === user.uid ? "a" : (record.player_b === user.uid ? "b" : "");
  if (!view) {
    notFound(root);
    return;
  }
  const foe = view === "a" ? "b" : "a";
  const names = await profiles([record.player_a, record.player_b]);
  const players = {a: names[record.player_a], b: names[record.player_b]};
  const lead = [
    dateLabel(Number(record.finished_at) || 0),
    KIND_LABELS[record.kind] || record.kind,
    view === "a" ? "先手" : "後手",
    `相手 ${players[foe].name}`,
    resultOf(record, view),
    `${record.turns}手`,
  ].join("・");
  root.replaceChildren(
    el("h1", {text: "リプレイ"}),
    el("p", {class: "lead", text: lead}),
    shareControls(matchId),
    await player(record.build, gameRecord(record, view, players)),
  );
}

/** 共有リンク /r/{id}。ログインせずに再生できる。 */
export async function renderSharedReplayPage(root, shareId) {
  root.replaceChildren(el("h1", {text: "リプレイ"}), el("p", {class: "notice", text: "読み込んでいます"}));
  const response = await fetch(`/r/${shareId}.json`, {cache: "no-store"}).catch(() => null);
  if (!response || !response.ok) {
    notFound(root);
    return;
  }
  const replay = await response.json();
  const sharer = replay.players[replay.view];
  const lead = [dateLabel(replay.finished_at), resultOf(replay, replay.view), `${replay.turns}手`].join("・");
  root.replaceChildren(
    el("h1", {text: `${sharer.name}の対局`}),
    el("p", {class: "lead", text: lead}),
    await player(replay.build, gameRecord(replay, replay.view, replay.players)),
  );
}
