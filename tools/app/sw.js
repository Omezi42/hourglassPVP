// アプリ版(PWA)の service worker(Architecture.md 4.6節)。
// make_portal.py が __ENGINE__ を Godot の版に置き換えて build/app/sw.js を作る。
const CACHE = 'sunadokei-app-' + __ENGINE__;
const OFFLINE = './offline.html';
const CACHEABLE = /\.(wasm|js|png)$/;

self.addEventListener('install', (event) => {
	event.waitUntil(caches.open(CACHE).then((cache) => cache.add(OFFLINE)));
	self.skipWaiting();
});

self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
			.then(() => self.clients.claim())
	);
});

self.addEventListener('fetch', (event) => {
	const url = new URL(event.request.url);
	if (event.request.method !== 'GET' || url.origin !== self.location.origin) {
		return;
	}
	// 起動部は毎回ネットから取る。取れなければ通信できないことを知らせる。
	if (event.request.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('index.html')) {
		event.respondWith(fetch(event.request).catch(() => caches.open(CACHE).then((cache) => cache.match(OFFLINE))));
		return;
	}
	if (CACHEABLE.test(url.pathname)) {
		event.respondWith(
			caches.open(CACHE).then(async (cache) => {
				const hit = await cache.match(event.request);
				if (hit) {
					return hit;
				}
				const response = await fetch(event.request);
				if (response.ok) {
					cache.put(event.request, response.clone());
				}
				return response;
			})
		);
	}
});
