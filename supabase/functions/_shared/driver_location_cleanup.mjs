import {
  CLEANUP_KEY,
  CLEANUP_LOCATION_BATCH_SCRIPT,
  GEO_KEY,
  LOC_PREFIX,
  OFFLINE_PREFIX,
  redisResult,
  scheduleOfflineLocations,
} from "./driver_location_retention.mjs";

const SCAN_CURSOR_KEY = "drivers:offline:scan-cursor";
const BATCH_SIZE = 100;

export async function cleanupOfflineDriverLocations(
  { redis, loadStates, now = Date.now },
) {
  const timestamp = now();
  // Gradually seed existing cache entries / OFF events from older clients.
  // Unknown OFF times start conservatively at first observation, never earlier.
  const cursor = redisResult(await redis(["GET", SCAN_CURSOR_KEY])) ?? "0";
  const scan = redisResult(
    await redis(["ZSCAN", GEO_KEY, cursor, "COUNT", BATCH_SIZE]),
  );
  if (!Array.isArray(scan) || !Array.isArray(scan[1])) {
    throw new Error("Invalid GPS scan");
  }
  const scannedIds = scan[1].filter((_, index) => index % 2 === 0);
  const dueIds = redisResult(
    await redis([
      "ZRANGE",
      CLEANUP_KEY,
      "-inf",
      timestamp,
      "BYSCORE",
      "LIMIT",
      0,
      BATCH_SIZE,
    ]),
  );
  if (!Array.isArray(dueIds)) throw new Error("Invalid GPS cleanup schedule");
  const snapshots = new Map();
  const raw = dueIds.length
    ? redisResult(
      await redis([
        "MGET",
        ...dueIds.flatMap((id) => [OFFLINE_PREFIX + id, LOC_PREFIX + id]),
      ]),
    )
    : [];
  if (!Array.isArray(raw)) throw new Error("Invalid GPS cleanup snapshot");
  for (const [index, userId] of dueIds.entries()) {
    snapshots.set(userId, {
      marker: raw[index * 2],
      location: raw[index * 2 + 1] ?? "",
    });
  }
  const ids = [...new Set([...scannedIds, ...dueIds])];
  // A failed database read aborts cleanup; it must never imply "no active order".
  const states = ids.length ? await loadStates(ids) : new Map();
  const offlineIds = scannedIds.filter((id) =>
    states.has(id) && !states.get(id).isAvailable
  );
  await scheduleOfflineLocations(redis, offlineIds, timestamp);
  await redis(["SET", SCAN_CURSOR_KEY, String(scan[0])]);
  const result = {
    checked: dueIds.length,
    deleted: 0,
    kept_active: 0,
    cancelled_online: 0,
    observed_offline: offlineIds.length,
  };
  const operations = [];
  for (const userId of dueIds) {
    const snapshot = snapshots.get(userId);
    const state = states.get(userId);
    if (!snapshot.marker || !state) continue;
    const action = state.isAvailable
      ? "online"
      : state.hasActiveOrder
      ? "active"
      : "delete";
    operations.push({ userId, snapshot, action });
  }
  if (!operations.length) return result;
  const appliedResults = redisResult(
    await redis([
      "EVAL",
      CLEANUP_LOCATION_BATCH_SCRIPT,
      operations.length * 4,
      ...operations.flatMap((
        { userId },
      ) => [
        OFFLINE_PREFIX + userId,
        CLEANUP_KEY,
        GEO_KEY,
        LOC_PREFIX + userId,
      ]),
      ...operations.flatMap((
        { userId, snapshot, action },
      ) => [userId, snapshot.marker, timestamp, action, snapshot.location]),
    ]),
  );
  if (!Array.isArray(appliedResults)) {
    throw new Error("Invalid GPS cleanup acknowledgement");
  }
  for (const [index, { action }] of operations.entries()) {
    const applied = appliedResults[index];
    if (applied !== 1) continue;
    if (action === "online") result.cancelled_online++;
    else if (action === "active") result.kept_active++;
    else result.deleted++;
  }
  return result;
}
