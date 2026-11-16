const TILE_CACHE = 'pettracker-tiles-v1';
const ASSET_CACHE = 'pettracker-assets-v1';
const MAX_TILES = 600;

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keep = [TILE_CACHE, ASSET_CACHE];
    for (const name of await caches.keys()) {
      if (name.startsWith('pettracker-') && !keep.includes(name)) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (url.hostname === 'tile.openstreetmap.org') {
    event.respondWith(cacheFirst(req, TILE_CACHE, true));
    return;
  }
  if (url.origin === self.location.origin && url.pathname.includes('/sounds/')) {
    event.respondWith(cacheFirst(req, ASSET_CACHE, false));
  }
});

async function cacheFirst(req, cacheName, limit) {
  const cache = await caches.open(cacheName);
  const hit = await cache.match(req);
  if (hit) return hit;
  try {
    const res = await fetch(req);
    if (res.ok || res.type === 'opaque') {
      await cache.put(req, res.clone());
      if (limit) trim(cache);
    }
    return res;
  } catch (e) {
    return hit || Response.error();
  }
}

async function trim(cache) {
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - MAX_TILES; i++) await cache.delete(keys[i]);
}
