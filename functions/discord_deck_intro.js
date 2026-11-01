/**
 * Discordのデッキ紹介(GameDesign.md 26章 / Architecture.md 10.14節)。
 *
 * 入口のボタン → 自分のデッキの選択肢 → コメントのフォーム → #デッキ紹介 へ投稿、と
 * 紹介の投稿に付く「ゲームに追加」を受け持つ。状態はボタンに持たせず、毎回Firestoreから読む。
 */

const {InteractionResponseType} = require("discord-interactions");
const {
  handleLinkCommand,
  messageForm,
  deferEphemeralResponse,
  parseDeckText,
} = require("./discord_commands");

const DISCORD_API = "https://discord.com/api/v10";
const EPHEMERAL = 64;
const DECK_SIZE = 30;
const SELECT_OPTION_LIMIT = 25;
const COMMENT_MAX_LENGTH = 200;
const DEFAULT_DECK_NAME = "デッキ";
// 攻略サイトの「ゲームに追加」と同じ上限(GameDesign.md 32章)。
const INBOX_LIMIT = 10;
const CODE_LENGTH = 8;
const ISSUE_RETRY_COUNT = 5;
const WIKI_DECK_BASE = "https://sunadokei-arena-wiki.pages.dev/d/";
const EMBED_COLOR = 0xb08a3e;

const ID_START = "deck_intro:start";
const ID_LINK = "deck_intro:link";
const ID_PICK = "deck_intro:pick";
const ID_COMMENT_PREFIX = "deck_intro:comment:";
const ID_ADD_PREFIX = "deck_add:";
const FIELD_COMMENT = "comment";

const ACTION_ROW = 1;
const BUTTON = 2;
const STRING_SELECT = 3;
const TEXT_INPUT = 4;
const BUTTON_PRIMARY = 1;
const BUTTON_SECONDARY = 2;
const BUTTON_LINK = 5;
const TEXT_INPUT_PARAGRAPH = 2;

function interactionUserId(interaction) {
  if (interaction.member && interaction.member.user) return interaction.member.user.id;
  if (interaction.user) return interaction.user.id;
  return "";
}

function ephemeral(content, components) {
  return {
    type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
    data: {flags: EPHEMERAL, content, components: components || undefined},
  };
}

function linkButtonRow() {
  return [
    {
      type: ACTION_ROW,
      components: [{type: BUTTON, style: BUTTON_SECONDARY, custom_id: ID_LINK, label: "アカウント連携"}],
    },
  ];
}

function notLinkedMessage() {
  return ephemeral("先にゲーム内アカウントと連携してください。", linkButtonRow());
}

async function linkedUid(db, interaction) {
  const doc = await db.collection("discord_links").doc(interactionUserId(interaction)).get();
  return doc.exists ? doc.data().uid : "";
}

/** `players/{uid}.decks` のうち30枚そろったものを、添字つきで返す。 */
async function completeDecks(db, uid) {
  const doc = await db.collection("players").doc(uid).get();
  const decks = (doc.exists && doc.data().decks) || [];
  return decks
    .map((deck, index) => ({index, name: deck.name || DEFAULT_DECK_NAME, ids: deck.ids || []}))
    .filter((deck) => deck.ids.length === DECK_SIZE);
}

/** `CardDeckCode.to_text()` と同じ「id*枚数」を `,` で連ねた形(idの昇順)。 */
function deckText(ids) {
  const counts = new Map();
  for (const id of ids) counts.set(id, (counts.get(id) || 0) + 1);
  return [...counts.keys()]
    .sort()
    .map((id) => `${id}*${counts.get(id)}`)
    .join(",");
}

function randomCode() {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i += 1) code += String(Math.floor(Math.random() * 10));
  return code;
}

/** `DeckCodeService.publish()` と同じく、使われていない番号を取って預ける。 */
async function publishDeckCode(db, cards, name) {
  for (let attempt = 0; attempt < ISSUE_RETRY_COUNT; attempt += 1) {
    const code = randomCode();
    try {
      await db.collection("deckcodes").doc(code).create({cards, name, created_at: Math.floor(Date.now() / 1000)});
      return code;
    } catch (error) {
      if (error.code !== 6) throw error; // 6 = ALREADY_EXISTS。番号が衝突したら引き直す
    }
  }
  return "";
}

// --- 入口 ----------------------------------------------------------------------

async function handleStart(interaction, db) {
  const uid = await linkedUid(db, interaction);
  if (!uid) return notLinkedMessage();
  const decks = (await completeDecks(db, uid)).slice(0, SELECT_OPTION_LIMIT);
  if (decks.length === 0) return ephemeral("30枚そろったデッキがありません。");
  return ephemeral("紹介するデッキを選んでください。", [
    {
      type: ACTION_ROW,
      components: [
        {
          type: STRING_SELECT,
          custom_id: ID_PICK,
          placeholder: "デッキを選ぶ",
          options: decks.map((deck) => ({label: deck.name, value: String(deck.index)})),
        },
      ],
    },
  ]);
}

/** 選んだデッキのコメントのフォームを開く。 */
function handlePick(interaction) {
  const index = (interaction.data.values || [])[0] || "";
  return {
    type: InteractionResponseType.MODAL,
    data: {
      custom_id: `${ID_COMMENT_PREFIX}${index}`,
      title: "デッキを紹介する",
      components: [
        {
          type: ACTION_ROW,
          components: [
            {
              type: TEXT_INPUT,
              custom_id: FIELD_COMMENT,
              label: "コメント(省略できます)",
              style: TEXT_INPUT_PARAGRAPH,
              required: false,
              max_length: COMMENT_MAX_LENGTH,
            },
          ],
        },
      ],
    },
  };
}

