// Honeybun service worker: makes the app open offline.
// Pages and code are fetched fresh when online (so updates show right away) and served from cache when offline.
const CACHE = "honeybun-v28";
const SHELL = ["/", "/index.html", "/app.js", "/i18n.js", "/boot.js", "/theme.js", "/halloween.js", "/halloween.css", "/icon-192.png", "/apple-touch-icon.png", "/favicon-32.png", "/manifest.webmanifest"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
// Push: the server sends an empty ping, and we ask it what to say (so nothing sensitive travels through the push service).
self.addEventListener("push", (e) => {
  e.waitUntil((async () => {
    let n = { title: "Honeybun", body: "Bun has something for you 🐰", url: "/" };
    try { const r = await fetch("/api/push/latest", { credentials: "same-origin", cache: "no-store" }); if (r.ok) n = await r.json(); } catch {}
    await self.registration.showNotification(n.title, { body: n.body, icon: "/icon-192.png", badge: "/icon-192.png", tag: "honeybun", renotify: true, data: { url: n.url || "/" } });
  })());
});
self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || "/";
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
    const c = list.find((w) => "focus" in w);
    if (c) { c.navigate(url).catch(() => {}); return c.focus(); }
    return self.clients.openWindow(url);
  }));
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
