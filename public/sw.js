// Honeybun service worker: makes the app open offline.
// Pages and code are fetched fresh when online (so updates show right away) and served from cache when offline.
const CACHE = "honeybun-v5";
const SHELL = ["/", "/index.html", "/app.js", "/i18n.js", "/boot.js", "/icon-192.png", "/apple-touch-icon.png", "/favicon-32.png", "/manifest.webmanifest"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin || url.pathname.startsWith("/api/")) return;
  const isPage = e.request.mode === "navigate";
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(isPage ? "/" : e.request, copy)); }
        return res;
      })
      .catch(() => caches.match(isPage ? "/" : e.request).then((r) => r || caches.match("/")))
  );
});
