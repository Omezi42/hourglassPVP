/**
 * 攻略サイトの「デッキを紹介する」(GameDesign.md 32章 / Architecture.md 10.21節)。
 *
 * サイトが送る IDトークンで本人を確かめ、Discordの連携から紹介者を引いて、
 * Discordから紹介したときと同じ `postIntro()` で #デッキ紹介 へ流す。
 */

const {postIntro} = require("./discord_deck_intro");

// 押し間違いの連投でチャンネルが埋まらないように(GameDesign.md 32章)。
const COOLDOWN_SECONDS = 60;
const ALLOWED_ORIGIN = "*";

function bearerToken(req) {
  const header = String(req.get("Authorization") || "");
  return header.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
}

async function discordUserIdOf(db, uid) {
  const linked = await db.collection("discord_links").where("uid", "==", uid).limit(1).get();
  return linked.empty ? "" : linked.docs[0].id;
}

/** 1分に1回まで。通してよければ時刻を書き、true を返す。 */
async function takeCooldown(db, uid) {
  const ref = db.collection("deck_intro_cooldowns").doc(uid);
  const now = Math.floor(Date.now() / 1000);
  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    if (doc.exists && now - Number(doc.data().last_at || 0) < COOLDOWN_SECONDS) return false;
    transaction.set(ref, {last_at: now});
    return true;
  });
}

async function handleWikiDeckIntro(req, res, db, auth, config) {
  res.set("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({message: "POST だけを受け付けます"});
    return;
  }
  let uid = "";
  try {
    uid = (await auth.verifyIdToken(bearerToken(req))).uid;
  } catch (error) {
    res.status(401).json({message: "ログインが切れました。もう一度ログインしてください"});
    return;
  }
  const discordUserId = await discordUserIdOf(db, uid);
  if (!discordUserId) {
    res.status(403).json({message: "Discordの #デッキを紹介する で「アカウント連携」を押すと紹介できます"});
    return;
  }
  const body = req.body || {};
  const deckIndex = Number(body.index);
  if (!Number.isInteger(deckIndex)) {
    res.status(400).json({message: "デッキを選んでください"});
    return;
  }
  if (!(await takeCooldown(db, uid))) {
    res.status(429).json({message: "少し待ってからもう一度"});
    return;
  }
  const error = await postIntro(db, config, {discordUserId, uid, deckIndex, comment: body.comment});
  if (error) {
    res.status(400).json({message: error});
    return;
  }
  res.json({message: "#デッキ紹介に投稿しました"});
}

module.exports = {handleWikiDeckIntro};
