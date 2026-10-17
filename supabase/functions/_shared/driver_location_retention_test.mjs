import assert from "node:assert/strict";
import test from "node:test";
import { cleanupOfflineDriverLocations } from "./driver_location_cleanup.mjs";
import {
  CLEANUP_KEY,
  GEO_KEY,
  LOC_PREFIX,
  OFFLINE_PREFIX,
  OFFLINE_RETENTION_MS,
  scheduleOfflineLocation,
  writeLatestDriverLocation,
} from "./driver_location_retention.mjs";
import { driverRedisFixture } from "./test_helpers/driver_redis_fixture.mjs";

const start = Date.parse("2026-10-12T09:00:00Z");
const id = "driver-user-1";
function fixture() {
  const f = driverRedisFixture();
  let timestamp = start;
  const state = { isAvailable: false, hasActiveOrder: false };
  const write = (extra = {}) =>
    writeLatestDriverLocation({
      redis: f.redis,
      userId: id,
      location: { lat: 10.8, lng: 106.7, updated_at: timestamp },
      isAvailable: state.isAvailable,
      now: timestamp,
      hasActiveOrder: async () => state.hasActiveOrder,
      ...extra,
    });
  const cleanup = (extra = {}) =>
    cleanupOfflineDriverLocations({
      redis: f.redis,
      now: () => timestamp,
      loadStates: async () => new Map([[id, state]]),
      ...extra,
    });
  return {
    ...f,
    state,
    write,
    cleanup,
    time: (ms) => {
      timestamp = start + ms;
    },
  };
}

test("OFF GPS remains until 30 minutes, then both latest and GEO are removed", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS - 1);
  assert.equal((await f.cleanup()).deleted, 0);
  assert.ok(f.values.has(LOC_PREFIX + id));
  f.time(OFFLINE_RETENTION_MS);
  assert.equal((await f.cleanup()).deleted, 1);
  assert.equal(f.values.has(LOC_PREFIX + id), false);
  assert.equal(f.zset(GEO_KEY).has(id), false);
});

test("the deadline starts at OFF, even when the last GPS was much earlier", async () => {
  const f = fixture();
  f.values.set(
    LOC_PREFIX + id,
    JSON.stringify({ updated_at: start - 7200000 }),
  );
  f.zset(GEO_KEY).set(id, 106.7);
  await scheduleOfflineLocation(f.redis, id, start);
  f.time(OFFLINE_RETENTION_MS - 1);
  assert.equal((await f.cleanup()).deleted, 0);
});

test("GPS and repeated OFF requests do not restart the first deadline", async () => {
  const f = fixture();
  await f.write();
  const original = f.values.get(OFFLINE_PREFIX + id);
  f.time(29 * 60000);
  await f.write();
  await scheduleOfflineLocation(f.redis, id, start + 29 * 60000);
  assert.equal(f.values.get(OFFLINE_PREFIX + id), original);
  f.time(OFFLINE_RETENTION_MS);
  assert.equal((await f.cleanup()).deleted, 1);
});

test("an active delivery or return is kept, then removed after the order ends", async () => {
  const f = fixture();
  await f.write();
  f.state.hasActiveOrder = true;
  f.time(OFFLINE_RETENTION_MS);
  assert.equal((await f.cleanup()).kept_active, 1);
  assert.equal(await f.write(), true);
  assert.equal(JSON.parse(f.values.get(OFFLINE_PREFIX + id)).offline_at, start);
  f.state.hasActiveOrder = false;
  f.time(OFFLINE_RETENTION_MS + 60000);
  assert.equal((await f.cleanup()).deleted, 1);
});

test("going Online cancels OFF cleanup and restores latest GPS", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  await f.cleanup();
  f.state.isAvailable = true;
  await f.write();
  assert.equal(f.values.has(OFFLINE_PREFIX + id), false);
  assert.equal(f.zset(CLEANUP_KEY).has(id), false);
  assert.ok(f.values.has(LOC_PREFIX + id));
});

test("cron cancels a missing Online notification after verifying DB state", async () => {
  const f = fixture();
  await f.write();
  f.state.isAvailable = true;
  f.time(OFFLINE_RETENTION_MS);
  assert.equal((await f.cleanup()).cancelled_online, 1);
  assert.ok(f.values.has(LOC_PREFIX + id));
});

