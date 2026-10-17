export const OFFLINE_RETENTION_MS = 30 * 60 * 1000;
export const GEO_KEY = "drivers:geo";
export const LOC_PREFIX = "driver:loc:";
export const OFFLINE_PREFIX = "driver:offline:";
export const CLEANUP_KEY = "drivers:offline:cleanup";

// Keep the first OFF event on retries; GPS never moves this deadline.
export const SCHEDULE_OFFLINE_SCRIPT = `
local markers = {}
for i = 2, #KEYS, 2 do
  local user = ARGV[i]
  local marker = redis.call('GET', KEYS[i])
  local was_online = false
  local latest = redis.call('GET', KEYS[i + 1])
  if latest then
    local valid, location = pcall(cjson.decode, latest)
    if valid and type(location) == 'table' and location.is_available == true then
      was_online = true
      location.is_available = false
      redis.call('SET', KEYS[i + 1], cjson.encode(location))
    end
  end
  -- Repair a missed Online/OFF notification after an outage conservatively.
  if not marker or was_online then
    marker = ARGV[i + 1]
    redis.call('SET', KEYS[i], marker)
    redis.call('ZADD', KEYS[1], ARGV[1], user)
  end
  table.insert(markers, marker)
end
return markers
`;

export const NEW_OFFLINE_SCRIPT = `
redis.call('SET', KEYS[1], ARGV[2])
redis.call('ZADD', KEYS[2], ARGV[3], ARGV[1])
local latest = redis.call('GET', KEYS[3])
if latest then
  local valid, location = pcall(cjson.decode, latest)
  if valid and type(location) == 'table' and location.is_available == true then
    location.is_available = false
    redis.call('SET', KEYS[3], cjson.encode(location))
  end
end
return ARGV[2]
`;

// Compare the observed generation so an old request cannot undo a newer OFF.
export const WRITE_LOCATION_SCRIPT = `
local marker = redis.call('GET', KEYS[1]) or ''
if marker ~= ARGV[2] then return 0 end
if ARGV[3] == '1' then
  redis.call('DEL', KEYS[1])
  redis.call('ZREM', KEYS[2], ARGV[1])
elseif marker ~= '' then
  local due = cjson.decode(marker).due_at
  if tonumber(due) <= tonumber(ARGV[4]) and ARGV[5] ~= '1' then return 0 end
  -- A delivery checked just before it ended can race with cleanup. Always
  -- schedule a fresh DB check if that in-flight active GPS restores the cache.
  if tonumber(due) <= tonumber(ARGV[4]) and ARGV[5] == '1' then
    redis.call('ZADD', KEYS[2], 'NX', ARGV[4], ARGV[1])
  end
end
redis.call('GEOADD', KEYS[3], ARGV[6], ARGV[7], ARGV[1])
redis.call('SET', KEYS[4], ARGV[8])
return 1
`;

export const CLEANUP_LOCATION_SCRIPT = `
if redis.call('GET', KEYS[1]) ~= ARGV[2] then return 0 end
local due = redis.call('ZSCORE', KEYS[2], ARGV[1])
if not due or tonumber(due) > tonumber(ARGV[3]) then return 0 end
if ARGV[4] == 'online' then
  redis.call('DEL', KEYS[1])
  redis.call('ZREM', KEYS[2], ARGV[1])
elseif ARGV[4] == 'active' then
  redis.call('ZADD', KEYS[2], tonumber(ARGV[3]) + 60000, ARGV[1])
else
  if (redis.call('GET', KEYS[4]) or '') ~= ARGV[5] then return 0 end
  redis.call('DEL', KEYS[4])
  redis.call('ZREM', KEYS[3], ARGV[1])
  redis.call('ZREM', KEYS[2], ARGV[1])
  -- Keep the marker, without GPS, to reject delayed retries until Online.
end
return 1
`;

// One Redis round trip for a bounded batch, with the same per-driver CAS checks.
export const CLEANUP_LOCATION_BATCH_SCRIPT = `
local function cleanup(KEYS, ARGV)
${CLEANUP_LOCATION_SCRIPT}
end
local results = {}
for i = 1, #KEYS, 4 do
  local j = ((i - 1) / 4) * 5 + 1
  table.insert(results, cleanup(
    {KEYS[i], KEYS[i + 1], KEYS[i + 2], KEYS[i + 3]},
    {ARGV[j], ARGV[j + 1], ARGV[j + 2], ARGV[j + 3], ARGV[j + 4]}))
end
return results
`;

export function redisResult(value) {
  return value && typeof value === "object" && "result" in value
    ? value.result
    : value;
}

export async function scheduleOfflineLocation(
  redis,
  userId,
  now = Date.now(),
  { reset = false } = {},
) {
  if (reset) {
    const marker = JSON.stringify({
      offline_at: now,
      due_at: now + OFFLINE_RETENTION_MS,
      token: crypto.randomUUID(),
    });
    return redisResult(
      await redis([
        "EVAL",
        NEW_OFFLINE_SCRIPT,
        3,
        OFFLINE_PREFIX + userId,
        CLEANUP_KEY,
        LOC_PREFIX + userId,
        userId,
        marker,
        now + OFFLINE_RETENTION_MS,
      ]),
    );
  }
  return (await scheduleOfflineLocations(redis, [userId], now))[0];
}

export async function scheduleOfflineLocations(
  redis,
  userIds,
  now = Date.now(),
) {
  if (!userIds.length) return [];
  const due = now + OFFLINE_RETENTION_MS;
  const args = userIds.flatMap((
    id,
  ) => [
    id,
    JSON.stringify({
      offline_at: now,
      due_at: due,
      token: crypto.randomUUID(),
    }),
  ]);
  return redisResult(
    await redis([
      "EVAL",
      SCHEDULE_OFFLINE_SCRIPT,
      userIds.length * 2 + 1,
      CLEANUP_KEY,
      ...userIds.flatMap((id) => [OFFLINE_PREFIX + id, LOC_PREFIX + id]),
      due,
      ...args,
    ]),
  );
}

export async function writeLatestDriverLocation(
  {
    redis,
    userId,
    location,
    isAvailable,
    hasActiveOrder = async () => false,
    now = Date.now(),
  },
) {
  // OFF scheduling also repairs old clients / missed notifications, without
  // extending a valid existing OFF deadline on each GPS sample.
  const marker = isAvailable
    ? redisResult(await redis(["GET", OFFLINE_PREFIX + userId])) ?? ""
    : await scheduleOfflineLocation(redis, userId, now);
  const expired = marker && JSON.parse(marker).due_at <= now;
  const active = !isAvailable && expired ? await hasActiveOrder() : false;
  return redisResult(
    await redis([
      "EVAL",
      WRITE_LOCATION_SCRIPT,
      4,
      OFFLINE_PREFIX + userId,
      CLEANUP_KEY,
      GEO_KEY,
      LOC_PREFIX + userId,
      userId,
      marker,
      isAvailable ? "1" : "0",
      now,
      active ? "1" : "0",
      location.lng,
      location.lat,
      JSON.stringify(location),
    ]),
  ) === 1;
}
