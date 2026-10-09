import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

test("GPS points are compressed into one R2 object per order", async () => {
  const puts = [];
  const env = {
    GPS_INGEST_SECRET: "gps-secret-long-enough-for-test",
    GPS_BUCKET: {
      async put(key, body, options) {
        puts.push({ key, body, options });
      },
    },
    ALLOWED_ORIGINS: "",
  };
  const response = await worker.fetch(
    new Request("https://gateway.test/v1/gps/chunks", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-gps-ingest-secret": env.GPS_INGEST_SECRET,
      },
      body: JSON.stringify({
        points: [
          point("order-1", 10.1, 106.1),
          point("order-1", 10.2, 106.2),
          point("order-2", 10.3, 106.3),
        ],
      }),
    }),
    env,
  );

  assert.equal(response.status, 201);
  assert.equal(puts.length, 2);
  assert.match(puts[0].key, /^orders\/order-1\/gps\/\d{4}\/\d{2}\/\d{2}\//);
  assert.match(puts[1].key, /^orders\/order-2\/gps\/\d{4}\/\d{2}\/\d{2}\//);
  assert.equal(puts[0].options.httpMetadata.contentEncoding, "gzip");
  assert.equal(puts[0].options.customMetadata.pointCount, "2");
});

function point(orderId, lat, lng) {
  return {
    order_id: orderId,
    driver_id: "driver-1",
    user_id: "user-1",
    lat,
    lng,
    created_at: "2026-09-18T08:00:00.000Z",
  };
}

test("retrying the same GPS batch uses one stable object key dated by its GPS sample", async () => {
  const keys = [];
  const env = {
    GPS_INGEST_SECRET: "gps-secret-long-enough-for-test",
    GPS_BUCKET: { async put(key) { keys.push(key); } },
    ALLOWED_ORIGINS: "",
  };
  const body = {
    batch_id: "a".repeat(64),
    points: [point("order-retry", 10.8, 106.7)],
  };
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await worker.fetch(new Request("https://gateway.test/v1/gps/chunks", {
      method: "POST",
      headers: { "content-type": "application/json", "x-gps-ingest-secret": env.GPS_INGEST_SECRET },
      body: JSON.stringify(body),
    }), env);
    assert.equal(response.status, 201);
  }
  assert.equal(keys[0], keys[1]);
  assert.equal(keys[0], `orders/order-retry/gps/2026/09/18/${body.batch_id}.jsonl.gz`);
});