// --- 投稿 ----------------------------------------------------------------------

function modalValue(interaction, customId) {
  for (const row of interaction.data.components || []) {
    for (const component of row.components || []) {
      if (component.custom_id === customId) return String(component.value || "");
    }
  }
  return "";
}

async function postToChannel(botToken, channelId, payload, files) {
  const response = await fetch(`${DISCORD_API}/channels/${channelId}/messages`, {
    method: "POST",
    headers: {Authorization: `Bot ${botToken}`},
    body: messageForm(payload, files),
  });
  if (!response.ok) {
    console.error(`deck intro post failed: ${response.status} ${await response.text()}`);
    return null;
  }
  return response.json();
}

function introPayload(interaction, deck, code, comment) {
  const lines = [`<@${interactionUserId(interaction)}> のデッキ紹介`];
  if (comment) lines.push("", comment);
  return {
    content: lines.join("\n"),
    allowed_mentions: {parse: []},
    embeds: [{title: deck.name, color: EMBED_COLOR, image: {url: "attachment://deck.png"}}],
    components: [
      {
        type: ACTION_ROW,
        components: [
          {type: BUTTON, style: BUTTON_PRIMARY, custom_id: `${ID_ADD_PREFIX}${code}`, label: "ゲームに追加"},
          {type: BUTTON, style: BUTTON_LINK, url: `${WIKI_DECK_BASE}${code}`, label: "サイトで見る"},
        ],
      },
    ],
  };
}

/** 紹介の本体。返り値は本人へ返す1行。 */
async function introduce(interaction, db, config) {
  const uid = await linkedUid(db, interaction);
  if (!uid) return "先にゲーム内アカウントと連携してください。";
  const index = Number(interaction.data.custom_id.slice(ID_COMMENT_PREFIX.length));
  const deck = (await completeDecks(db, uid)).find((d) => d.index === index);
  if (!deck) return "デッキが見つかりませんでした。もう一度選び直してください。";
  const cards = deckText(deck.ids);
  if (parseDeckText(cards).length !== DECK_SIZE) return "このデッキは紹介できません。";
  const code = await publishDeckCode(db, cards, deck.name);
  if (!code) return "紹介できませんでした。時間をおいてもう一度お試しください。";
  // deck_share.js がこのファイルの読み込み元を読むため、循環しないよう使う時点で読む。
  const {renderDeckCodeImage} = require("./deck_share");
  const png = await renderDeckCodeImage({code, name: deck.name, cards});
  const comment = modalValue(interaction, FIELD_COMMENT).trim();
  const posted = await postToChannel(config.botToken, config.channelId, introPayload(interaction, deck, code, comment), [
    {buffer: png, filename: "deck.png", type: "image/png"},
  ]);
  if (!posted) return "紹介できませんでした。時間をおいてもう一度お試しください。";
  // スマホのコピーは投稿単位のため、コードだけを返信の形で別に流す(GameDesign.md 26章)。
  await postToChannel(
    config.botToken,
    config.channelId,
    {content: code, message_reference: {message_id: posted.id}, allowed_mentions: {parse: []}},
    []
  );
  return `<#${config.channelId}> に投稿しました。`;
}

/**
 * コメントのフォームの送信。画像の生成で3秒を越えうるため、deferをコールバックへ先に送ってから
 * 処理し、`@original` を書き換える(`/card` と同じ。Architecture.md 10.14節)。
 */
async function handleCommentSubmit(interaction, db, config) {
  const {id, token, application_id: applicationId} = interaction;
  const deferred = await fetch(`${DISCORD_API}/interactions/${id}/${token}/callback`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(deferEphemeralResponse()),
  });
  if (!deferred.ok) {
    console.error(`deck intro defer failed: ${deferred.status} ${await deferred.text()}`);
    return;
  }
  const content = await introduce(interaction, db, config);
  await fetch(`${DISCORD_API}/webhooks/${applicationId}/${token}/messages/@original`, {
    method: "PATCH",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({content}),
  });
}

// --- ゲームに追加 ----------------------------------------------------------------

async function handleAdd(interaction, db) {
  const uid = await linkedUid(db, interaction);
  if (!uid) return notLinkedMessage();
  const code = interaction.data.custom_id.slice(ID_ADD_PREFIX.length);
  const {readDeckCode} = require("./deck_share");
  const deck = await readDeckCode(db, code);
  if (!deck) return ephemeral("このデッキは見つかりませんでした。");
  const inbox = db.collection("players").doc(uid).collection("deck_inbox");
  const queued = await inbox.limit(INBOX_LIMIT).get();
  if (queued.size >= INBOX_LIMIT) return ephemeral("ゲームを開いて受け取ってから追加してください");
  await inbox.add({name: deck.name, cards: deck.cards, sent_at: Math.floor(Date.now() / 1000)});
  return ephemeral(`ゲームを開くと「${deck.name}」が届きます。`);
}

// --- 振り分け ----------------------------------------------------------------------

/** ボタン・選択肢(MESSAGE_COMPONENT)。デッキ紹介のものでなければ null。 */
async function handleDeckIntroComponent(interaction, db) {
  const customId = interaction.data.custom_id || "";
  if (customId === ID_START) return handleStart(interaction, db);
  if (customId === ID_LINK) return handleLinkCommand();
  if (customId === ID_PICK) return handlePick(interaction);
  if (customId.startsWith(ID_ADD_PREFIX)) return handleAdd(interaction, db);
  return null;
}

function isDeckIntroModal(interaction) {
  return String(interaction.data.custom_id || "").startsWith(ID_COMMENT_PREFIX);
}

module.exports = {
  handleDeckIntroComponent,
  handleCommentSubmit,
  isDeckIntroModal,
  deckText,
};
