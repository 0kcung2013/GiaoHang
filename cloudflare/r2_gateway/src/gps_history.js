import { currentRole, requireRestRow, requireUser } from './supabase_auth.js';
import { httpError, json, readJson, safeSegment } from './http.js';

export async function readGpsHistory(request, env) {
  const user = await requireUser(request, env);
  const role = await currentRole(user.id, request, env);
  if (!['support', 'admin'].includes(role)) throw httpError(403, 'Support access required');
  const body = await readJson(request);
  const orderId = safeSegment(body.orderId);
  await requireRestRow(`orders?id=eq.${encodeURIComponent(orderId)}&select=id`, request, env);
  const cursor = body.cursor;
  if (cursor != null && (typeof cursor !== 'string' || cursor.length > 4096)) {
    throw httpError(400, 'Invalid cursor');
  }
  const page = await env.GPS_BUCKET.list({
    prefix: `orders/${orderId}/gps/`, limit: 20, ...(cursor ? { cursor } : {}),
  });
  const now = Date.now();
  const cutoff = now - 14 * 86400000;
  const points = [];
  let unavailableChunks = 0;
  for (const entry of page.objects) {
    if (!entry.key.startsWith(`orders/${orderId}/gps/`)) {
      throw httpError(403, 'Invalid archive scope');
    }
  }
  // Overlap R2 I/O, but keep decompression and memory use bounded. Four reads
  // suffice to avoid a serial round-trip for every tiny archived chunk.
  for (let offset = 0; offset < page.objects.length; offset += 4) {
    const batch = await Promise.all(page.objects.slice(offset, offset + 4)
      .map(entry => readChunk(entry.key, env, orderId, cutoff, now)));
    for (const chunk of batch) {
      points.push(...chunk.points);
      unavailableChunks += chunk.unavailable;
    }
  }
  points.sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at));
  const response = json({points, unavailableChunks, nextCursor: page.truncated ? page.cursor : null});
  response.headers.set('Cache-Control', 'no-store');
  return response;
}

async function readChunk(key, env, orderId, cutoff, now) {
  const object = await env.GPS_BUCKET.get(key);
  const points = [];
  if (!object) return { points, unavailable: 1 };
  try {
    const text = await new Response(object.body.pipeThrough(new DecompressionStream('gzip'))).text();
    for (const line of text.split('\n').filter(Boolean)) {
      const point = JSON.parse(line);
      const time = Date.parse(point.created_at);
      if (point.order_id !== orderId || !Number.isFinite(time) || time < cutoff || time > now ||
          !Number.isFinite(point.lat) || !Number.isFinite(point.lng) ||
          Math.abs(point.lat) > 90 || Math.abs(point.lng) > 180) continue;
      points.push({lat: point.lat, lng: point.lng, created_at: point.created_at, driver_id: point.driver_id});
    }
    return { points, unavailable: 0 };
  } catch {
    return { points, unavailable: 1 };
  }
}
