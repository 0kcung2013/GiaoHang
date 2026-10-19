import { currentRole, requireUser, restRows } from './supabase_auth.js';
import { httpError, json, readJson } from './http.js';

// Discover archives from actual R2 objects. No second index or database field.
// Pages can contain the same order; the client merges their date ranges.
export async function listGpsArchives(request, env) {
  const user = await requireUser(request, env);
  const role = await currentRole(user.id, request, env);
  if (!['support', 'admin'].includes(role)) throw httpError(403, 'Support access required');
  const { cursor } = await readJson(request);
  if (cursor != null && (typeof cursor !== 'string' || cursor.length > 4096)) {
    throw httpError(400, 'Invalid cursor');
  }
  const page = await env.GPS_BUCKET.list({
    prefix: 'orders/', limit: 500, ...(cursor ? { cursor } : {}),
  });
  const cutoffDay = new Date(Date.now() - 14 * 86400000).toISOString().slice(0, 10);
  const today = new Date().toISOString().slice(0, 10);
  const entries = new Map();
  for (const object of page.objects) {
    const match = /^orders\/([a-zA-Z0-9_-]{1,128})\/gps\/(\d{4})\/(\d{2})\/(\d{2})\/[^/]+\.jsonl\.gz$/.exec(object.key);
    if (!match) continue;
    const [, orderId, year, month, day] = match;
    const date = `${year}-${month}-${day}`;
    if (date < cutoffDay || date > today) continue;
    const entry = entries.get(orderId) ?? { orderId, firstDay: date, lastDay: date, chunks: 0 };
    entry.firstDay = entry.firstDay < date ? entry.firstDay : date;
    entry.lastDay = entry.lastDay > date ? entry.lastDay : date;
    entry.chunks++;
    entries.set(orderId, entry);
  }
  // Apply the caller's RLS before returning any order identifiers, even to staff.
  const allowed = new Set();
  const ids = [...entries.keys()];
  for (let offset = 0; offset < ids.length; offset += 50) {
    const batch = ids.slice(offset, offset + 50);
    const rows = await restRows(`orders?select=id&id=in.(${batch.join(',')})&limit=50`, request, env);
    for (const row of rows) allowed.add(row.id);
  }
  const response = json({
    archives: [...entries.values()].filter(entry => allowed.has(entry.orderId)),
    nextCursor: page.truncated ? page.cursor : null,
  });
  response.headers.set('Cache-Control', 'no-store');
  return response;
}
