import {el} from "./dom.js";
import {currentUser, idToken} from "./auth.js";
import {authedDoc, authedQuery} from "./firestore.js";
import {goToLogin} from "./login.js";

// デッキを紹介する(GameDesign.md 32章 / Architecture.md 10.21節)。送るのは Cloud Functions の wikiDeckIntro。
const INTRO_URL = "https://us-central1-hourglasspvp.cloudfunctions.net/wikiDeckIntro";
const DECK_SIZE = 30;
const COMMENT_MAX_LENGTH = 200;
const DEFAULT_DECK_NAME = "デッキ";
const NOT_LINKED = "Discordの #デッキを紹介する で「アカウント連携」を押すと紹介できます";

async function isLinked(uid) {
  const found = await authedQuery({
    from: [{collectionId: "discord_links"}],
    where: {fieldFilter: {field: {fieldPath: "uid"}, op: "EQUAL", value: {stringValue: uid}}},
    limit: 1,
  });
  return found === null ? null : found.length > 0;
}

/** 30枚そろったデッキを、ゲームのデッキ一覧の添字つきで返す。 */
function completeDecks(player) {
  return (player.decks || [])
    .map((deck, index) => ({index, name: deck.name || DEFAULT_DECK_NAME, ids: deck.ids || []}))
    .filter((deck) => deck.ids.length === DECK_SIZE);
}

async function send(index, comment) {
  const token = await idToken();
  if (!token) return "ログインが切れました。もう一度ログインしてください";
  const response = await fetch(INTRO_URL, {
    method: "POST",
    headers: {"Authorization": `Bearer ${token}`, "Content-Type": "application/json"},
    body: JSON.stringify({index, comment}),
  }).catch(() => null);
  if (!response) return "通信に失敗しました。接続を確認してください";
  const body = await response.json().catch(() => ({}));
  return body.message || "紹介できませんでした";
}

function introForm(decks) {
  const select = el("select", {name: "deck", required: ""},
    decks.map((deck) => el("option", {value: String(deck.index), text: deck.name})));
  const comment = el("textarea", {name: "comment", rows: "4", maxlength: String(COMMENT_MAX_LENGTH)});
  const submit = el("button", {class: "action", type: "submit", text: "紹介する"});
  const message = el("p", {class: "form-message", role: "status"});
  const form = el("form", {class: "login-form intro-form"}, [
    el("label", {}, [el("span", {text: "デッキ"}), select]),
    el("label", {}, [el("span", {text: `コメント(省略できます・${COMMENT_MAX_LENGTH}字まで)`}), comment]),
    submit,
    message,
  ]);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    submit.disabled = true;
    message.textContent = "";
    message.textContent = await send(Number(select.value), comment.value);
    submit.disabled = false;
  });
  return form;
}

export async function renderIntroducePage(root) {
  const user = currentUser();
  if (!user) {
    goToLogin();
    return;
  }
  const heading = el("h1", {text: "デッキを紹介する"});
  const lead = el("p", {class: "lead", text: "自分のデッキを選び、コメントを添えて Discord の #デッキ紹介 へ流します。"});
  root.replaceChildren(heading, lead, el("p", {class: "notice", text: "読み込んでいます"}));
  const [linked, player] = await Promise.all([isLinked(user.uid), authedDoc(`players/${user.uid}`)]);
  if (linked === null || player === null) {
    root.replaceChildren(heading, lead, el("p", {class: "notice", text: "読み込めませんでした"}));
    return;
  }
  if (!linked) {
    root.replaceChildren(heading, lead, el("p", {class: "notice", text: NOT_LINKED}));
    return;
  }
  const decks = completeDecks(player);
  if (decks.length === 0) {
    root.replaceChildren(heading, lead, el("p", {class: "notice", text: "30枚そろったデッキがありません"}));
    return;
  }
  root.replaceChildren(heading, lead, introForm(decks));
}
