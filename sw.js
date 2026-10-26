// Pingpaar – Offline-Speicher für schnelles Öffnen
// App-Dateien kommen sofort aus dem Speicher; im Hintergrund wird die neueste Version geladen
// und beim nächsten Öffnen angezeigt. Datenbank, Karte und Suche laufen immer übers Internet.
const CACHE = 'pingpaar-v1';
const CORE = ['./', './index.html', './config.js', './vendor/supabase.js', './vendor/leaflet.css', './manifest.webmanifest', './icon-192.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return; // Supabase, Karte, Suche: nie zwischenspeichern
  e.respondWith(caches.open(CACHE).then(async c => {
    const key = req.mode === 'navigate' ? './index.html' : req;
    const hit = await c.match(key, { ignoreSearch: req.mode === 'navigate' });
    const net = fetch(req).then(r => { if (r.ok) c.put(key, r.clone()); return r; }).catch(() => hit);
    return hit || net;
  }));
});
