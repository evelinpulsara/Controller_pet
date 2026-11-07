/*
 * Service Worker de PetTracker: un "proxy" entre la app y la red.
 *
 * Qué hace:
 *  - Guarda en caché las imágenes del mapa (OpenStreetMap) que ya viste,
 *    para que el mapa siga viéndose aunque te quedes sin internet.
 *  - Guarda los sonidos de alarma para que suenen sin conexión.
 *
 * Qué NO hace (a propósito): no guarda los archivos de la app (HTML/JS),
 * para que siempre cargues la versión más nueva y nunca una vieja.
 */
const TILE_CACHE = 'pettracker-tiles-v1';
const ASSET_CACHE = 'pettracker-assets-v1';
const MAX_TILES = 600;

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Borra cachés viejas de versiones anteriores de este Service Worker.
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

