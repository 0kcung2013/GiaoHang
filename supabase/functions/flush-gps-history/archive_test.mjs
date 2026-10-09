import assert from "node:assert/strict";
import test from "node:test";

import {
  ACK_SCRIPT,
  CLAIM_SCRIPT,
  RELEASE_SCRIPT,
  createGpsArchiveHandler,
  flushGpsHistory,
} from "./archive.mjs";

const now = Date.parse("2026-10-09T08:00:00Z");
const point = (id = "order-1") => JSON.stringify({
  driver_id: "driver-1", user_id: "user-1", order_id: id,
  lat: 10.8, lng: 106.7, created_at: "2026-10-09T07:59:00Z",
});

function fixture(rawPoints = [point()]) {
  const state = { queue: [...rawPoints].reverse(), processing: [], lock: null };
  const redis = async ([command, ...args]) => {
    if (command === "LLEN") return state.queue.length;
    if (command === "SET") {
      if (state.lock) return null;
      state.lock = args[1];
      return "OK";
    }
    assert.equal(command, "EVAL");
    const [script, keyCount] = args;
    const token = args[2 + keyCount];
    if (script === RELEASE_SCRIPT) {
      if (state.lock === token) state.lock = null;
      return 1;
    }
    if (state.lock !== token) return 0;
    if (script === CLAIM_SCRIPT) {
      if (!state.processing.length) {
        const limit = Number(args[3 + keyCount]);
        while (state.queue.length && state.processing.length < limit) {
          state.processing.push(state.queue.pop());
        }
      }
      return [...state.processing];
    }
    assert.equal(script, ACK_SCRIPT);
    state.processing = [];
    return 1;
  };
  const run = (archive) => flushGpsHistory({
    redis, archive, now: () => now, createToken: () => "lock-token",
  });
  return { state, run };
}

test("a chunk is acknowledged only after R2 confirms storage", async () => {
  const { state, run } = fixture([point(), point("order-2")]);
  const result = await run(async (body) => {
    assert.equal(state.processing.length, 2);
    assert.equal(body.points.length, 2);
    assert.match(body.batch_id, /^[a-f0-9]{64}$/);
    return { objects: [{}, {}] };
  });
  assert.equal(result.archived, 2);
  assert.equal(result.objects, 2);
  assert.deepEqual(state.processing, []);
});

test("R2 failure retains the batch and a later run retries the same batch ID", async () => {
  const { state, run } = fixture();
  let firstId;
  await assert.rejects(run(async (body) => {
    firstId = body.batch_id;
    throw new Error("R2 unavailable");
  }), /R2 unavailable/);
  assert.equal(state.processing.length, 1);
  assert.equal(state.lock, null);
  await run(async (body) => {
    assert.equal(body.batch_id, firstId);
    return { objects: [{}] };
  });
  assert.deepEqual(state.processing, []);
});

test("an interrupted invocation resumes the batch left in processing", async () => {
  const { state, run } = fixture([point("new-order")]);
  state.processing = [point("interrupted-order")];
  const result = await run(async (body) => {
    assert.equal(body.points[0].order_id, "interrupted-order");
    return { objects: [{}] };
  });
  assert.equal(state.queue.length, 1);
  assert.equal(result.queue_remaining, 1);
});

test("a concurrent invocation cannot consume or acknowledge another batch", async () => {
  const { state, run } = fixture();
  state.lock = "another-invocation";
  const result = await run(async () => assert.fail("must not upload"));
  assert.equal(result.busy, true);
  assert.equal(state.queue.length, 1);
  assert.equal(state.lock, "another-invocation");
});

test("expired and malformed samples are discarded rather than archived", async () => {
  const expired = JSON.stringify({ ...JSON.parse(point()), created_at: "2026-09-01T00:00:00Z" });
  const { state, run } = fixture([expired, "bad-json", point()]);
  const result = await run(async (body) => {
    assert.equal(body.points.length, 1);
    return { objects: [{}] };
  });
  assert.equal(result.discarded, 2);
  assert.equal(result.archived, 1);
  assert.deepEqual(state.processing, []);
});

test("a lost lock prevents acknowledgement of a batch stored in R2", async () => {
  const { state, run } = fixture();
  await assert.rejects(run(async () => {
    state.lock = "new-owner";
    return { objects: [{}] };
  }), /GPS archive lock lost/);
  assert.equal(state.processing.length, 1);
  assert.equal(state.lock, "new-owner");
});

test("missing configuration is rejected before any point is claimed", async () => {
  const handler = createGpsArchiveHandler({
    getEnv: (name) => ({ R2_GPS_INGEST_SECRET: "test-gps-secret" })[name],
    fetcher: async () => assert.fail("must not access Redis"),
    log: { info() {}, error() {} },
  });
  const response = await handler(new Request("https://edge.test", {
    method: "POST", headers: { "x-gps-ingest-secret": "test-gps-secret" },
  }));
  assert.equal(response.status, 500);
  assert.match((await response.json()).error, /Missing/);
});

test("a public or forged request cannot flush the GPS queue", async () => {
  const handler = createGpsArchiveHandler({
    getEnv: () => "server-secret",
    fetcher: async () => assert.fail("must not access Redis"),
  });
  for (const headers of [{}, { "x-gps-ingest-secret": "wrong-secret" }]) {
    assert.equal((await handler(new Request("https://edge.test", { method: "POST", headers }))).status, 401);
  }
});
