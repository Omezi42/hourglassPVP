import {el} from "./dom.js";
import {compareByCost, loadCards, tile} from "./cards.js";

// 共有リンク /d/{code} のデッキ(GameDesign.md 32章)。中身は Pages Functions の /d/{code}.json から読む。
const COPIED_MS = 1500;

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
    el("div", {class: "card-grid"}, entries.map((entry) => tile(entry.card, entry.count))),
  );
  return deck;
}
