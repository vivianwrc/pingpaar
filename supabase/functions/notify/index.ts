// Pingpaar – Benachrichtigung „Herz bekommen“
// Supabase Edge Function „notify“. Schickt dem Partner eine Push-Nachricht aufs Handy.
// Braucht die Secrets VAPID_PUBLIC und VAPID_PRIVATE (siehe ANLEITUNG.md).
// Kommt ohne Zusatzbibliotheken aus: Web Push (RFC 8291 + VAPID) mit WebCrypto.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const enc = new TextEncoder();
const b64u = (b) => btoa(String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64u = (s) => { s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '='; return Uint8Array.from(atob(s), (c) => c.charCodeAt(0)); };
const cat = (...a) => { const o = new Uint8Array(a.reduce((n, x) => n + x.length, 0)); let i = 0; for (const x of a) { o.set(x, i); i += x.length; } return o; };

async function hkdf(salt, ikm, info, len) {
  const k = await crypto.subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt, info }, k, len * 8));
}

// Inhalt für ein Abo verschlüsseln (aes128gcm, RFC 8188/8291)
export async function encrypt(payload, p256dh, authSecret) {
  const ua = unb64u(p256dh), auth = unb64u(authSecret);
  const eph = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const as = new Uint8Array(await crypto.subtle.exportKey('raw', eph.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', ua, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const secret = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, eph.privateKey, 256));
  const ikm = await hkdf(auth, secret, cat(enc.encode('WebPush: info\0'), ua, as), 32);
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, enc.encode('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdf(salt, ikm, enc.encode('Content-Encoding: nonce\0'), 12);
  const key = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, key, cat(enc.encode(payload), new Uint8Array([2]))));
  return cat(salt, new Uint8Array([0, 0, 16, 0]), new Uint8Array([as.length]), as, ct);
}

// VAPID-Ausweis für den Push-Dienst
export async function vapidHeader(endpoint, pub, priv, subject) {
  const p = unb64u(pub);
  const key = await crypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256', d: priv, x: b64u(p.slice(1, 33)), y: b64u(p.slice(33, 65)), ext: true },
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const head = b64u(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const body = b64u(enc.encode(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: subject })));
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(head + '.' + body));
  return `vapid t=${head}.${body}.${b64u(sig)}, k=${pub}`;
}

export async function sendPush(sub, payload, pub, priv, subject) {
  const body = await encrypt(payload, sub.p256dh, sub.auth);
  return fetch(sub.endpoint, {
    method: 'POST',
    headers: { 'Content-Encoding': 'aes128gcm', 'Content-Type': 'application/octet-stream', TTL: '86400', Urgency: 'high', Authorization: await vapidHeader(sub.endpoint, pub, priv, subject) },
    body,
  });
}

const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

if (typeof Deno !== 'undefined') Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const apikey = req.headers.get('apikey') || Deno.env.get('SUPABASE_ANON_KEY') || '';
    const authz = req.headers.get('Authorization') || '';
    const pub = Deno.env.get('VAPID_PUBLIC'), priv = Deno.env.get('VAPID_PRIVATE');
    if (!pub || !priv) return json({ error: 'vapid_missing' }, 500);
    const input = await req.json().catch(() => ({}));
    if (input.kind !== 'heart') return json({ error: 'kind' }, 400);
    const rpc = (name, args) => fetch(`${url}/rest/v1/rpc/${name}`, { method: 'POST', headers: { apikey, Authorization: authz, 'Content-Type': 'application/json' }, body: JSON.stringify(args || {}) });
    // Nur die Geräte des eigenen Partners – die Datenbank prüft das anhand des Logins
    const r = await rpc('partner_push_subs');
    if (!r.ok) return json({ error: 'auth' }, 401);
    const subs = await r.json();
    const name = String(input.name || 'Dein Schatz').slice(0, 40);
    const payload = JSON.stringify({ title: 'Pingpaar', body: `${name} hat dir Herzen geschickt 💗`, tag: 'heart' });
    let sent = 0;
    await Promise.all(subs.map(async (s) => {
      try {
        const res = await sendPush(s, payload, pub, priv, 'https://vivianwrc.github.io/pingpaar/');
        if (res.status === 404 || res.status === 410) await rpc('drop_partner_push', { ep: s.endpoint });
        else if (res.ok) sent++;
        else console.log('push', res.status, await res.text());
      } catch (e) { console.log('push error', String(e)); }
    }));
    return json({ sent, devices: subs.length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
