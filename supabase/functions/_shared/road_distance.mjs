export const AUTOMATIC_ROAD_LIMIT = 2000;
export const FREE_PICK_ROAD_LIMIT = 3000;
const TABLE_BATCH_SIZE = 48;
const DEFAULT_OSRM_URL = 'https://router.project-osrm.org';

export class RoadRoutingUnavailable extends Error {
  constructor() { super('ROAD_ROUTING_UNAVAILABLE'); }
}

export async function rankDriversByRoadDistance(candidates, pickup, options = {}) {
  const target = point(pickup);
  const ranked = [];
  for (let offset = 0; offset < candidates.length; offset += TABLE_BATCH_SIZE) {
    const batch = candidates.slice(offset, offset + TABLE_BATCH_SIZE);
    const origins = batch.map(point);
    const table = await loadTable([...origins, target], origins.map((_, i) => i), [origins.length], options);
    batch.forEach((candidate, i) => {
      const quote = cell(table, i, 0, origins[i], target);
      if (quote && quote.distance_meters <= AUTOMATIC_ROAD_LIMIT) ranked.push({ ...candidate, ...quote });
    });
  }
  return ranked.sort((a, b) => a.distance_meters - b.distance_meters ||
    a.duration_seconds - b.duration_seconds || String(a.user_id).localeCompare(String(b.user_id)));
}

export async function quoteFreePickOrders(driver, orders, options = {}) {
  const origin = point(driver);
  const result = [];
  for (let offset = 0; offset < orders.length; offset += TABLE_BATCH_SIZE) {
    const batch = orders.slice(offset, offset + TABLE_BATCH_SIZE);
    const targets = batch.map(order => point({ lat: order.pickup_lat, lng: order.pickup_lng }));
    const table = await loadTable([origin, ...targets], [0], targets.map((_, i) => i + 1), options);
    batch.forEach((order, i) => {
      const quote = cell(table, 0, i, origin, targets[i]);
      if (quote && quote.distance_meters > AUTOMATIC_ROAD_LIMIT && quote.distance_meters <= FREE_PICK_ROAD_LIMIT) {
        result.push({ ...order, pickup_road_distance_meters: quote.distance_meters,
          pickup_road_duration_seconds: quote.duration_seconds, pickup_road_quoted_at: quote.quoted_at,
          pickup_road_origin_lat: origin.lat, pickup_road_origin_lng: origin.lng });
      }
    });
  }
  return result.sort((a, b) => a.pickup_road_distance_meters - b.pickup_road_distance_meters || String(a.id).localeCompare(String(b.id)));
}

export async function quotePickupRoute(driver, pickup, options = {}) {
  const origin = point(driver);
  const target = point(pickup);
  return cell(await loadTable([origin, target], [0], [1], options), 0, 0, origin, target);
}

async function loadTable(points, sources, destinations, {
  fetcher = fetch, now = Date.now, cache, beforeRequest, osrmUrl = DEFAULT_OSRM_URL,
} = {}) {
  const coords = points.map(p => p.lng + ',' + p.lat).join(';');
  const url = osrmUrl.replace(/\/$/, '') + '/table/v1/driving/' + coords +
    '?sources=' + sources.join(';') + '&destinations=' + destinations.join(';') + '&annotations=distance,duration';
  try {
    const key = cache ? await cacheKey(url) : null;
    if (cache) {
      const cached = await cache.get(key);
      if (cached && now() - Date.parse(cached.quoted_at) >= 0 && now() - Date.parse(cached.quoted_at) <= 20000) {
        validateTable(cached, sources.length, destinations.length);
        return cached;
      }
    }
    if (beforeRequest) await beforeRequest();
    const response = await fetcher(url, { signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw new RoadRoutingUnavailable();
    const table = { ...await response.json(), quoted_at: new Date(now()).toISOString() };
    validateTable(table, sources.length, destinations.length);
    if (cache) await cache.set(key, table, 20);
    return table;
  } catch {
    throw new RoadRoutingUnavailable();
  }
}

function validateTable(table, rows, columns) {
  if (table.code !== 'Ok' || !Number.isFinite(Date.parse(table.quoted_at)) ||
    !Array.isArray(table.distances) || !Array.isArray(table.durations) ||
    table.distances.length !== rows || table.durations.length !== rows) throw new RoadRoutingUnavailable();
  for (let i = 0; i < rows; i++) {
    if (table.distances[i]?.length !== columns || table.durations[i]?.length !== columns) throw new RoadRoutingUnavailable();
    for (let j = 0; j < columns; j++) {
      const d = table.distances[i][j], t = table.durations[i][j];
      if (d === null && t === null) continue;
      if (typeof d !== 'number' || typeof t !== 'number' || !Number.isFinite(d) || !Number.isFinite(t) || d < 0 || t < 0) {
        throw new RoadRoutingUnavailable();
      }
    }
  }
}

function cell(table, row, column, origin, target) {
  if (table.distances[row][column] === null) return null;
  if ((table.sources?.[row]?.distance ?? 0) > 100 || (table.destinations?.[column]?.distance ?? 0) > 100) return null;
  return { distance_meters: table.distances[row][column], duration_seconds: table.durations[row][column],
    origin_lat: origin.lat, origin_lng: origin.lng, pickup_lat: target.lat, pickup_lng: target.lng,
    quoted_at: table.quoted_at };
}

function point(value) {
  const lat = value.lat ?? value.current_lat;
  const lng = value.lng ?? value.current_lng;
  if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng) ||
    Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new RoadRoutingUnavailable();
  return { lat, lng };
}

async function cacheKey(url) {
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(url)));
  return 'road:table:v1:' + [...bytes].map(b => b.toString(16).padStart(2, '0')).join('');
}
