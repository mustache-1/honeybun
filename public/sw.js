// Honeybun service worker: fresh online, cached offline.
const CACHE = "honeybun-v7";
const SHELL = ["/", "/index.html", "/app.js", "/i18n.js", "/boot.js", "/hb-v7.css", "/icon-192.png", "/apple-touch-icon.png", "/favicon-32.png", "/manifest.webmanifest"];

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
  if (isPage) {
    e.respondWith(fetch(e.request).then(async (res) => {
      if (!res.ok) return res;
      let html = await res.text();
      if (!html.includes('/hb-v7.css')) html = html.replace('</head>', '<link rel="stylesheet" href="/hb-v7.css?v=7"></head>');
      const out = new Response(html, {status:res.status,statusText:res.statusText,headers:res.headers});
      caches.open(CACHE).then((c) => c.put("/", out.clone()));
      return out;
    }).catch(() => caches.match("/")));
    return;
  }
  e.respondWith(fetch(e.request).then((res) => {
    if (res.ok) { const copy=res.clone(); caches.open(CACHE).then((c)=>c.put(e.request,copy)); }
    return res;
  }).catch(()=>caches.match(e.request)));
});
