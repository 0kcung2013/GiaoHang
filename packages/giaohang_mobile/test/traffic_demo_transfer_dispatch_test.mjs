import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { AUTOMATIC_ROAD_LIMIT, rankDriversByRoadDistance }
  from '../../../supabase/functions/_shared/road_distance.mjs';

const replay = JSON.parse(readFileSync(
  new URL('./fixtures/traffic_demo_transfer_dispatch.json', import.meta.url), 'utf8',
));

// Replay the measured OSRM cells for whichever drivers remain after a refusal.
function replayOsrm(request) {
  const url = new URL(request);
  const points = url.pathname.split('/').at(-1).split(';').map(coord => {
    const [lng, lat] = coord.split(',').map(Number);
    return { lat, lng };
  });
  const destinations = url.searchParams.get('destinations').split(';').map(Number);
  assert.equal(destinations.length, 1);
  assert.deepEqual(points[destinations[0]], replay.pickup);
  const indexes = url.searchParams.get('sources').split(';').map(source => {
    const point = points[Number(source)];
    const index = replay.drivers.findIndex(driver =>
      driver.lat === point.lat && driver.lng === point.lng);
    assert.notEqual(index, -1, 'A road quote must match the configured GPS');
    return index;
  });
  return new Response(JSON.stringify({
    ...replay.table,
    distances: indexes.map(index => replay.table.distances[index]),
    durations: indexes.map(index => replay.table.durations[index]),
    sources: indexes.map(index => replay.table.sources[index]),
  }));
}

test('road dispatcher offers the demo order to taixe, taixe2, then taixe3', async () => {
  const rejected = new Set();
  const options = {
    fetcher: replayOsrm,
    now: () => Date.parse(replay.checked_at),
  };

  for (let index = 0; index < replay.drivers.length; index++) {
    // The database excludes rejected drivers; do not rely on input ordering.
    const remaining = replay.drivers.filter(driver => !rejected.has(driver.user_id));
    const ranked = await rankDriversByRoadDistance(
      [...remaining].reverse(), replay.pickup, options,
    );
    assert.deepEqual(ranked.map(driver => driver.email),
      replay.drivers.slice(index).map(driver => driver.email));
    assert.ok(ranked.every(driver => driver.distance_meters <= AUTOMATIC_ROAD_LIMIT));
    rejected.add(ranked[0].user_id);
  }

  assert.deepEqual(await rankDriversByRoadDistance([], replay.pickup, options), []);
});
