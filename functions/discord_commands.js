/**
 * Discordスラッシュコマンド `/card` `/deck` `/link` `/profile` と `/link` のフォーム送信のハンドラ
 * (GameDesign.md 26章 / Architecture.md 10.14節)。
 *
 * `discordInteractions`(index.js)から呼ばれる。常駐するBotプロセスは持たないため、
 * ここに書くのはいずれも「1回のHTTPリクエストの中で完結する処理」だけにする。
 */

const {InteractionResponseType} = require("discord-interactions");
const cardsData = require("./data/cards.json");

// カード画像・実演動画はビルドのたびにリポジトリへコミットしている(10.14節)ため、
// 常駐サーバーを持たずに配信するには、BGMと同じくjsDelivr経由でリポジトリから
// 直接読ませる(Architecture.md 4.1.6節と同じ考え方)。@main を指すため、
// 新しいカードを足してpushすれば数分〜数時間でここにも反映される
// (jsDelivrのキャッシュが効くため即時ではない)。
const CDN_BASE = "https://cdn.jsdelivr.net/gh/Omezi42/hourglassPVP@main";

const EPHEMERAL = 64;

const DISCORD_API = "https://discord.com/api/v10";

/** id → CardData の索引。起動のたびに1度だけ作る。 */
const CARDS_BY_ID = new Map(cardsData.cards.map((c) => [c.id, c]));

/** コスト順(GameDesign.md 9章と同じ並び。同コストは砂時計が先・砂術が後・総量順)。 */
function compareByCost(a, b) {
  if (a.cost !== b.cost) return a.cost - b.cost;
  if (a.is_spell !== b.is_spell) return a.is_spell ? 1 : -1;
  if (a.total_sand !== b.total_sand) return a.total_sand - b.total_sand;
  return a.id < b.id ? -1 : 1;
}

/** 表示名の部分一致検索。大文字小文字・全角半角は区別しない。 */
function searchCards(query) {
  const needle = query.trim().toLowerCase();
  if (!needle) return [];
  return cardsData.cards.filter((c) => c.display_name.toLowerCase().includes(needle));
}

function optionValue(interaction, name) {
  const options = interaction.data && interaction.data.options;
  if (!options) return "";
  const found = options.find((o) => o.name === name);
  return found ? String(found.value) : "";
}

function interactionUserId(interaction) {
  if (interaction.member && interaction.member.user) return interaction.member.user.id;
  if (interaction.user) return interaction.user.id;
  return "";
}

function ephemeralMessage(content, embeds) {
  return {
    type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
    data: {flags: EPHEMERAL, content: content || undefined, embeds: embeds || undefined},
  };
}

// --- /card -----------------------------------------------------------------

function buildCardEmbeds(card) {
  const total = card.is_spell ? "術" : String(card.total_sand);
  return [
    {
      title: card.display_name,
      description: `コスト ${card.cost} / 総量 ${total}\n${card.describe}`,
      color: card.is_spell ? 0x4a5a90 : 0xb08a3e,
      image: {url: `${CDN_BASE}/functions/data/card_art/${card.id}.png`},
    },
  ];
}

/**
 * 能力の実演(MP4)を添付として読む。埋め込みの画像欄は動画を再生できないため、
 * メッセージの添付として送り、Discordのプレイヤーで再生させる。読めなければ null
 * (実演が無くてもカードの詳細は返す)。
 */
async function fetchEffectVideo(card) {
  try {
    const response = await fetch(`${CDN_BASE}/functions/data/effect_videos/${card.id}.mp4`);
    if (!response.ok) return null;
    return {
      buffer: Buffer.from(await response.arrayBuffer()),
      filename: `${card.id}.mp4`,
      type: "video/mp4",
    };
  } catch (error) {
    console.error(`effect video fetch failed: ${error}`);
    return null;
  }
}

/** payload_json と添付ファイルを multipart の本文にまとめる。 */
function messageForm(payload, files) {
  const form = new FormData();
  form.append("payload_json", JSON.stringify(payload));
  files.forEach((file, index) => {
    form.append(`files[${index}]`, new Blob([file.buffer], {type: file.type}), file.filename);
  });
  return form;
}

/** カードの詳細と実演の動画を1通にした本文。 */
async function cardMessageForm(card, embeds) {
  const video = await fetchEffectVideo(card);
  return messageForm({embeds}, video ? [video] : []);
}

/**
 * 表示名からカードを1枚に絞る。絞れなければ返す文を message に入れる。
 * 表示名が完全一致するカードは、部分一致の絞り込みより先に見る。「サンド」で調べたのに
 * 「サンドショット」との複数候補にされ、正確に打ち込んだのに詳細を見られない、
 * という実際に踏んだ不具合の修正(GameDesign.md 26章)。
 */
function findCard(query) {
  const needle = query.trim().toLowerCase();
  const exact = cardsData.cards.find((c) => c.display_name.toLowerCase() === needle);
  if (exact) return {card: exact};
  const matches = searchCards(query);
  if (matches.length === 0) {
    return {message: `「${query}」に一致するカードが見つかりませんでした。`};
  }
  if (matches.length > 1) {
    const names = matches
      .slice(0, 10)
      .map((c) => c.display_name)
      .join(" / ");
    return {message: `候補が複数あります。もう少し詳しく入力してください。\n${names}`};
  }
  return {card: matches[0]};
}

