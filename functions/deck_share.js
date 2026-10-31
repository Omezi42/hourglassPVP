/**
 * 共有リンク `/d/{code}` の中身(GameDesign.md 32章 / Architecture.md 10.21節)。
 * `deckcodes` はサインイン必須のため、攻略サイトの Pages Functions はここ経由で読む。
 */

const {loadImage} = require("@napi-rs/canvas");
const {renderDeckSheet} = require("./deck_sheet_canvas");
const {parseDeckText} = require("./discord_commands");

const WIKI_ART_BASE = "https://sunadokei-arena-wiki.pages.dev/art/";
const CODE_PATTERN = /^\d{8}$/;
const DEFAULT_NAME = "デッキ";
// 中身が変わらないため、Cloudflare 側でも長く残す(Architecture.md 10.21節)。
const CACHE_SECONDS = 365 * 24 * 60 * 60;

/** @return {Promise<?{code: string, name: string, cards: string}>} 読めないコードは null */
async function readDeckCode(db, code) {
  if (!CODE_PATTERN.test(code)) return null;
  const doc = await db.collection("deckcodes").doc(code).get();
  if (!doc.exists) return null;
  const data = doc.data();
  const cards = data.cards || "";
  if (parseDeckText(cards).length === 0) return null;
  return {code, name: data.name || DEFAULT_NAME, cards};
}

async function loadWikiArt(id) {
  const response = await fetch(`${WIKI_ART_BASE}${encodeURIComponent(id)}_thumb.webp`);
  if (!response.ok) return null;
  return loadImage(Buffer.from(await response.arrayBuffer()));
}

async function renderDeckCodeImage(deck) {
  return renderDeckSheet(parseDeckText(deck.cards), {name: deck.name, code: deck.code, loadArt: loadWikiArt});
}

/** `?code=12345678&format=json|png` */
async function handleDeckShare(req, res, db) {
  const code = String(req.query.code || "");
  const deck = await readDeckCode(db, code);
  if (!deck) {
    res.set("Cache-Control", "no-store");
    res.status(404).json({ok: false});
    return;
  }
  res.set("Cache-Control", `public, max-age=${CACHE_SECONDS}, immutable`);
  if (req.query.format === "png") {
    res.type("png").send(await renderDeckCodeImage(deck));
    return;
  }
  res.json(deck);
}

module.exports = {handleDeckShare, readDeckCode, renderDeckCodeImage, loadWikiArt};
