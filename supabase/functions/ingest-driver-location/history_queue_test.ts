import assert from "node:assert/strict";
import test from "node:test";

import {
  enqueueHistoryOnce,
  type GpsHistoryPayload,
  type RedisCommand,
} from "./history_queue.ts";

function createFakeRedis() {
  const locks = new Set<string>();
  const queue: string[] = [];

  const redis: RedisCommand = async (command) => {
    const [name, key, value] = command;

    if (name === "SET") {
      const lockKey = String(key);
      if (locks.has(lockKey)) return { result: null };
      locks.add(lockKey);
      return { result: "OK" };
    }

    if (name === "LPUSH") {
      queue.unshift(String(value));
      return { result: queue.length };
    }

    if (name === "DEL") {
      locks.delete(String(key));
      return { result: 1 };
    }

    throw new Error(`Unexpected Redis command: ${String(name)}`);
  };

  return { queue, redis };
}

const point: GpsHistoryPayload = {
  driver_id: "driver-1",
  user_id: "user-1",
  lat: 10.762622,
  lng: 106.660172,
  heading: 90,
  speed: 0,
  created_at: "2026-07-29T13:22:20.000Z",
};

test("two concurrent identical GPS requests enqueue one history item", async () => {
  const fake = createFakeRedis();

  const results = await Promise.all([
    enqueueHistoryOnce(fake.redis, point),
    enqueueHistoryOnce(fake.redis, {
      ...point,
      created_at: "2026-07-29T13:22:20.100Z",
    }),
  ]);

  assert.deepEqual(results, [true, false]);
  assert.equal(fake.queue.length, 1);
  assert.deepEqual(JSON.parse(fake.queue[0]), point);
});

test("different coordinates remain distinct history items", async () => {
  const fake = createFakeRedis();

  const first = await enqueueHistoryOnce(fake.redis, point);
  const second = await enqueueHistoryOnce(fake.redis, {
    ...point,
    lat: point.lat + 0.0001,
  });

  assert.equal(first, true);
  assert.equal(second, true);
  assert.equal(fake.queue.length, 2);
});
