// Pages Functions の共通部品(Architecture.md 10.21節)。

// 共有リンクの中身は変わらないため、Cloudflare のキャッシュへ長く残す。
const CACHE_SECONDS = 365 * 24 * 60 * 60;

/** 上流(Cloud Functions)の応答をキャッシュして返す。成功した応答だけを残す。 */
export async function fetchCached(context, url) {
  const cache = caches.default;
  const key = new Request(url);
  const hit = await cache.match(key);
  if (hit) return hit;
  const upstream = await fetch(url);
  if (!upstream.ok) return new Response(null, {status: upstream.status});
  const response = new Response(upstream.body, upstream);
  response.headers.set("Cache-Control", `public, max-age=${CACHE_SECONDS}, immutable`);
  context.waitUntil(cache.put(key, response.clone()));
  return response;
}

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);
}
