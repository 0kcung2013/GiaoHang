import assert from "node:assert/strict";
import test from "node:test";
import { rankDriversByRoadDistance, quoteFreePickOrders } from "./road_distance.mjs";

const pickup = { lat: 10.8, lng: 106.7 };
const candidates = [
  { user_id: "driver-a", lat: 10.8001, lng: 106.7001 },
  { user_id: "driver-b", lat: 10.805, lng: 106.705 },
];
const matrix = (distances, durations) => async () => Response.json({
  code: "Ok", distances, durations,
});

test("a driver across a barrier loses to a farther GPS point with a shorter road route", async () => {
  const result = await rankDriversByRoadDistance(candidates, pickup, {
    fetcher: matrix([[2800], [900]], [[500], [180]]),
  });
  assert.deepEqual(result.map(x => x.user_id), ["driver-b"]);
  assert.equal(result[0].distance_meters, 900);
});

test("the table direction is every driver to pickup, including one-way streets", async () => {
  let request;
  await rankDriversByRoadDistance(candidates, pickup, {
    fetcher: async (url) => { request = new URL(url); return Response.json({
      code: "Ok", distances: [[1200], [700]], durations: [[90], [120]],
    }); },
  });
  assert.equal(request.searchParams.get("sources"), "0;1");
  assert.equal(request.searchParams.get("destinations"), "2");
  assert.match(request.pathname, /106\.7001,10\.8001;106\.705,10\.805;106\.7,10\.8$/);
});

test("road distance wins over duration; equal distances use duration and stable ID", async () => {
  const result = await rankDriversByRoadDistance(candidates, pickup, {
    fetcher: matrix([[900], [700]], [[60], [120]]),
  });
  assert.deepEqual(result.map(x => x.user_id), ["driver-b", "driver-a"]);
});

test("unreachable routes and routes beyond 2 km receive no automatic offer", async () => {
  const result = await rankDriversByRoadDistance(candidates, pickup, {
    fetcher: matrix([[null], [2001]], [[null], [300]]),
  });
  assert.deepEqual(result, []);
});

test("a routing outage cannot silently fall back to direct distance", async () => {
  await assert.rejects(rankDriversByRoadDistance(candidates, pickup, {
    fetcher: async () => { throw new Error("network down"); },
  }), /ROAD_ROUTING_UNAVAILABLE/);
});

test("a malformed matrix cannot turn a missing route into zero distance", async () => {
  await assert.rejects(rankDriversByRoadDistance(candidates, pickup, {
    fetcher: matrix([[null], [900]], [[12], [100]]),
  }), /ROAD_ROUTING_UNAVAILABLE/);
});

test("every candidate is routed, including candidates outside the first API batch", async () => {
  const many = Array.from({ length: 60 }, (_, i) => ({
    user_id: `driver-${i}`, lat: 10.8 + i * 0.00001, lng: 106.7,
  }));
  let routed = 0;
  const result = await rankDriversByRoadDistance(many, pickup, {
    fetcher: async (url) => {
      const count = new URL(url).searchParams.get("sources").split(";").length;
      const distances = Array.from({ length: count }, (_, i) => [routed + i === 59 ? 100 : 1900]);
      routed += count;
      return Response.json({ code: "Ok", distances,
        durations: Array.from({ length: count }, () => [100]) });
    },
  });
  assert.equal(routed, 60);
  assert.equal(result[0].user_id, "driver-59");
});

test("FreePick includes the 3 km boundary and excludes every longer road route", async () => {
  const result = await quoteFreePickOrders(candidates[0], [
    { id: "near-gps", pickup_lat: 10.801, pickup_lng: 106.701 },
    { id: "short-road", pickup_lat: 10.802, pickup_lng: 106.702 },
    { id: "at-limit", pickup_lat: 10.8025, pickup_lng: 106.7025 },
    { id: "too-far", pickup_lat: 10.803, pickup_lng: 106.703 },
  ], { fetcher: matrix([[2500, 1500, 3000, 3000.1]], [[300, 150, 400, 500]]) });
  assert.deepEqual(result.map(x => x.id), ["near-gps", "at-limit"]);
  assert.equal(result[0].pickup_road_distance_meters, 2500);
});
