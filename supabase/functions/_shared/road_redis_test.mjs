import test from 'node:test';
import assert from 'node:assert/strict';
import { withRoadLease } from './road_redis.mjs';
import { quotePickupRoute } from './road_distance.mjs';

function fakeRedis() {
  const values = new Map();
  return async ([command,key,value,...args]) => {
    if (command === 'SET') {
      if (args.includes('NX') && values.has(key)) return null;
      values.set(key,value); return 'OK';
    }
    if (command === 'GET') return values.get(key) ?? null;
    if (command === 'EVAL') {
      const actualKey = args[0], token = args[1];
      if (values.get(actualKey) === token) { values.delete(actualKey); return 1; }
      return 0;
    }
    throw new Error('Unexpected command');
  };
}

test('concurrent dispatches cannot both acquire the Redis lease', async () => {
  const redis = fakeRedis();
  await withRoadLease(redis, async check => {
    assert.deepEqual(await withRoadLease(redis,async () => assert.fail('Second dispatcher ran')),
      {ok:true,busy:true});
    await check();
  });
  assert.equal(await withRoadLease(redis,async () => 'released'),'released');
});

test('an expired dispatcher cannot commit or delete its successor lease', async () => {
  const redis = fakeRedis();
  await withRoadLease(redis, async check => {
    await redis(['SET','road:dispatch:lease','successor']);
    await assert.rejects(check,/ROAD_DISPATCH_LEASE_LOST/);
  });
  assert.equal(await redis(['GET','road:dispatch:lease']),'successor');
});

test('cache preserves quote time and requests a new route after twenty seconds', async () => {
  let timestamp = 100000, requests = 0, cached = null;
  const options = {
    now: () => timestamp,
    cache: { get:async () => cached,set:async (_,value) => {cached=value;} },
    fetcher:async () => { requests++; return {ok:true,json:async () => ({
      code:'Ok',distances:[[900]],durations:[[120]],
    })}; },
  };
  const origin = {lat:10.78,lng:106.7}, target = {lat:10.79,lng:106.71};
  const first = await quotePickupRoute(origin,target,options);
  timestamp += 19000;
  assert.equal((await quotePickupRoute(origin,target,options)).quoted_at,first.quoted_at);
  assert.equal(requests,1);
  timestamp += 2000;
  assert.notEqual((await quotePickupRoute(origin,target,options)).quoted_at,first.quoted_at);
  assert.equal(requests,2);
});