/**
 * 1枚に絞れたら、defer をコールバックAPIへ先に送り、実演の動画を読んで `@original` を書き換えてから
 * null を返す(HTTPの応答はその後に返す)。絞れなければHTTPの応答として返す本文を返す。
 *
 * - HTTPの応答本文では添付を送れない
 * - deferをHTTPの応答で返して後から追送すると、応答を返した後はCPUが絞られて追送に10秒以上かかる
 * - 動画つきの返信をコールバックへ一度に送ると、コールドスタートで3秒の期限を越える
 */
async function respondCardCommand(interaction) {
  const {card, message} = findCard(optionValue(interaction, "name"));
  if (!card) return ephemeralMessage(message);
  const video = fetchEffectVideo(card);
  const {id, token, application_id: applicationId} = interaction;
  const deferred = await fetch(`${DISCORD_API}/interactions/${id}/${token}/callback`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(deferEphemeralResponse()),
  });
  if (!deferred.ok) {
    console.error(`card defer failed: ${deferred.status} ${await deferred.text()}`);
    return null;
  }
  const loaded = await video;
  const url = `${DISCORD_API}/webhooks/${applicationId}/${token}/messages/@original`;
  const form = messageForm({embeds: buildCardEmbeds(card)}, loaded ? [loaded] : []);
  const response = await fetch(url, {method: "PATCH", body: form});
  if (!response.ok) {
    console.error(`card reply failed: ${response.status} ${await response.text()}`);
  }
  return null;
}

// --- /link -------------------------------------------------------------------

const LINK_MODAL_ID = "link_modal";
const LINK_FIELD_ID = "login_id";
const LINK_FIELD_PASSWORD = "password";
// FirebaseAuth(scripts/net/firebase_auth.gd)の合成アドレスと同じ形にそろえる。
const SYNTHETIC_EMAIL_DOMAIN = "hourglass-arena.local";
const ID_MAX_LENGTH = 20;
const PASSWORD_MAX_LENGTH = 128;
// 認証の確認はすべてこの関数の回線から出るため、1人の総当たりで全員が止まらないよう絞る。
const LINK_FAILURE_LIMIT = 5;
const LINK_FAILURE_WINDOW_MS = 60 * 60 * 1000;
const SIGN_IN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=";
const TEXT_INPUT_SHORT = 1;
const ACTION_ROW = 1;
const TEXT_INPUT = 4;

/** `/link` はID/パスワードのフォームを開くだけ(GameDesign.md 26章)。 */
function handleLinkCommand() {
  const field = (id, label, maxLength) => ({
    type: ACTION_ROW,
    components: [
      {type: TEXT_INPUT, custom_id: id, label, style: TEXT_INPUT_SHORT, required: true, max_length: maxLength},
    ],
  });
  return {
    type: InteractionResponseType.MODAL,
    data: {
      custom_id: LINK_MODAL_ID,
      title: "ゲーム内アカウントと連携",
      components: [
        field(LINK_FIELD_ID, "ID(ゲームのログインに使うもの)", ID_MAX_LENGTH),
        field(LINK_FIELD_PASSWORD, "パスワード(保存しません)", PASSWORD_MAX_LENGTH),
      ],
    },
  };
}

function modalValue(interaction, customId) {
  const rows = (interaction.data && interaction.data.components) || [];
  for (const row of rows) {
    for (const component of row.components || []) {
      if (component.custom_id === customId) return String(component.value || "");
    }
  }
  return "";
}

/** ゲームのログインと同じ認証でuidを引く。違っていれば空文字。 */
async function signInUid(apiKey, loginId, password) {
  const response = await fetch(SIGN_IN_URL + apiKey, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      email: `${loginId.trim().toLowerCase()}@${SYNTHETIC_EMAIL_DOMAIN}`,
      password,
      returnSecureToken: false,
    }),
  });
  if (!response.ok) return "";
  const body = await response.json();
  return body.localId || "";
}

/** 直近の窓で失敗が上限に達していれば true。 */
async function linkLocked(attemptRef) {
  const doc = await attemptRef.get();
  if (!doc.exists) return false;
  const {window_start: windowStart, failures} = doc.data();
  return Date.now() - windowStart < LINK_FAILURE_WINDOW_MS && failures >= LINK_FAILURE_LIMIT;
}

async function recordLinkFailure(attemptRef) {
  const doc = await attemptRef.get();
  const now = Date.now();
  const data = doc.exists ? doc.data() : null;
  if (!data || now - data.window_start >= LINK_FAILURE_WINDOW_MS) {
    await attemptRef.set({window_start: now, failures: 1});
    return;
  }
  await attemptRef.update({failures: data.failures + 1});
}

