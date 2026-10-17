import assert from "node:assert/strict";
import test from "node:test";
import { changeDriverLocationPresence } from "./presence.mjs";
import {
  CLEANUP_KEY,
  LOC_PREFIX,
  OFFLINE_PREFIX,
  OFFLINE_RETENTION_MS,
  scheduleOfflineLocation,
} from "../_shared/driver_location_retention.mjs";
import { driverRedisFixture } from "../_shared/test_helpers/driver_redis_fixture.mjs";

function fixture() {
  const f = driverRedisFixture();
  const driver = {
    id: "profile-1",
    user_id: "user-1",
    is_available: true,
    current_lat: 10.8,
    current_lng: 106.7,
    location_updated_at: "2026-10-12T09:00:00Z",
  };
  const change = (event, extra = {}) =>
    changeDriverLocationPresence({
      event,
      redis: f.redis,
      now: () => 1000,
      loadDriver: async () => ({ ...driver }),
      goOffline: async () => {
        driver.is_available = false;
      },
      log: { error() {} },
      ...extra,
    });
  return { ...f, driver, change };
}

test("OFF commits the existing business RPC before starting the server deadline", async () => {
  const f = fixture();
  f.values.set(
    LOC_PREFIX + "user-1",
    JSON.stringify({ ...f.driver, updated_at: "old-gps" }),
  );
  assert.equal((await f.change("offline")).cache_synced, true);
  assert.equal(f.driver.is_available, false);
  assert.equal(
    JSON.parse(f.values.get(LOC_PREFIX + "user-1")).is_available,
    false,
  );
  assert.equal(
    JSON.parse(f.values.get(LOC_PREFIX + "user-1")).updated_at,
    "old-gps",
  );
  assert.equal(
    JSON.parse(f.values.get(OFFLINE_PREFIX + "user-1")).due_at,
    1000 + OFFLINE_RETENTION_MS,
  );
});

test("RPC rejection cannot schedule cleanup", async () => {
  const f = fixture();
  await assert.rejects(
    f.change("offline", {
      goOffline: async () => {
        throw new Error("Forbidden");
      },
    }),
    /Forbidden/,
  );
  assert.equal(f.calls.length, 0);
});

test("Online requires successful PIN RPC state before touching Redis", async () => {
  const f = fixture();
  f.driver.is_available = false;
  await assert.rejects(f.change("online"), /verify the Online PIN/);
  assert.equal(f.calls.length, 0);
});

test("successful Online cancels cleanup and uses the new PG location", async () => {
  const f = fixture();
  await scheduleOfflineLocation(f.redis, "user-1", 0);
  await f.change("online");
  assert.equal(f.values.has(OFFLINE_PREFIX + "user-1"), false);
  assert.equal(f.zset(CLEANUP_KEY).has("user-1"), false);
  assert.equal(JSON.parse(f.values.get(LOC_PREFIX + "user-1")).lat, 10.8);
});

test("a Redis outage preserves successful OFF and reports cache synchronization failure", async () => {
  const f = fixture();
  const result = await f.change("offline", {
    redis: async () => {
      throw new Error("Redis down");
    },
  });
  assert.deepEqual(result, {
    ok: true,
    is_available: false,
    cache_synced: false,
  });
  assert.equal(f.driver.is_available, false);
});

test("clients cannot use an unsupported event to change availability", async () => {
  const f = fixture();
  await assert.rejects(f.change("force-online"), /Invalid presence event/);
  assert.equal(f.driver.is_available, true);
});

test("a new Online-to-OFF transition replaces an old timer even if Online cache sync was missed", async () => {
  const f = fixture();
  await scheduleOfflineLocation(f.redis, "user-1", -OFFLINE_RETENTION_MS);
  await f.change("offline");
  assert.equal(
    JSON.parse(f.values.get(OFFLINE_PREFIX + "user-1")).offline_at,
    1000,
  );
  await f.change("offline", { now: () => 10000 });
  assert.equal(
    JSON.parse(f.values.get(OFFLINE_PREFIX + "user-1")).offline_at,
    1000,
  );
});
