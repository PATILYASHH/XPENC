// XPENC web's offline cache, registered by index.html.
//
// Every same-origin GET under this folder is answered from the network when
// there is one — so a new release never mixes with pieces of an old one —
// and from this cache when there isn't, which is what lets XPENC web open
// with no connection after the first visit. It fetches nothing the page
// didn't ask for, and talks to nothing but this site.
//
// It must never be worse than no worker at all: if the cache itself fails
// (storage full, a damaged profile), requests simply go to the network.
const CACHE = 'xpenc-web-shell-v1';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        // Only this worker's own old caches — never anything else of the
        // site's.
        const names = await caches.keys();
        await Promise.all(
          names
            .filter((n) => n.startsWith('xpenc-web-shell-') && n !== CACHE)
            .map((n) => caches.delete(n)),
        );
      } catch (_) {
        // Old caches linger; nothing breaks.
      }
      await self.clients.claim();
    })(),
  );
});

async function remember(request, response) {
  try {
    const cache = await caches.open(CACHE);
    await cache.put(request, response);
  } catch (_) {
    // Not cached this time — the next visit online tries again.
  }
}

async function recall(request, scope) {
  try {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(request, { ignoreSearch: true });
    if (hit) return hit;
    // A deep link the app routes itself: the page, not a 404.
    if (request.mode === 'navigate') {
      const folder = new URL('./', self.location).pathname;
      return (
        (await cache.match(scope)) ||
        (await cache.match(folder)) ||
        (await cache.match(`${folder}index.html`))
      );
    }
  } catch (_) {
    // Fall through to the network error.
  }
  return undefined;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  // `/web` on xpenc.in (see index.html), `/web/` wherever the page keeps
  // its trailing slash.
  const scope = new URL(self.registration.scope).pathname;
  if (request.method !== 'GET') return;
  if (url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith(scope)) return;

  event.respondWith(
    (async () => {
      try {
        const response = await fetch(request);
        if (response.ok) event.waitUntil(remember(request, response.clone()));
        return response;
      } catch (offline) {
        const cached = await recall(request, scope);
        if (cached) return cached;
        throw offline;
      }
    })(),
  );
});
