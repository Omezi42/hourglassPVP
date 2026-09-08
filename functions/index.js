/**
 * 砂時計アリーナのDiscord連携(GameDesign.md 25章・26章 / Architecture.md 10.13〜10.14節)。
 *
 * この作品はバックエンドに自前サーバーを立てない方針(GameDesign.md 10章)だが、
 * 「日曜日になった瞬間に、誰も対局していなくても告知する」ことや、Discordから
 * カード・デッキ・アカウントの情報を引けるようにすることは、クライアント発火の
 * 仕組みでは実現できない。ここではFirebaseのサーバーレス関数(Cloud Functions)と
 * その定期実行(Cloud Scheduler)だけを足し、常駐するプロセスは持たない。
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {verifyKey, InteractionType, InteractionResponseType} = require("discord-interactions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const cardsData = require("./data/cards.json");
const {
  handleCardCommand,
  handleLinkCommand,
  handleProfileCommand,
  deferDeckResponse,
  sendDeckFollowup,
  buildCardEmbeds,
} = require("./discord_commands");

// Botトークン・公開鍵と同じ扱いで、リポジトリへは一切コミットしない。
// `firebase functions:secrets:set DISCORD_WEBHOOK_URL` / `DISCORD_PUBLIC_KEY` で設定する。
const DISCORD_WEBHOOK_URL = defineSecret("DISCORD_WEBHOOK_URL");
const DISCORD_PUBLIC_KEY = defineSecret("DISCORD_PUBLIC_KEY");

const ANNOUNCE_MESSAGE =
  "☀️ 本日は日曜イベント開催中!\n" +
  "ランダムマッチで手に入る砂金が、日付が変わるまで2倍になります。";

// カードスポットライトで、同じカードを続けて紹介しないための間隔(GameDesign.md 26章)。
const SPOTLIGHT_COOLDOWN_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * 毎週日曜0:00(JST)に1度だけ、Discordの#お知らせへ日曜イベント開始を告知する
 * (GameDesign.md 15章・25章)。1局ごと・日次の集計を自動投稿しない方針(22章)とは
 * 別物で、週1回しか起きないイベント開始の告知であるため自動化している。
 */
exports.announceSundayEvent = onSchedule(
  {schedule: "0 0 * * 0", timeZone: "Asia/Tokyo", secrets: [DISCORD_WEBHOOK_URL]},
  async () => {
    const webhookUrl = DISCORD_WEBHOOK_URL.value();
    if (!webhookUrl) {
      logger.warn("DISCORD_WEBHOOK_URL is not configured; skipping the sunday announcement");
      return;
    }
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({content: ANNOUNCE_MESSAGE}),
    });
    if (!response.ok) {
      logger.error(`discord webhook post failed with status ${response.status}`);
    }
  }
);

/**
 * 毎日1回、その日のカードを1枚紹介する投稿を#お知らせへ行う(GameDesign.md 26章)。
 * 直近30日以内に紹介したカードは候補から外し、完全ランダムで選ぶ。候補が尽きた
 * (プールの大半を直近30日で紹介し終えた)場合は、その回だけ除外条件を外して
 * 全カードから選び直す。
 */
exports.announceCardSpotlight = onSchedule(
  {schedule: "0 12 * * *", timeZone: "Asia/Tokyo", secrets: [DISCORD_WEBHOOK_URL]},
  async () => {
    const webhookUrl = DISCORD_WEBHOOK_URL.value();
    if (!webhookUrl) {
      logger.warn("DISCORD_WEBHOOK_URL is not configured; skipping the card spotlight");
      return;
    }
    const db = admin.firestore();
    // プールの枚数(今のところ70枚)は少ないため、全件読んでこちら側でフィルタする
    // (Architecture.md 10.14節。複合インデックスを要する範囲クエリを組まない)。
    const historySnapshot = await db.collection("bot_spotlight_history").get();
    const now = Date.now();
    const recentlyShown = new Set();
    historySnapshot.forEach((doc) => {
      const lastShown = doc.data().last_shown || 0;
      if (now - lastShown < SPOTLIGHT_COOLDOWN_MS) recentlyShown.add(doc.id);
    });
    let candidates = cardsData.cards.filter((c) => !recentlyShown.has(c.id));
    if (candidates.length === 0) candidates = cardsData.cards;

    const card = candidates[Math.floor(Math.random() * candidates.length)];
    await db.collection("bot_spotlight_history").doc(card.id).set({last_shown: now});

    const embeds = buildCardEmbeds(card);
    embeds[0].title = `【今日のカード】${embeds[0].title}`;
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({embeds}),
    });
    if (!response.ok) {
      logger.error(`discord webhook post failed with status ${response.status}`);
    }
  }
);

/**
 * Discordスラッシュコマンドの受け口(GameDesign.md 26章)。常駐するBotプロセス
 * (Gateway接続)は持たず、DiscordのInteractions Endpoint URL(HTTPS方式)で受ける。
 */
exports.discordInteractions = onRequest(
  {secrets: [DISCORD_PUBLIC_KEY]},
  async (req, res) => {
    const signature = req.get("X-Signature-Ed25519");
    const timestamp = req.get("X-Signature-Timestamp");
    const publicKey = DISCORD_PUBLIC_KEY.value();
    if (!signature || !timestamp || !publicKey || !req.rawBody) {
      res.status(401).send("invalid request");
      return;
    }
    const isValid = await verifyKey(req.rawBody, signature, timestamp, publicKey);
    if (!isValid) {
      res.status(401).send("invalid request signature");
      return;
    }

    const body = req.body;
    if (body.type === InteractionType.PING) {
      res.json({type: InteractionResponseType.PONG});
      return;
    }

    if (body.type === InteractionType.APPLICATION_COMMAND) {
      const name = body.data && body.data.name;
      const db = admin.firestore();
      switch (name) {
        case "card":
          res.json(handleCardCommand(body));
          return;
        case "link":
          res.json(await handleLinkCommand(body, db));
          return;
        case "profile":
          res.json(await handleProfileCommand(body, db));
          return;
        case "deck":
          // 3秒以内にACK(defer)を返し、画像の生成が終わってから追送する
          // (Architecture.md 10.14節)。res.json() の後も await で処理を続けることで、
          // Cloud Functionsのインスタンスがフォローアップの送信前に終了しないようにする。
          res.json(deferDeckResponse());
          await sendDeckFollowup(body, db);
          return;
        default:
          break;
      }
    }

    // 未対応のインタラクション種別・コマンド。
    res.json({
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: {flags: 64, content: "未対応のコマンドです"},
    });
  }
);
