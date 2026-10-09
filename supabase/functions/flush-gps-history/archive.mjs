export const QUEUE_KEY = "gps:history:queue";
export const PROCESSING_KEY = "gps:history:processing";
export const LOCK_KEY = "gps:history:archive-lock";
const RETENTION_MS = 14 * 24 * 60 * 60 * 1000;

// Keep claimed points until R2 acknowledges them; resume after interruption.
export const CLAIM_SCRIPT = `
if redis.call('GET', KEYS[3]) ~= ARGV[1] then return false end
local pending = redis.call('LRANGE', KEYS[2], 0, -1)
if #pending > 0 then return pending end
local batch = redis.call('LRANGE', KEYS[1], -tonumber(ARGV[2]), -1)
if #batch == 0 then return {} end
for i = #batch, 1, -1 do redis.call('RPUSH', KEYS[2], batch[i]) end
redis.call('LTRIM', KEYS[1], 0, -#batch - 1)
return redis.call('LRANGE', KEYS[2], 0, -1)
`;
export const ACK_SCRIPT = `
if redis.call('GET', KEYS[2]) ~= ARGV[1] then return 0 end
redis.call('DEL', KEYS[1])
return 1
`;
export const RELEASE_SCRIPT = `
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
end
return 0
`;

export async function flushGpsHistory({ redis, archive, now = Date.now,
  createToken = () => crypto.randomUUID(), batchSize = 500 }) {
  const token = createToken();
  const acquired = await redis(["SET", LOCK_KEY, token, "NX", "EX", 180]);
  if (acquired !== "OK") return { ok: true, archived: 0, busy: true };
  try {
    const raw = await redis(["EVAL", CLAIM_SCRIPT, 3,
      QUEUE_KEY, PROCESSING_KEY, LOCK_KEY, token,
      Math.min(5000, Math.max(1, batchSize))]);
    if (!Array.isArray(raw)) throw new Error("GPS archive lock lost");
    if (raw.length === 0) return { ok: true, archived: 0, queue_empty: true };
    const timestamp = now();
    const points = raw.map((value) => normalizePoint(value, timestamp)).filter(Boolean);
    const discarded = raw.length - points.length;
    let stored = { objects: [] };
    if (points.length > 0) {
      const digest = await crypto.subtle.digest("SHA-256",
        new TextEncoder().encode(JSON.stringify(raw)));
      const batchId = [...new Uint8Array(digest)]
        .map((byte) => byte.toString(16).padStart(2, "0")).join("");
      stored = await archive({ points, batch_id: batchId });
      if (!Array.isArray(stored?.objects) || stored.objects.length === 0) {
        throw new Error("R2 did not acknowledge GPS objects");
      }
    }
    const acknowledged = await redis([
      "EVAL", ACK_SCRIPT, 2, PROCESSING_KEY, LOCK_KEY, token]);
    if (acknowledged !== 1) throw new Error("GPS archive lock lost");
    return { ok: true, archived: points.length, discarded,
      objects: stored.objects.length,
      queue_remaining: await redis(["LLEN", QUEUE_KEY]) };
  } finally {
    // Redis outages leave the batch intact; the lock expires automatically.
    try { await redis(["EVAL", RELEASE_SCRIPT, 1, LOCK_KEY, token]); } catch { /* retry later */ }
  }
}

function normalizePoint(raw, now) {
  try {
    const point = typeof raw === "string" ? JSON.parse(raw) : raw;
    const createdAt = Date.parse(point?.created_at);
    const lat = Number(point?.lat);
    const lng = Number(point?.lng);
    if (!/^[a-zA-Z0-9_-]{1,128}$/.test(point?.driver_id ?? "") ||
      !/^[a-zA-Z0-9_-]{1,128}$/.test(point?.order_id ?? "") ||
      point?.lat == null || point?.lng == null ||
      !Number.isFinite(lat) || !Number.isFinite(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180 ||
      !Number.isFinite(createdAt) || createdAt < now - RETENTION_MS ||
      createdAt > now + 5 * 60 * 1000) return null;
    return { driver_id: point.driver_id, user_id: point.user_id ?? null,
      order_id: point.order_id, lat, lng, heading: point.heading ?? null,
      speed: point.speed ?? null, is_active: true,
      created_at: new Date(createdAt).toISOString() };
  } catch { return null; }
}

export function createGpsArchiveHandler({ getEnv, fetcher = fetch, now = Date.now, log = console }) {
  return async (request) => {
    if (request.method === "OPTIONS") return json(null, 204);
    if (request.method !== "POST" && request.method !== "GET") {
      return json({ error: "Method not allowed" }, 405);
    }
    if (!isAuthorized(request, getEnv)) return json({ error: "Unauthorized" }, 401);
    try {
      // Check dependencies before claiming any queue items.
      const redisUrl = requiredEnv(getEnv, "UPSTASH_REDIS_REST_URL");
      const redisToken = requiredEnv(getEnv, "UPSTASH_REDIS_REST_TOKEN");
      const gatewayUrl = requiredEnv(getEnv, "R2_GATEWAY_URL").replace(/\/$/, "");
      const ingestSecret = requiredEnv(getEnv, "R2_GPS_INGEST_SECRET");
      const result = await flushGpsHistory({ now,
        redis: async (command) => {
          const response = await fetcher(redisUrl, { method: "POST",
            signal: AbortSignal.timeout(15000),
            headers: { Authorization: `Bearer ${redisToken}`, "Content-Type": "application/json" },
            body: JSON.stringify(command) });
          if (!response.ok) throw new Error(`Redis HTTP ${response.status}`);
          const data = await response.json();
          if (data.error) throw new Error(`Redis: ${data.error}`);
          return data.result;
        },
        archive: async (body) => {
          const response = await fetcher(`${gatewayUrl}/v1/gps/chunks`, {
            method: "POST", signal: AbortSignal.timeout(45000),
            headers: { "Content-Type": "application/json", "x-gps-ingest-secret": ingestSecret },
            body: JSON.stringify(body) });
          if (!response.ok) throw new Error(`R2 gateway HTTP ${response.status}`);
          return response.json();
        },
      });
      log.info("[GpsArchive]", JSON.stringify(result));
      return json(result);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      log.error("[GpsArchive]", message);
      return json({ error: message }, 500);
    }
  };
}

function isAuthorized(request, getEnv) {
  const bearer = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  const matches = (name, value) => {
    const expected = getEnv(name)?.trim();
    if (!expected || !value || expected.length !== value.length) return false;
    let difference = 0;
    for (let i = 0; i < expected.length; i++) difference |= expected.charCodeAt(i) ^ value.charCodeAt(i);
    return difference === 0;
  };
  return matches("SUPABASE_SERVICE_ROLE_KEY", bearer) ||
    matches("SUPABASE_SERVICE_ROLE_KEY", request.headers.get("apikey")) ||
    matches("CRON_SECRET", request.headers.get("x-cron-secret")) ||
    matches("R2_GPS_INGEST_SECRET", request.headers.get("x-gps-ingest-secret"));
}
function requiredEnv(getEnv, name) {
  const value = getEnv(name)?.trim();
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
function json(body, status = 200) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization,apikey,content-type,x-cron-secret,x-gps-ingest-secret" } });
}
