/**
 * リプレイの共有(GameDesign.md 32章 / Architecture.md 10.21節)。
 *
 * - `wikiReplayShare`: 攻略サイトが IDトークン付きで呼ぶ。共有の状態を見る・発行する・取り消す
 * - `replayShare`: 共有リンク `/r/{id}` の中身(JSON)と埋め込みの画像(PNG)。誰でも読める
 *
 * `replay_shares/{id}` = `{match_id, uid, created_at}`。読み書きするのは Functions だけ。
 */

const crypto = require("crypto");
const {loadImage} = require("@napi-rs/canvas");
const {renderReplayCard} = require("./replay_card_canvas");
const {loadWikiArt} = require("./deck_share");
const cardsData = require("./data/cards.json");

const SHARES = "replay_shares";
const RECORDS = "match_records";
const ID_LENGTH = 10;
const ID_PATTERN = /^[A-Za-z0-9]{10}$/;
const ID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const CREATE_RETRIES = 3;
const WIKI_ICON_BASE = "https://sunadokei-arena-wiki.pages.dev/icons/";
// 相手は共有に同意していないため、名前とアイコンを伏せる(GameDesign.md 32章)。
const HIDDEN_NAME = "対戦相手";
const DEFAULT_ICON = "sand";
const DEFAULT_TITLE = "novice";
const GUEST_NAME = "ゲスト";
// 埋め込みの「主なカード」の枚数(コストの高い順。マイページのデッキの呼び名と同じ)。
const MAIN_CARDS = 3;
const ALLOWED_ORIGIN = "*";

const CARDS_BY_ID = new Map(cardsData.cards.map((card) => [card.id, card]));

function bearerToken(req) {
  const header = String(req.get("Authorization") || "");
  return header.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
}

function newShareId() {
  const bytes = crypto.randomBytes(ID_LENGTH);
  return Array.from(bytes, (byte) => ID_ALPHABET[byte % ID_ALPHABET.length]).join("");
}

async function findShare(db, matchId, uid) {
  const found = await db.collection(SHARES).where("match_id", "==", matchId).where("uid", "==", uid).limit(1).get();
  return found.empty ? null : found.docs[0];
}

async function createShare(db, matchId, uid) {
  for (let attempt = 0; attempt < CREATE_RETRIES; attempt += 1) {
    const id = newShareId();
    try {
      await db.collection(SHARES).doc(id).create({match_id: matchId, uid, created_at: Math.floor(Date.now() / 1000)});
      return id;
    } catch (error) {
      // 同じIDが既にあった。引き直す。
    }
  }
  return "";
}

/** POST `{action: "status"|"share"|"revoke", match_id}`。返すのは `{id}`(共有していなければ空)。 */
async function handleWikiReplayShare(req, res, db, auth) {
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
  const body = req.body || {};
  const matchId = String(body.match_id || "");
  const record = matchId ? await db.collection(RECORDS).doc(matchId).get() : null;
  if (!record || !record.exists || ![record.get("player_a"), record.get("player_b")].includes(uid)) {
    res.status(404).json({message: "見つかりませんでした"});
    return;
  }
  const existing = await findShare(db, matchId, uid);
  if (body.action === "revoke") {
    if (existing) await existing.ref.delete();
    res.json({id: ""});
    return;
  }
  if (body.action === "share" && !existing) {
    const id = await createShare(db, matchId, uid);
    if (!id) {
      res.status(500).json({message: "共有できませんでした"});
      return;
    }
    res.json({id});
    return;
  }
  res.json({id: existing ? existing.id : ""});
}

function profileOf(doc) {
  const data = doc.exists ? doc.data() : {};
  return {
    name: data.display_name || GUEST_NAME,
    icon: data.icon_id || DEFAULT_ICON,
    title: data.title_id || DEFAULT_TITLE,
  };
}

/** 共有された1局を、共有した人を手前・相手を伏せた形で返す。無ければ null。 */
async function readSharedReplay(db, id) {
  if (!ID_PATTERN.test(id)) return null;
  const share = await db.collection(SHARES).doc(id).get();
  if (!share.exists) return null;
  const {match_id: matchId, uid} = share.data();
  const recordDoc = await db.collection(RECORDS).doc(matchId).get();
  if (!recordDoc.exists) return null;
  const record = recordDoc.data();
  const view = record.player_a === uid ? "a" : "b";
  const foe = view === "a" ? "b" : "a";
  const sharer = profileOf(await db.collection("players").doc(uid).get());
  return {
    build: record.build || "",
    finished_at: Number(record.finished_at) || 0,
    turns: Number(record.turns) || 0,
    winner: record.winner,
    end_reason: record.end_reason,
    view,
    players: {[view]: sharer, [foe]: {name: HIDDEN_NAME, icon: DEFAULT_ICON, title: DEFAULT_TITLE}},
    deck_a: record.deck_a || [],
    deck_b: record.deck_b || [],
    seed: Number(record.seed) || 0,
    actions: record.actions || [],
  };
}

/** コストの高い順に、同じカードを1回として数枚。 */
function mainCards(ids) {
  return [...new Set(ids.map(String))]
    .map((cardId) => CARDS_BY_ID.get(cardId))
    .filter(Boolean)
    .sort((a, b) => b.cost - a.cost || a.pool_index - b.pool_index)
    .slice(0, MAIN_CARDS);
}

async function loadIcon(iconId) {
  try {
    const response = await fetch(`${WIKI_ICON_BASE}${encodeURIComponent(iconId)}.webp`);
    if (!response.ok) return null;
    return await loadImage(Buffer.from(await response.arrayBuffer()));
  } catch (error) {
    return null;
  }
}

async function renderSharedReplayImage(replay) {
  const sides = [replay.view, replay.view === "a" ? "b" : "a"];
  const draw = replay.end_reason === "draw";
  const players = await Promise.all(sides.map(async (side) => ({
    name: replay.players[side].name,
    icon: await loadIcon(replay.players[side].icon),
    result: draw ? "draw" : (replay.winner === side ? "win" : "lose"),
    cards: mainCards(side === "a" ? replay.deck_a : replay.deck_b),
  })));
  return renderReplayCard({players, turns: replay.turns, loadArt: loadWikiArt});
}

/** `?id=…&format=json|png`。取り消されたらすぐ見えなくなるよう、どちらもキャッシュさせない。 */
async function handleReplayShare(req, res, db) {
  res.set("Cache-Control", "no-store");
  const replay = await readSharedReplay(db, String(req.query.id || ""));
  if (!replay) {
    res.status(404).json({ok: false});
    return;
  }
  if (req.query.format === "png") {
    res.type("png").send(await renderSharedReplayImage(replay));
    return;
  }
  res.json(replay);
}

module.exports = {handleWikiReplayShare, handleReplayShare, readSharedReplay, mainCards};
