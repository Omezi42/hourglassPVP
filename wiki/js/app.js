// ページの切り替え(URL の # で選ぶ)。
import {renderCardsPage} from "./cards.js";
import {renderStatsPage} from "./stats.js";

const PAGES = {
  cards: {title: "カード辞典", render: renderCardsPage},
  stats: {title: "みんなの統計", render: renderStatsPage},
};
const DEFAULT_PAGE = "cards";
const SITE_NAME = "砂時計アリーナ 攻略データベース";

function route() {
  const name = location.hash.slice(1);
  const key = name in PAGES ? name : DEFAULT_PAGE;
  for (const link of document.querySelectorAll(".site-nav a")) {
    if (link.dataset.page === key) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
  document.title = `${PAGES[key].title} | ${SITE_NAME}`;
  window.scrollTo(0, 0);
  PAGES[key].render(document.getElementById("page"));
}

window.addEventListener("hashchange", route);
route();