test("a delayed GPS retry cannot resurrect expired OFF coordinates", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  await f.cleanup();
  assert.equal(await f.write(), false);
  await f.cleanup();
  assert.equal(f.values.has(LOC_PREFIX + id), false);
  assert.equal(f.zset(CLEANUP_KEY).has(id), false);
});

test("an in-flight active GPS racing after cleanup is queued for another DB check", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  await f.write({
    hasActiveOrder: async () => {
      await f.cleanup();
      return true; // The earlier DB check saw an active order just before it ended.
    },
  });
  assert.ok(f.values.has(LOC_PREFIX + id));
  assert.ok(f.zset(CLEANUP_KEY).has(id));
  assert.equal((await f.cleanup()).deleted, 1);
});

test("a stale timer after missed Online/OFF notifications starts a conservative new deadline", async () => {
  const f = fixture();
  await scheduleOfflineLocation(f.redis, id, start - OFFLINE_RETENTION_MS);
  f.values.set(
    LOC_PREFIX + id,
    JSON.stringify({
      lat: 10.8,
      lng: 106.7,
      is_available: true,
      updated_at: start,
    }),
  );
  f.zset(GEO_KEY).set(id, 106.7);
  assert.equal((await f.cleanup()).deleted, 0);
  assert.equal(JSON.parse(f.values.get(OFFLINE_PREFIX + id)).offline_at, start);
  assert.equal(JSON.parse(f.values.get(LOC_PREFIX + id)).is_available, false);
  f.time(OFFLINE_RETENTION_MS);
  assert.equal((await f.cleanup()).deleted, 1);
});

test("an old cleanup cannot delete GPS from a new Online then OFF session", async () => {
  const f = fixture();
  await f.write();
  const oldMarker = f.values.get(OFFLINE_PREFIX + id);
  f.time(OFFLINE_RETENTION_MS);
  const result = await f.cleanup({
    loadStates: async () => {
      f.state.isAvailable = true;
      await f.write();
      f.state.isAvailable = false;
      await scheduleOfflineLocation(f.redis, id, start + OFFLINE_RETENTION_MS);
      return new Map([[id, f.state]]);
    },
  });
  assert.equal(result.deleted, 0);
  assert.ok(f.values.has(LOC_PREFIX + id));
  assert.notEqual(f.values.get(OFFLINE_PREFIX + id), oldMarker);
});

test("a GPS arriving during the DB check is kept for the next cleanup run", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  const result = await f.cleanup({
    loadStates: async () => {
      f.state.hasActiveOrder = true;
      await f.write();
      return new Map([[id, { isAvailable: false, hasActiveOrder: false }]]);
    },
  });
  assert.equal(result.deleted, 0);
  assert.ok(f.values.has(LOC_PREFIX + id));
});

test("a failed DB/active-order check never deletes GPS", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  await assert.rejects(
    f.cleanup({
      loadStates: async () => {
        throw new Error("DB down");
      },
    }),
    /DB down/,
  );
  await assert.rejects(
    f.write({
      hasActiveOrder: async () => {
        throw new Error("DB down");
      },
    }),
    /DB down/,
  );
  assert.ok(f.values.has(LOC_PREFIX + id));
});

test("unknown/deleted driver profiles are not treated as safe to delete", async () => {
  const f = fixture();
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  assert.equal(
    (await f.cleanup({ loadStates: async () => new Map() })).deleted,
    0,
  );
  assert.ok(f.values.has(LOC_PREFIX + id));
});

test("legacy OFF cache entries start a conservative deadline on first cron observation", async () => {
  const f = fixture();
  f.values.set(LOC_PREFIX + id, "old-gps");
  f.zset(GEO_KEY).set(id, 106.7);
  assert.equal((await f.cleanup()).deleted, 0);
  assert.equal(JSON.parse(f.values.get(OFFLINE_PREFIX + id)).offline_at, start);
  f.time(OFFLINE_RETENTION_MS);
  assert.equal((await f.cleanup()).deleted, 1);
});

test("cleanup never touches GPS history, R2 metadata, or PG sync gates", async () => {
  const f = fixture();
  for (
    const key of [
      "gps:history:queue",
      "gps:history:processing",
      "gps:pg_touch:profile-1",
    ]
  ) {
    f.values.set(key, "keep-history");
  }
  await f.write();
  f.time(OFFLINE_RETENTION_MS);
  await f.cleanup();
  for (
    const key of [
      "gps:history:queue",
      "gps:history:processing",
      "gps:pg_touch:profile-1",
    ]
  ) {
    assert.equal(f.values.get(key), "keep-history");
  }
});
