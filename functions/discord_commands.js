/**
 * Discordスラッシュコマンド `/card` `/deck` `/link` `/profile` のハンドラ
 * (GameDesign.md 26章 / Architecture.md 10.14節)。
 *
 * `discordInteractions`(index.js)から呼ばれる。常駐するBotプロセスは持たないため、
 * ここに書くのはいずれも「1回のHTTPリクエストの中で完結する処理」だけにする。
 */

const {InteractionResponseType} = require("discord-interactions");
const cardsData = require("./data/cards.json");
const {renderDeckSheet} = require("./deck_sheet_canvas");

// カード画像・実演GIFはビルドのたびにリポジトリへコミットしている(10.14節)ため、
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
    {
      title: "実演",
      image: {url: `${CDN_BASE}/functions/data/effect_gifs/${card.id}.gif`},
      color: card.is_spell ? 0x4a5a90 : 0xb08a3e,
    },
  ];
}

function handleCardCommand(interaction) {
  const query = optionValue(interaction, "name");
  // 表示名が完全一致するカードは、部分一致の絞り込みより先に見る。「サンド」で調べたのに
  // 「サンドショット」との複数候補にされ、正確に打ち込んだのに詳細を見られない、
  // という実際に踏んだ不具合の修正(GameDesign.md 26章)。
  const needle = query.trim().toLowerCase();
  const exact = cardsData.cards.find((c) => c.display_name.toLowerCase() === needle);
  if (exact) {
    return ephemeralMessage(null, buildCardEmbeds(exact));
  }
  const matches = searchCards(query);
  if (matches.length === 0) {
    return ephemeralMessage(`「${query}」に一致するカードが見つかりませんでした。`);
  }
  if (matches.length > 1) {
    const names = matches
      .slice(0, 10)
      .map((c) => c.display_name)
      .join(" / ");
    return ephemeralMessage(`候補が複数あります。もう少し詳しく入力してください。\n${names}`);
  }
  return ephemeralMessage(null, buildCardEmbeds(matches[0]));
}

// --- /link -------------------------------------------------------------------

async function handleLinkCommand(interaction, db) {
  const code = optionValue(interaction, "code").trim();
  const discordUserId = interactionUserId(interaction);
  if (!/^[0-9]{8}$/.test(code)) {
    return ephemeralMessage("コードは8桁の数字で入力してください。");
  }
  const codeDoc = await db.collection("discord_link_codes").doc(code).get();
  if (!codeDoc.exists) {
    return ephemeralMessage("そのコードは見つかりませんでした。ゲーム内で発行し直してください。");
  }
  const uid = codeDoc.data().uid;
  if (!uid) {
    return ephemeralMessage("そのコードは見つかりませんでした。ゲーム内で発行し直してください。");
  }
  // 1つのDiscordアカウントにつき1つのuidだけを保持する(GameDesign.md 26章)。
  // 結び直すと前の紐付けを上書きする。
  await db.collection("discord_links").doc(discordUserId).set({
    uid,
    linked_at: Date.now(),
  });
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
      "まだ連携されていません。ゲーム内のアカウント画面で連携コードを発行し、" +
        "`/link <コード>` を実行してください。"
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
function deferDeckResponse() {
  return {
    type: InteractionResponseType.DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE,
    data: {flags: EPHEMERAL},
  };
}

async function sendDeckFollowup(interaction, db) {
  const applicationId = interaction.application_id;
  const token = interaction.token;
  const code = optionValue(interaction, "code").trim();
  const doc = await db.collection("deckcodes").doc(code).get();
  if (!doc.exists) {
    await editOriginalResponse(applicationId, token, {content: "見つかりませんでした。"});
    return;
  }
  const text = doc.data().cards || "";
  const cards = parseDeckText(text);
  if (cards.length === 0) {
    await editOriginalResponse(applicationId, token, {content: "見つかりませんでした。"});
    return;
  }
  const png = await renderDeckSheet(cards);
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
  const form = new FormData();
  form.append(
    "payload_json",
    JSON.stringify({embeds: [{image: {url: `attachment://${filename}`}}]})
  );
  form.append("files[0]", new Blob([buffer], {type: "image/png"}), filename);
  await fetch(url, {method: "PATCH", body: form});
}

module.exports = {
  handleCardCommand,
  handleLinkCommand,
  handleProfileCommand,
  deferDeckResponse,
  sendDeckFollowup,
  searchCards,
  parseDeckText,
  compareByCost,
  buildCardEmbeds,
};
