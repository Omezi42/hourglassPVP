import {el} from "./dom.js";

// カードの一覧(build_wiki.py が functions/data/cards.json から写したもの)と、詳細の窓。
let cardsPromise = null;

export function loadCards() {
  if (!cardsPromise) {
    cardsPromise = fetch("data/cards.json").then((response) => response.json()).then((body) => body.cards);
  }
  return cardsPromise;
}

export function thumbUrl(card) {
  return card.has_art ? `art/${card.id}_thumb.webp` : "";
}

export function compareByCost(a, b) {
  return a.cost - b.cost || a.pool_index - b.pool_index;
}

export function openCardDialog(card) {
  const dialog = document.getElementById("card-dialog");
  const art = document.getElementById("card-dialog-art");
  const text = document.getElementById("card-dialog-text");
  art.hidden = !card.has_art;
  art.src = card.has_art ? `art/${card.id}.webp` : "";
  art.alt = `${card.display_name} コスト${card.cost} ${card.describe}`;
  // 絵が無いカードだけ、文字で中身を出す。
  text.textContent = card.has_art ? "" : `${card.display_name}(コスト${card.cost}) ${card.describe}`;
  dialog.showModal();
}


const KIND_FILTERS = [
  ["all", "すべて"],
  ["hourglass", "砂時計"],
  ["spell", "砂術"],
];

function matches(card, query, kind) {
  if (kind === "hourglass" && card.is_spell) return false;
  if (kind === "spell" && !card.is_spell) return false;
  if (!query) return true;
  return `${card.display_name} ${card.describe}`.toLowerCase().includes(query);
}

export function tile(card, count = 1) {
  const nums = el("div", {class: "card-tile__nums"});
  nums.innerHTML = `<span>コスト <b>${card.cost}</b></span>` +
    (card.is_spell ? "" : `<span>総量 <b>${card.total_sand}</b></span>`);
  const name = el("p", {class: "card-tile__name", text: card.display_name});
  if (count > 1) name.append(el("span", {class: "badge badge--count", text: `×${count}`}));
  if (card.is_spell) name.append(el("span", {class: "badge", text: "砂術"}));
  const button = el("button", {class: "card-tile", type: "button"}, [
    el("img", {src: thumbUrl(card), alt: "", loading: "lazy", width: "64", height: "84"}),
    el("div", {}, [name, nums, el("p", {class: "card-tile__text", text: card.describe})]),
  ]);
  button.addEventListener("click", () => openCardDialog(card));
  return button;
}

export async function renderCardsPage(root) {
  const cards = (await loadCards()).slice().sort(compareByCost);
  const state = {query: "", kind: "all"};
  const search = el("input", {type: "search", placeholder: "名前・効果で探す(例: 守護)", "aria-label": "カードを探す"});
  const segmented = el("div", {class: "segmented", role: "group", "aria-label": "種類"});
  const count = el("span", {class: "count"});
  const grid = el("div", {class: "card-grid"});

  const render = () => {
    const shown = cards.filter((card) => matches(card, state.query, state.kind));
    grid.replaceChildren(...shown.map((card) => tile(card)));
    count.textContent = `${shown.length} / ${cards.length}枚`;
    for (const button of segmented.children) button.setAttribute("aria-pressed", button.dataset.kind === state.kind);
  };
  for (const [kind, label] of KIND_FILTERS) {
    const button = el("button", {type: "button", "data-kind": kind, text: label});
    button.addEventListener("click", () => { state.kind = kind; render(); });
    segmented.append(button);
  }
  search.addEventListener("input", () => { state.query = search.value.trim().toLowerCase(); render(); });

  root.replaceChildren(
    el("h1", {text: "カード辞典"}),
    el("p", {class: "lead", text: "いま遊べる全カード。カードを押すと図鑑と同じ詳細を出します。"}),
    el("div", {class: "toolbar"}, [search, segmented, count]),
    grid,
  );
  render();
}
