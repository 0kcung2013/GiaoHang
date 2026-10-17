import assert from "node:assert/strict";
import test from "node:test";
import type { RedisCommand } from "./history_queue.ts";
import { syncLatestDriverLocation } from "./latest_location_sync.ts";

function fakeRedis() {
  let now = 0;
  const keys = new Map<string, { value: unknown; expires: number }>();
  const redis: RedisCommand = async ([command, ...args]) => {
    if (command === "SET") {
      const [key, value, ...options] = args;
      const current = keys.get(String(key));
      if (options.includes("NX") && current && current.expires > now) {
        return { result: null };
      }
      const seconds = Number(options[options.indexOf("EX") + 1]);
      keys.set(String(key), { value, expires: now + seconds });
      return { result: "OK" };
    }
    if (command === "EVAL") {
      const [, , key, token] = args;
      if (keys.get(String(key))?.value !== token) return { result: 0 };
      keys.delete(String(key));
      return { result: 1 };
    }
    throw new Error(`Unexpected ${command}`);
  };
  return {
    redis,
    keys,
    at: (seconds: number) => {
      now = seconds;
    },
  };
}

test("5s GPS requests produce one PG write every 10s", async () => {
  const fake = fakeRedis();
  const writes: number[] = [];
  for (const second of [0, 5, 10, 15, 20]) {
    fake.at(second);
    await syncLatestDriverLocation(fake.redis, "profile", async () => {
      writes.push(second);
      return true;
    });
  }
  assert.deepEqual(writes, [0, 10, 20]);
});

test("concurrent navigation and foreground producers share the PG cadence", async () => {
  const fake = fakeRedis();
  let writes = 0;
  const update = async () => {
    writes++;
    return true;
  };
  const results = await Promise.all([
    syncLatestDriverLocation(fake.redis, "profile", update),
    syncLatestDriverLocation(fake.redis, "profile", update),
  ]);
  assert.deepEqual(results, [true, false]);
  assert.equal(writes, 1);
  assert.equal(
    await syncLatestDriverLocation(fake.redis, "another-profile", update),
    true,
  );
  assert.equal(writes, 2);
});

test("critical arrival sync bypasses cadence and starts a new 10s window", async () => {
  const fake = fakeRedis();
  const writes: number[] = [];
  for (const second of [0, 3, 5, 12, 13]) {
    fake.at(second);
    await syncLatestDriverLocation(fake.redis, "profile", async () => {
      writes.push(second);
      return true;
    }, { force: second === 3 });
  }
  assert.deepEqual(writes, [0, 3, 13]);
});

test("failed PG update can be retried immediately", async () => {
  const fake = fakeRedis();
  assert.equal(
    await syncLatestDriverLocation(fake.redis, "profile", async () => false),
    false,
  );
  assert.equal(
    await syncLatestDriverLocation(fake.redis, "profile", async () => true),
    true,
  );
});

test("throwing PG update releases its claim", async () => {
  const fake = fakeRedis();
  await assert.rejects(
    syncLatestDriverLocation(fake.redis, "profile", async () => {
      throw new Error("PG unavailable");
    }),
    /PG unavailable/,
  );
  assert.equal(
    await syncLatestDriverLocation(fake.redis, "profile", async () => true),
    true,
  );
});

test("failure cannot remove the window established by a critical successor", async () => {
  const fake = fakeRedis();
  await syncLatestDriverLocation(fake.redis, "profile", async () => {
    await syncLatestDriverLocation(fake.redis, "profile", async () => true, {
      force: true,
      token: "arrival",
    });
    return false;
  }, { token: "older" });
  assert.equal(fake.keys.get("gps:pg_touch:profile")?.value, "arrival");
  assert.equal(
    await syncLatestDriverLocation(fake.redis, "profile", async () => true),
    false,
  );
});
