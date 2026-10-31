// ページの切り替え(URL の # で選ぶ。共有リンク /d/{code} だけはパスで選ぶ)。
import {renderCardsPage} from "./cards.js";
import {renderStatsPage} from "./stats.js";
import {DECK_PATH, renderDeckPage} from "./deck.js";
import {renderLoginPage} from "./login.js";
import {currentUser, signOut} from "./auth.js";

const PAGES = {
  cards: {title: "カード辞典", render: renderCardsPage},
  stats: {title: "みんなの統計", render: renderStatsPage},
  login: {title: "ログイン", render: renderLoginPage},
};
const DEFAULT_PAGE = "cards";
const SITE_NAME = "砂時計アリーナ 攻略データベース";

function setCurrentNav(key) {
  for (const link of document.querySelectorAll(".site-nav a")) {
    if (link.dataset.page === key) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
}

/** ヘッダーの右端: ログインしていればIDとログアウト、していなければログイン。 */
function renderAccount() {
  const slot = document.getElementById("account");
  const user = currentUser();
  if (!user) {
    slot.innerHTML = '<a href="/#login" data-page="login">ログイン</a>';
    return;
  }
  const button = document.createElement("button");
  button.type = "button";
  button.className = "link-button";
  button.textContent = "ログアウト";
  button.addEventListener("click", () => {
    signOut();
    route();
  });
  slot.replaceChildren(`${user.loginId} `, button);
}

function route() {
  renderAccount();
  const deckMatch = DECK_PATH.exec(location.pathname);
  if (deckMatch && !location.hash) {
    setCurrentNav("");
    renderDeckPage(document.getElementById("page"), deckMatch[1]);
    return;
  }
  const name = location.hash.slice(1);
  const key = name in PAGES ? name : DEFAULT_PAGE;
  setCurrentNav(key);
  document.title = `${PAGES[key].title} | ${SITE_NAME}`;
  window.scrollTo(0, 0);
  PAGES[key].render(document.getElementById("page"));
}

window.addEventListener("hashchange", route);
route();
