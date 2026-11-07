import test from 'node:test';
import assert from 'node:assert/strict';
import { isAlongDestinationRoute, rankDispatchDrivers } from './destination_dispatch.mjs';

test('same direction requires strictly closer delivery and pickup within 3km', () => {
  assert.equal(isAlongDestinationRoute(2800, 10000, 3000, 5000), true);
  assert.equal(isAlongDestinationRoute(3001, 10000, 3000, 5000), false);
  assert.equal(isAlongDestinationRoute(500, 10000, 1000, 11000), false);
  assert.equal(isAlongDestinationRoute(500, 10000, 10000, 9000), true);
  assert.equal(isAlongDestinationRoute(3000, 10000, 20000, 9999), true);
  assert.equal(isAlongDestinationRoute(500, 10000, 1000, 10000), false);
  assert.equal(isAlongDestinationRoute(100, 250, 20, 10), false);
  assert.equal(isAlongDestinationRoute(100, 5000, NaN, 1000), false);
});

const order = {pickup_lat: 11, pickup_lng: 106.6, delivery_lat: 11.03, delivery_lng: 106.6};
const destination = {user_id: 'home', current_lat: 10.99, current_lng: 106.6,
  dispatch_mode: 'destination', destination_lat: 11.08, destination_lng: 106.6,
  destination_expires_at: '2026-11-05T20:00:00Z'};
const nearby = {user_id: 'near', current_lat: 10.999, current_lng: 106.6, dispatch_mode: 'nearby'};

function routing(responses) {
  let call = 0;
  return async () => {
    const distances = responses[call++];
    if (distances instanceof Error) throw distances;
    return Response.json({code: 'Ok', distances, durations: distances.map(row => row.map(d => d == null ? null : d / 10))});
  };
}
test('destination driver within 3km wins over nearer ordinary driver', async () => {
  const result = await rankDispatchDrivers([nearby, destination], order, {
    fetcher: routing([[[400], [2800]], [[3000, 8000], [0, 5000], [2800, 10000]]]),
  });
  assert.deepEqual(result.map(d => d.user_id), ['home', 'near']);
  assert.equal(result[0].destination_route.remaining_meters, 5000);
});
test('far pickup excludes destination driver and keeps the ordinary candidate', async () => {
  const result = await rankDispatchDrivers([nearby, destination], order, {
    fetcher: routing([[[400], [3001]]]),
  });
  assert.deepEqual(result.map(d => d.user_id), ['near']);
});
test('reverse direction and routing failure never receive priority', async () => {
  for (const response of [[[3000, 8000], [0, 11000], [2000, 10000]], new Error('offline')]) {
    const result = await rankDispatchDrivers([nearby, destination], order, {
      fetcher: routing([[[400], [2000]], response]),
    });
    assert.deepEqual(result.map(d => d.user_id), ['near']);
  }
});
test('two matching destination drivers retain nearest pickup ordering', async () => {
  const other = {...destination, user_id: 'closer', current_lat: 10.995};
  const result = await rankDispatchDrivers([destination, other], order, {
    fetcher: routing([[[2500], [1000]], [[3000, 8000, 8000], [0, 5000, 5000], [1000, 10000, 10000], [2500, 10000, 10000]]]),
  });
  assert.deepEqual(result.map(d => d.user_id), ['closer', 'home']);
});
test('ordinary candidates retain their configured automatic radius', async () => {
  const result = await rankDispatchDrivers([nearby], order, {fetcher: routing([[[2500]]])});
  assert.deepEqual(result, []);
});

test('nearby delivery limits use strictly less than 5km or 10km; unlimited is preserved', async () => {
  const drivers = [
    {...nearby, user_id: 'five', nearby_delivery_limit_m: 5000},
    {...nearby, user_id: 'ten', nearby_delivery_limit_m: 10000},
    {...nearby, user_id: 'unlimited'},
  ];
  for (const [distance, expected] of [
    [4999.9, ['five', 'ten', 'unlimited']],
    [5000, ['ten', 'unlimited']], [9999.9, ['ten', 'unlimited']],
    [10000, ['unlimited']], [50000, ['unlimited']],
  ]) {
    const result = await rankDispatchDrivers(drivers, order, {
      fetcher: routing([[[100], [100], [100]], [[distance]]]),
    });
    assert.deepEqual(result.map(d => d.user_id).sort(), expected.sort());
  }
});
test('delivery routing failure excludes limited nearby drivers but not unlimited or area drivers', async () => {
  const result = await rankDispatchDrivers([
    {...nearby, user_id: 'limited', nearby_delivery_limit_m: 5000},
    {...nearby, user_id: 'unlimited'},
    {...nearby, user_id: 'area', dispatch_mode: 'area', nearby_delivery_limit_m: 5000},
  ], order, {fetcher: routing([[[100], [100], [100]], new Error('offline')])});
  assert.deepEqual(result.map(d => d.user_id).sort(), ['area', 'unlimited']);
});
