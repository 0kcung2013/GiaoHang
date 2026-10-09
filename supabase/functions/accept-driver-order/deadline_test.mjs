import { test } from 'node:test';
import assert from 'node:assert/strict';
import { quoteRoute, validPoint } from './deadline.mjs';

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
