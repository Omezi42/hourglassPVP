// 共有リンク /r/{id}(GameDesign.md 32章 / Architecture.md 10.21節)。
// クローラーは JS を動かさないため、ページの head へ1局ごとの OGP を差し込んで返す。
// 共有は取り消せるため、中身は毎回 Cloud Functions に確かめる(画像だけはその後にキャッシュから返す)。
import {escapeHtml, fetchCached} from "../_shared.js";

const REPLAY_SHARE = "https://us-central1-hourglasspvp.cloudfunctions.net/replayShare";
const PARAM = /^([A-Za-z0-9]{10})(?:\.(png|json))?$/;
const SITE_NAME = "砂時計アリーナ 攻略データベース";
const RESULT_LABELS = {win: "勝ち", lose: "負け", draw: "引き分け"};

export async function onRequestGet(context) {
  const match = PARAM.exec(context.params.id);
  if (!match) return new Response("not found", {status: 404});
  const [, id, format] = match;
  const replay = await fetchReplay(id);
  if (format === "json") return replayJson(replay);
  if (format === "png") return replay ? fetchCached(context, `${REPLAY_SHARE}?id=${id}&format=png`) : new Response(null, {status: 404});
  return replayPage(context, id, replay);
}

async function fetchReplay(id) {
  const response = await fetch(`${REPLAY_SHARE}?id=${id}&format=json`);
  return response.ok ? response.json() : null;
}

function replayJson(replay) {
  return new Response(replay ? JSON.stringify(replay) : JSON.stringify({ok: false}), {
    status: replay ? 200 : 404,
    headers: {"Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store"},
  });
}

function sharerResult(replay) {
  if (replay.end_reason === "draw") return RESULT_LABELS.draw;
  return replay.winner === replay.view ? RESULT_LABELS.win : RESULT_LABELS.lose;
}

async function replayPage(context, id, replay) {
  const origin = new URL(context.request.url).origin;
  const title = replay ?
    `${replay.players[replay.view].name}の対局(${sharerResult(replay)}・${replay.turns}手)` :
    "見つかりませんでした";
  const meta = [
    ["og:type", "website"],
    ["og:site_name", SITE_NAME],
    ["og:title", title],
    ["og:url", `${origin}/r/${id}`],
    ["og:description", replay ? "砂時計アリーナのリプレイ。開くとその1局を再生します" : ""],
  ];
  if (replay) meta.push(["og:image", `${origin}/r/${id}.png`]);
  const tags = meta.map(([key, value]) => `<meta property="${key}" content="${escapeHtml(value)}">`).join("") +
    `<meta name="twitter:card" content="${replay ? "summary_large_image" : "summary"}">`;

  const page = await context.env.ASSETS.fetch(new URL("/", context.request.url));
  const rewritten = new HTMLRewriter()
    .on("head", {element: (head) => head.prepend('<base href="/">', {html: true})})
    .on("head", {element: (head) => head.append(tags, {html: true})})
    .on("title", {element: (node) => node.setInnerContent(`${title} | ${SITE_NAME}`)})
    .transform(page);
  return new Response(rewritten.body, {status: replay ? 200 : 404, headers: rewritten.headers});
}
