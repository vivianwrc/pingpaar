// Pingpaar – Offline-Speicher für schnelles Öffnen
// App-Dateien kommen sofort aus dem Speicher; im Hintergrund wird die neueste Version geladen
// und beim nächsten Öffnen angezeigt. Datenbank, Karte und Suche laufen immer übers Internet.
// Außerdem: Benachrichtigungen anzeigen (z. B. „… hat dir Herzen geschickt“).
const CACHE = 'pingpaar-v4';
const CORE = ['./', './index.html', './config.js', './vendor/supabase.js', './vendor/leaflet.css', './manifest.webmanifest', './icon-192.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE.map(u => new Request(u, { cache: 'no-cache' })))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return; // Supabase, Karte, Suche: nie zwischenspeichern
  if (url.pathname.endsWith('/pebble-rettung.html')) return; // Pebble-Rettungsseite: nie abfangen
  e.respondWith(caches.open(CACHE).then(async c => {
    const key = req.mode === 'navigate' ? './index.html' : req;
    const hit = await c.match(key, { ignoreSearch: req.mode === 'navigate' });
    const net = fetch(req, { cache: 'no-cache' }).then(r => { if (r.ok) c.put(key, r.clone()); return r; }).catch(() => hit);
    return hit || net;
  }));
});

self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { body: e.data ? e.data.text() : '' }; }
  e.waitUntil(self.registration.showNotification(d.title || 'Pingpaar', {
    body: d.body || '', tag: d.tag || 'pingpaar', renotify: true, icon: './icon-192.png', data: { url: './' },
  }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(ws => {
    for (const w of ws) if ('focus' in w) return w.focus();
    return self.clients.openWindow('./');
  }));
});
