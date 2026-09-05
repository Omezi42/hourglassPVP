/**
 * 砂時計アリーナのDiscord連携(GameDesign.md 25章 / Architecture.md 10.13節)。
 *
 * この作品はバックエンドに自前サーバーを立てない方針(GameDesign.md 10章)だが、
 * 「日曜日になった瞬間に、誰も対局していなくても告知する」ことはクライアント発火の
 * 仕組みでは実現できない。ここではFirebaseのサーバーレス関数(Cloud Functions)と
 * その定期実行(Cloud Scheduler)だけを足し、常駐するプロセスは持たない。
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {verifyKey, InteractionType, InteractionResponseType} = require("discord-interactions");
const logger = require("firebase-functions/logger");

// Botトークン・公開鍵と同じ扱いで、リポジトリへは一切コミットしない。
// `firebase functions:secrets:set DISCORD_WEBHOOK_URL` / `DISCORD_PUBLIC_KEY` で設定する。
const DISCORD_WEBHOOK_URL = defineSecret("DISCORD_WEBHOOK_URL");
const DISCORD_PUBLIC_KEY = defineSecret("DISCORD_PUBLIC_KEY");

const ANNOUNCE_MESSAGE =
  "☀️ 本日は日曜イベント開催中!\n" +
  "ランダムマッチで手に入る砂金が、日付が変わるまで2倍になります。";

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
 * 将来のDiscordスラッシュコマンドの受け口(GameDesign.md 25章)。常駐するBot
 * プロセス(Gateway接続)は持たず、DiscordのInteractions Endpoint URL(HTTPS方式)で
 * 受ける。現時点ではコマンドを1つも持たないため、Discordの検証で送られてくる
 * PING(type 1)へPONG(type 1)を返すだけにする。コマンドを足すときはここへ
 * `InteractionType.APPLICATION_COMMAND` の分岐を1つ加える。
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

    // 未対応のインタラクション種別。将来スラッシュコマンドを足すときはここへ分岐を足す。
    res.json({
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: {content: "未対応のコマンドです"},
    });
  }
);