async function handleLinkModalSubmit(interaction, db, apiKey) {
  const discordUserId = interactionUserId(interaction);
  const attemptRef = db.collection("discord_link_attempts").doc(discordUserId);
  if (await linkLocked(attemptRef)) {
    return ephemeralMessage("失敗が続いたため、しばらく時間をおいてからもう一度お試しください。");
  }
  const loginId = modalValue(interaction, LINK_FIELD_ID);
  const password = modalValue(interaction, LINK_FIELD_PASSWORD);
  const uid = await signInUid(apiKey, loginId, password);
  if (!uid) {
    await recordLinkFailure(attemptRef);
    return ephemeralMessage(
      "IDかパスワードが違います。ゲストのままの場合は、ゲーム内のアカウント画面で" +
        "IDを登録してからお試しください。"
    );
  }
  // 1つのDiscordアカウントにつき1つのuidだけを保持し、結び直すと上書きする(GameDesign.md 26章)。
  await db.collection("discord_links").doc(discordUserId).set({uid, linked_at: Date.now()});
  await attemptRef.delete();
  return ephemeralMessage("連携しました。これから /profile で確認できます。");
}

// --- /profile ------------------------------------------------------------------

/** GameDesign.md 22章・Architecture.md 10.9節と同じ、2本の等価フィルタをマージする方式。 */
async function fetchMatchTotals(db, uid) {
  const [asA, asB] = await Promise.all([
    db.collection("match_records").where("player_a", "==", uid).get(),
    db.collection("match_records").where("player_b", "==", uid).get(),
  ]);
  let games = 0;
  let wins = 0;
  for (const doc of asA.docs) {
    games += 1;
    if (doc.data().winner === "a") wins += 1;
  }
  for (const doc of asB.docs) {
    games += 1;
    if (doc.data().winner === "b") wins += 1;
  }
  return {games, wins};
}

async function handleProfileCommand(interaction, db) {
  const discordUserId = interactionUserId(interaction);
  const linkDoc = await db.collection("discord_links").doc(discordUserId).get();
  if (!linkDoc.exists) {
    return ephemeralMessage(
      "まだ連携されていません。`/link` を打ち、ゲームのログインに使うID/パスワードを入力してください。"
    );
  }
  const uid = linkDoc.data().uid;
  const playerDoc = await db.collection("players").doc(uid).get();
  const player = playerDoc.exists ? playerDoc.data() : {};
  const totals = await fetchMatchTotals(db, uid);
  const winRate = totals.games > 0 ? Math.round((totals.wins / totals.games) * 100) : null;
  const lines = [
    `表示名: ${player.display_name || "(未設定)"}`,
    `砂金: ${player.currency || 0}`,
    `オンライン対戦: ${totals.games}戦${winRate !== null ? ` (勝率${winRate}%)` : ""}`,
  ];
  return ephemeralMessage(lines.join("\n"));
}

// --- /deck ---------------------------------------------------------------------

/** ephemeralのdeferred応答。実際の画像は後から webhook 経由で追送する(3秒制限を避ける)。 */
function deferEphemeralResponse() {
  return {
    type: InteractionResponseType.DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE,
    data: {flags: EPHEMERAL},
  };
}

async function sendDeckFollowup(interaction, db) {
  const applicationId = interaction.application_id;
  const token = interaction.token;
  const code = optionValue(interaction, "code").trim();
  // deck_share.js がこのファイルの parseDeckText を読むため、循環しないよう使う時点で読む。
  const {readDeckCode, renderDeckCodeImage} = require("./deck_share");
  const deck = await readDeckCode(db, code);
  if (!deck) {
    await editOriginalResponse(applicationId, token, {content: "見つかりませんでした。"});
    return;
  }
  const png = await renderDeckCodeImage(deck);
  await editOriginalResponseWithImage(applicationId, token, png, "deck.png");
}

/** `CardDeckCode.to_text()` と同じ「id*枚数」を `,` で連ねた形式を読む。 */
function parseDeckText(text) {
  const entries = [];
  for (const part of text.split(",")) {
    const [id, countText] = part.split("*");
    const card = CARDS_BY_ID.get(id);
    const count = parseInt(countText, 10) || 0;
    if (!card || count <= 0) continue;
    for (let i = 0; i < count; i += 1) entries.push(card);
  }
  return entries.sort(compareByCost);
}

async function editOriginalResponse(applicationId, token, payload) {
  const url = `${DISCORD_API}/webhooks/${applicationId}/${token}/messages/@original`;
  await fetch(url, {
    method: "PATCH",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(payload),
  });
}

async function editOriginalResponseWithImage(applicationId, token, buffer, filename) {
  const url = `${DISCORD_API}/webhooks/${applicationId}/${token}/messages/@original`;
  const form = messageForm({embeds: [{image: {url: `attachment://${filename}`}}]}, [
    {buffer, filename, type: "image/png"},
  ]);
  await fetch(url, {method: "PATCH", body: form});
}

module.exports = {
  respondCardCommand,
  cardMessageForm,
  handleLinkCommand,
  handleLinkModalSubmit,
  LINK_MODAL_ID,
  handleProfileCommand,
  deferEphemeralResponse,
  sendDeckFollowup,
  searchCards,
  parseDeckText,
  compareByCost,
  buildCardEmbeds,
};
