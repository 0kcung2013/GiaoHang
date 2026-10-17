import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { quoteRoute, validPoint } from './deadline.mjs';
import { supportsPoint, routeMultiplier } from '../_shared/delivery_eta_traffic.mjs';

test('uses route duration and rejects invalid coordinates', async () => {
  let requested;
  const result = await quoteRoute([[106,10],[106.01,10.01],[106.02,10.02]], async url => {
    requested = url;
    return { ok: true, json: async () => ({ code: 'Ok', routes: [{ duration: 1200.1 }] }) };
  });
  assert.equal(result.seconds,1201);
  assert.equal(result.source,'osrm');
  assert.match(requested,/106,10;106.01,10.01;106.02,10.02/);
  assert.equal(validPoint(0,0),false);
  assert.equal(validPoint(null,106),false);
  assert.equal(validPoint(91,106),false);
});
test('router failure and malformed duration use conservative fallback', async () => {
  const points = [[106,10],[106.01,10.01],[106.02,10.02]];
  for (const fetcher of [
    async () => { throw new Error('timeout'); },
    async () => ({ok:true,json:async () => ({code:'Ok',routes:[{duration:-1}]})}),
  ]) {
    const result = await quoteRoute(points,fetcher);
    assert.equal(result.source,'distance_fallback');
    assert.ok(result.seconds > 600);
  }
});

const forecastAt = '2026-08-07T10:30:00.000Z';
const hcmPoints = [[106.6684,10.7849],[106.651842,10.793838]];
const hcmRoute = {
  duration: 600, distance: 2800,
  geometry: { type: 'LineString', coordinates: hcmPoints },
};
const responseFor = route => async () => ({
  ok: true, json: async () => ({ code: 'Ok', routes: [route] }),
});
const trafficFor = (predict = routeMultiplier) => ({
  at: forecastAt,
  supportsPoint: point => supportsPoint(point),
  predict,
});

test('HCM applies the traffic factor once to OSRM travel time', async () => {
  let requested, calls = 0;
  const quote = await quoteRoute(hcmPoints, async url => {
    requested = url;
    return responseFor(hcmRoute)();
  }, trafficFor((route, at) => {
    calls++;
    assert.deepEqual(route, { distance_meters: 2800, points: hcmPoints });
    assert.equal(at, forecastAt);
    return 1.5;
  }));
  assert.deepEqual(quote, { seconds: 900, source: 'osrm' });
  assert.equal(calls, 1);
  assert.match(requested, /overview=full&geometries=geojson/);
});

test('Binh Duong preserves the old quote and does not invoke route prediction', async () => {
  const points = [[106.615,10.85],[106.615,10.89]];
  const route = { ...hcmRoute, duration: 1200.1 };
  let requested, calls = 0;
  const quote = await quoteRoute(points, async url => {
    requested = url;
    return responseFor(route)();
  }, trafficFor(() => { calls++; return 1.5; }));
  assert.deepEqual(quote, await quoteRoute(points, responseFor(route)));
  assert.equal(calls, 0);
  assert.match(requested, /overview=false$/);
});

test('a mixed HCM and outside-coverage journey keeps the old quote', async () => {
  const points = [[106.615,10.89], ...hcmPoints];
  let requested, calls = 0;
  const quote = await quoteRoute(points, async url => {
    requested = url;
    return responseFor(hcmRoute)();
  }, trafficFor(() => { calls++; return 1.5; }));
  assert.deepEqual(quote, { seconds: 600, source: 'osrm' });
  assert.equal(calls, 0);
  assert.match(requested, /overview=false$/);
});

test('an OSRM route leaving model coverage retains its unadjusted duration', async () => {
  const route = {
    ...hcmRoute, distance: 10000,
    geometry: {
      type: 'LineString',
      coordinates: [hcmPoints[0], [106.66,10.90], hcmPoints[1]],
    },
  };
  const quote = await quoteRoute(hcmPoints, responseFor(route), trafficFor());
  assert.deepEqual(quote, { seconds: 600, source: 'osrm' });
});

test('unavailable or invalid model predictions preserve valid OSRM time', async () => {
  for (const value of [null, undefined, NaN, Infinity, -1, 0, 0.5]) {
    const quote = await quoteRoute(hcmPoints, responseFor(hcmRoute), trafficFor(() => value));
    assert.deepEqual(quote, { seconds: 600, source: 'osrm' });
  }
  const quote = await quoteRoute(hcmPoints, responseFor(hcmRoute), trafficFor(() => {
    throw new Error('MODEL_UNAVAILABLE');
  }));
  assert.deepEqual(quote, { seconds: 600, source: 'osrm' });
});

test('missing or malformed geometry does not replace OSRM with distance fallback', async () => {
  for (const changes of [
    { geometry: undefined },
    { geometry: { type: 'LineString', coordinates: [hcmPoints[0]] } },
    { geometry: { type: 'LineString', coordinates: [[NaN,10.78], hcmPoints[1]] } },
    { geometry: { type: 'Polygon', coordinates: hcmPoints } },
    { distance: undefined },
    { distance: -1 },
  ]) {
    let calls = 0;
    const quote = await quoteRoute(hcmPoints, responseFor({ ...hcmRoute, ...changes }),
      trafficFor(() => { calls++; return 1.5; }));
    assert.deepEqual(quote, { seconds: 600, source: 'osrm' });
    assert.equal(calls, 0);
  }
});

test('traffic support errors or invalid forecast times retain the old request', async () => {
  for (const traffic of [
    { ...trafficFor(), at: 'invalid-time' },
    { ...trafficFor(), supportsPoint: () => { throw new Error('MODEL_UNAVAILABLE'); } },
  ]) {
    let requested;
    const quote = await quoteRoute(hcmPoints, async url => {
      requested = url;
      return responseFor(hcmRoute)();
    }, traffic);
    assert.deepEqual(quote, { seconds: 600, source: 'osrm' });
    assert.match(requested, /overview=false$/);
  }
});

test('HCM OSRM errors keep the existing distance fallback without an AI factor', async () => {
  for (const fetcher of [
    async () => { throw new Error('timeout'); },
    async () => ({ ok: false }),
    responseFor({ ...hcmRoute, duration: -1 }),
  ]) {
    let calls = 0;
    const quote = await quoteRoute(hcmPoints, fetcher,
      trafficFor(() => { calls++; return 1.5; }));
    assert.deepEqual(quote, await quoteRoute(hcmPoints, fetcher));
    assert.equal(quote.source, 'distance_fallback');
    assert.equal(calls, 0);
  }
});

test('adjusted travel time still respects the existing RPC duration limit', async () => {
  const quote = await quoteRoute(hcmPoints, responseFor({ ...hcmRoute, duration: 86400 }),
    trafficFor(() => 2.2));
  assert.deepEqual(quote, { seconds: 86400, source: 'osrm' });
});

test('legacy quote uses route speed at two times on identical geometry',async()=>{
  const r=JSON.parse(readFileSync(new URL('../../../packages/giaohang_mobile/test/fixtures/utraffic_routes.json',import.meta.url),'utf8')).cmt8_pham_van_dong;
  const endpoints=[r.geometry.coordinates[0],r.geometry.coordinates.at(-1)];
  const quote=at=>quoteRoute(endpoints,responseFor(r),{supportsPoint,predict:routeMultiplier,at});
  const peak=await quote('2020-12-16T18:00:00+07:00'),off=await quote('2020-12-16T12:00:00+07:00');
  assert.equal(peak.source,'osrm'); assert.equal(off.source,'osrm');
  assert.ok(peak.seconds>off.seconds);
});
