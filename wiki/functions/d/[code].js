// 共有リンク /d/{code}(GameDesign.md 32章 / Architecture.md 10.21節)。
// クローラーは JS を動かさないため、ページの head へデッキごとの OGP を差し込んで返す。
import {escapeHtml, fetchCached} from "../_shared.js";

const DECK_SHARE = "https://us-central1-hourglasspvp.cloudfunctions.net/deckShare";
const PARAM = /^(\d{8})(?:\.(png|json))?$/;
const SITE_NAME = "砂時計アリーナ 攻略データベース";

export async function onRequestGet(context) {
  const match = PARAM.exec(context.params.code);
  if (!match) return new Response("not found", {status: 404});
  const [, code, format] = match;
  if (format) return fetchCached(context, `${DECK_SHARE}?code=${code}&format=${format}`);
  return deckPage(context, code);
}

async function deckPage(context, code) {
  const deckResponse = await fetchCached(context, `${DECK_SHARE}?code=${code}&format=json`);
  const deck = deckResponse.ok ? await deckResponse.json() : null;
  const origin = new URL(context.request.url).origin;
  const title = deck ? `${deck.name}(デッキコード ${code})` : "見つかりませんでした";
  const meta = [
    ["og:type", "website"],
    ["og:site_name", SITE_NAME],
    ["og:title", title],
    ["og:url", `${origin}/d/${code}`],
    ["og:description", deck ? "砂時計アリーナのデッキ。開くと30枚の中身を見られます" : ""],
  ];
  if (deck) meta.push(["og:image", `${origin}/d/${code}.png`]);
  const tags = meta.map(([key, value]) => `<meta property="${key}" content="${escapeHtml(value)}">`).join("") +
    `<meta name="twitter:card" content="${deck ? "summary_large_image" : "summary"}">`;

  const page = await context.env.ASSETS.fetch(new URL("/", context.request.url));
  const rewritten = new HTMLRewriter()
    .on("head", {element: (head) => head.prepend('<base href="/">', {html: true})})
    .on("head", {element: (head) => head.append(tags, {html: true})})
    .on("title", {element: (node) => node.setInnerContent(`${title} | ${SITE_NAME}`)})
    .transform(page);
  return new Response(rewritten.body, {status: deck ? 200 : 404, headers: rewritten.headers});
}
