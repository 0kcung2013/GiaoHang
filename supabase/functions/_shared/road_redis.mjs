export function createRoadRedis(getEnv, fetcher = fetch) {
  const url = getEnv('UPSTASH_REDIS_REST_URL');
  const token = getEnv('UPSTASH_REDIS_REST_TOKEN');
  if (!url || !token) throw new Error('ROAD_REDIS_UNAVAILABLE');
  return async function command(args) {
    const response = await fetcher(url, { method: 'POST', signal: AbortSignal.timeout(5000),
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(args) });
    if (!response.ok) throw new Error('ROAD_REDIS_UNAVAILABLE');
    const data = await response.json();
    if (data.error) throw new Error('ROAD_REDIS_UNAVAILABLE');
    return data.result;
  };
}

export function roadRouteOptions(redis, osrmUrl) {
  return { ...(osrmUrl ? { osrmUrl } : {}), cache: {
    get: async key => { const value = await redis(['GET', key]); if (!value) return null;
      try { return JSON.parse(value); } catch { return null; } },
    set: async (key, value, ttl) => { await redis(['SET', key, JSON.stringify(value), 'EX', ttl]); },
  }, beforeRequest: async () => {
    if (await redis(['SET', 'road:osrm:rate', '1', 'NX', 'PX', 1000])) return;
    await new Promise(resolve => setTimeout(resolve, 1050));
    if (!await redis(['SET', 'road:osrm:rate', '1', 'NX', 'PX', 1000])) throw new Error('ROAD_ROUTING_BUSY');
  } };
}

const RELEASE = "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end";

export async function withRoadLease(redis, action, key = 'road:dispatch:lease') {
  const token = crypto.randomUUID();
  if (!await redis(['SET', key, token, 'NX', 'EX', 55])) return { ok: true, busy: true };
  const assertOwner = async () => {
    if (await redis(['GET', key]) !== token) throw new Error('ROAD_DISPATCH_LEASE_LOST');
  };
  try { return await action(assertOwner); }
  finally { try { await redis(['EVAL', RELEASE, 1, key, token]); } catch { /* TTL releases the lease after an outage. */ } }
}
