import {el} from "./dom.js";
import {signIn} from "./auth.js";

// ログインのページ(GameDesign.md 32章)。ログインの後は、ここへ来る前のページへ戻る。
const RETURN_KEY = "wiki_return";

/** 今のページを覚えてログインへ進む。 */
export function goToLogin() {
  try {
    sessionStorage.setItem(RETURN_KEY, location.pathname + location.hash);
  } catch (error) {
    // 覚えられなければ、ログインの後はカード辞典へ戻る。
  }
  location.href = "/#login";
}

function takeReturnPath() {
  try {
    const path = sessionStorage.getItem(RETURN_KEY);
    sessionStorage.removeItem(RETURN_KEY);
    return path && path.startsWith("/") ? path : "/#cards";
  } catch (error) {
    return "/#cards";
  }
}

export function renderLoginPage(root) {
  const id = el("input", {type: "text", name: "id", autocomplete: "username", required: "", maxlength: "20"});
  const password = el("input", {type: "password", name: "password", autocomplete: "current-password", required: ""});
  const submit = el("button", {class: "action", type: "submit", text: "ログイン"});
  const message = el("p", {class: "form-message", role: "alert"});
  const form = el("form", {class: "login-form"}, [
    el("label", {}, [el("span", {text: "ID"}), id]),
    el("label", {}, [el("span", {text: "パスワード"}), password]),
    submit,
    message,
  ]);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    submit.disabled = true;
    message.textContent = "";
    const error = await signIn(id.value, password.value);
    if (error) {
      message.textContent = error;
      submit.disabled = false;
      return;
    }
    location.href = takeReturnPath();
  });
  root.replaceChildren(
    el("h1", {text: "ログイン"}),
    el("p", {class: "lead", text: "ゲームで登録したIDとパスワードでログインします。"}),
    form,
    el("p", {class: "action-note", text: "ゲームのアカウント画面でIDを登録すると、ここに入れます"}),
  );
}
