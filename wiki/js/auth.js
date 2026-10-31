// ゲームのID/パスワードでのログイン(GameDesign.md 32章 / Architecture.md 10.21節)。
// ゲームと同じ Firebase Authentication を REST で使う。パスワードは保存せず、更新用のトークンだけを
// このブラウザに残す。
const SYNTHETIC_EMAIL_DOMAIN = "hourglass-arena.local";
const STORAGE_KEY = "wiki_session";
// 期限の少し前に更新する(通信の途中で切れないように)。
const REFRESH_MARGIN_MS = 60 * 1000;

let configPromise = null;
let session = readSession();

function loadConfig() {
  if (!configPromise) configPromise = fetch("/data/config.json").then((response) => response.json());
  return configPromise;
}

function readSession() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || null;
  } catch (error) {
    return null;
  }
}

function storeSession(value) {
  session = value;
  try {
    if (value) localStorage.setItem(STORAGE_KEY, JSON.stringify(value));
    else localStorage.removeItem(STORAGE_KEY);
  } catch (error) {
    // 保存できないブラウザでは、このページを開いている間だけログインしている。
  }
}

export function currentUser() {
  return session ? {uid: session.uid, loginId: session.loginId} : null;
}

/** ゲームの `FirebaseAuth._to_email()` と同じ変換。 */
function toEmail(loginId) {
  return `${loginId.trim().toLowerCase()}@${SYNTHETIC_EMAIL_DOMAIN}`;
}

const ERROR_MESSAGES = {
  INVALID_LOGIN_CREDENTIALS: "IDかパスワードが違います",
  INVALID_PASSWORD: "IDかパスワードが違います",
  EMAIL_NOT_FOUND: "IDかパスワードが違います",
  INVALID_EMAIL: "IDかパスワードが違います",
  USER_DISABLED: "このアカウントは使えません",
  TOO_MANY_ATTEMPTS_TRY_LATER: "試行が多すぎます。しばらくしてからやり直してください",
};

/** 成功したら空文字、失敗したら理由の1行を返す。 */
export async function signIn(loginId, password) {
  const {apiKey} = await loadConfig();
  let response;
  try {
    response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email: toEmail(loginId), password, returnSecureToken: true}),
    });
  } catch (error) {
    return "通信に失敗しました。接続を確認してください";
  }
  const body = await response.json();
  if (!response.ok) {
    const code = String(body.error?.message || "").split(" ")[0];
    return ERROR_MESSAGES[code] || "ログインできませんでした";
  }
  storeSession({
    uid: body.localId,
    loginId: loginId.trim(),
    idToken: body.idToken,
    refreshToken: body.refreshToken,
    expiresAt: Date.now() + Number(body.expiresIn) * 1000,
  });
  return "";
}

export function signOut() {
  storeSession(null);
}

/** Firestore へ添える ID トークン。更新できなければログアウトして null を返す。 */
export async function idToken() {
  if (!session) return null;
  if (Date.now() < session.expiresAt - REFRESH_MARGIN_MS) return session.idToken;
  const {apiKey} = await loadConfig();
  const response = await fetch(`https://securetoken.googleapis.com/v1/token?key=${apiKey}`, {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({grant_type: "refresh_token", refresh_token: session.refreshToken}),
  }).catch(() => null);
  if (!response || !response.ok) {
    if (response) signOut();
    return null;
  }
  const body = await response.json();
  storeSession({
    ...session,
    idToken: body.id_token,
    refreshToken: body.refresh_token,
    expiresAt: Date.now() + Number(body.expires_in) * 1000,
  });
  return session.idToken;
}
