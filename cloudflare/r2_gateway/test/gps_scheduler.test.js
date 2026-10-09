import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

const env = {
  SUPABASE_URL: "https://project.supabase.co",
  GPS_INGEST_SECRET: "gps-secret-long-enough-for-test",
};

test("a scheduled event archives the GPS queue using the server-side GPS secret", async (t) => {
  const calls = [];
  t.mock.method(globalThis, "fetch", async (url, options) => {
    calls.push({ url, options });
    return Response.json({ ok: true, archived: 3, objects: 1 });
  });

  await worker.scheduled({ cron: "* * * * *" }, env, {});

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, `${env.SUPABASE_URL}/functions/v1/flush-gps-history`);
  assert.equal(calls[0].options.method, "POST");
  assert.equal(calls[0].options.headers["x-gps-ingest-secret"], env.GPS_INGEST_SECRET);
  assert.equal(calls[0].options.headers.Authorization, undefined);
});

test("a failed archive makes the scheduled invocation fail visibly", async (t) => {
  t.mock.method(globalThis, "fetch", async () =>
    Response.json({ error: "R2 unavailable" }, { status: 502 }),
  );
  await assert.rejects(
    worker.scheduled({}, env, {}),
    /GPS archive failed.*502/,
  );
});

test("an empty GPS queue is a successful scheduled invocation", async (t) => {
  t.mock.method(globalThis, "fetch", async () =>
    Response.json({ ok: true, archived: 0, queue_empty: true }),
  );
  await worker.scheduled({}, env, {});
});
