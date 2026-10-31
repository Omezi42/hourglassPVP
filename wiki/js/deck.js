import {el} from "./dom.js";
import {compareByCost, loadCards, tile} from "./cards.js";
import {currentUser} from "./auth.js";
import {authedRequest} from "./firestore.js";
import {goToLogin} from "./login.js";

// 共有リンク /d/{code} のデッキ(GameDesign.md 32章)。中身は Pages Functions の /d/{code}.json から読む。
const COPIED_MS = 1500;
// 受け取り箱に置ける件数(GameDesign.md 32章)。ゲームが受け取ると空く。
const INBOX_LIMIT = 10;

export const DECK_PATH = /^\/d\/(\d{8})$/;

/** `CardDeckCode.to_text()` の「id*枚数」を `,` で連ねた形を [{card, count}] へ戻す。 */
function parseDeckText(text, cardsById) {
  const entries = [];
  for (const part of text.split(",")) {
    const [id, countText] = part.split("*");
    const card = cardsById.get(id);
    const count = parseInt(countText, 10) || 0;
    if (card && count > 0) entries.push({card, count});
  }
  return entries.sort((a, b) => compareByCost(a.card, b.card));
}

function copyButton(label, text) {
  const button = el("button", {class: "action action--quiet", type: "button", text: label});
  button.addEventListener("click", async () => {
    await navigator.clipboard.writeText(text);
    button.textContent = "コピーしました";
    setTimeout(() => { button.textContent = label; }, COPIED_MS);
  });
  return button;
}

/** 受け取り箱へ置く。結果の1行を返す。 */
async function sendToGame(deck) {
  const inbox = `players/${currentUser().uid}/deck_inbox`;
  const listed = await authedRequest(`${inbox}?pageSize=${INBOX_LIMIT}`);
  if (!listed) return "ログインが切れました。もう一度ログインしてください";
  if (!listed.ok) return "追加できませんでした";
  if (((await listed.json()).documents || []).length >= INBOX_LIMIT) {
    return "ゲームを開いて受け取ってから追加してください";
  }
  const created = await authedRequest(inbox, {
    method: "POST",
    fields: {name: deck.name, cards: deck.cards, sent_at: Math.floor(Date.now() / 1000)},
  });
  if (!created || !created.ok) return "追加できませんでした";
  return "追加しました。ゲームでデッキ一覧を開くと入っています";
}

function addToGame(deck) {
  const button = el("button", {class: "action", type: "button", text: "ゲームに追加"});
  const note = el("span", {class: "action-note"});
  const user = currentUser();
  note.textContent = user ? `${user.loginId} のデッキ一覧へ` : "ログインすると追加できます";
  button.addEventListener("click", async () => {
    if (!currentUser()) {
      goToLogin();
      return;
    }
    button.disabled = true;
    note.textContent = await sendToGame(deck);
    button.disabled = false;
  });
  return el("div", {class: "deck-code"}, [button, note]);
}

export async function renderDeckPage(root, code) {
  const [response, cards] = await Promise.all([fetch(`/d/${code}.json`), loadCards()]);
  if (!response.ok) {
    root.replaceChildren(el("h1", {text: "デッキ"}), el("p", {class: "notice", text: "見つかりませんでした"}));
    return null;
  }
  const deck = await response.json();
  const entries = parseDeckText(deck.cards, new Map(cards.map((card) => [card.id, card])));
  const total = entries.reduce((sum, entry) => sum + entry.count, 0);
  root.replaceChildren(
    el("h1", {text: deck.name}),
    el("p", {class: "lead", text: `${total}枚・コスト順`}),
    el("div", {class: "deck-code"}, [
      el("span", {text: "デッキコード"}),
      el("span", {class: "deck-code__number", text: code}),
      copyButton("コードをコピー", code),
      copyButton("リンクをコピー", location.href),
    ]),
    addToGame(deck),
    el("div", {class: "card-grid"}, entries.map((entry) => tile(entry.card, entry.count))),
  );
  return deck;
}
