import test from 'node:test';
import assert from 'node:assert/strict';
import {calculateEta} from './delivery_eta.mjs';

const assignedAt = '2026-10-17T05:00:00.000Z';
const now = Date.parse(assignedAt);
const inside = [106.67, 10.8], outside = [106.67, 11.0];
const baseOrder = {driver_id:'driver', status:'assigned',
  pickup_lng:106.672, pickup_lat:10.8, delivery_lng:106.675, delivery_lat:10.805};
const driver = {current_lng:inside[0], current_lat:inside[1], location_updated_at:assignedAt};
const road = points => ({distance_meters:1500, osrm_seconds:240, points});

for (const [name, approachOutside, deliveryOutside] of [
  ['both legs outside', true, true],
  ['only the approach outside', true, false],
  ['only the delivery outside', false, true],
]) {
  test(`new assignment uses OSRM for ${name}`, async () => {
    const approach = road([inside, ...(approachOutside ? [outside] : []), [106.672, 10.8]]);
    const delivery = road([[106.672, 10.8], ...(deliveryOutside ? [outside] : []), [106.675, 10.805]]);
    let calls = 0;
    const eta = await calculateEta({order:baseOrder, driver, assignedAt, now,
      getRoute:async () => ++calls === 1 ? approach : delivery});
    for (const [leg, unsupported] of [[eta.approach, approachOutside], [eta.delivery, deliveryOutside]]) {
      assert.equal(leg.used_ai, !unsupported);
      assert.equal(leg.coverage_version, 'hcm_training_bounds_v1');
      if (unsupported) {
        assert.equal(leg.fallback_reason, 'outside_training_area');
        assert.equal(leg.travel_minutes, 4);
        assert.equal(leg.ai_coverage_ratio, 0);
        assert.equal(leg.speed_profile.length, 1);
        assert.equal(leg.speed_profile[0].used_ai, false);
        assert.equal(leg.speed_profile[0].traffic_available, false);
      }
      const integrated = leg.speed_profile.reduce((s,p) => s + (p.end_meters-p.start_meters)*.06/p.speed_kmh, 0);
      assert.ok(Math.abs(integrated-leg.travel_minutes)<1e-8);
    }
    assert.equal(eta.preparation_minutes+eta.pickup_minutes+eta.handoff_minutes, 15);
    assert.ok(Math.abs(eta.initial_total_minutes-15-eta.approach.travel_minutes-eta.delivery.travel_minutes)<1e-8);
    assert.ok(Math.abs(Date.parse(eta.predicted_at)-now-eta.initial_total_minutes*60000)<1);
  });
}

test('refresh preserves a pre-rollout outside AI snapshot and its deadline', async () => {
  const deliveryEta = {calculation_mode:'assignment_once_v1', driver_id:'driver',
    assigned_at:assignedAt, computed_at:assignedAt, initial_predicted_at:'2026-10-17T05:25:00.000Z',
    predicted_at:'2026-10-17T05:25:00.000Z',
    approach:{used_ai:true,route_points:[outside, [106.672,11.0]]},
    delivery:{used_ai:true,route_points:[[106.672,11.0],[106.675,11.0]]}};
  const eta = await calculateEta({order:{...baseOrder, delivery_eta:deliveryEta},
    driver:{}, assignedAt, now:now+600000,
    getRoute:async () => {throw Error('saved assignments must not be recalculated');}});
  assert.strictEqual(eta, deliveryEta);
  assert.equal(eta.predicted_at, deliveryEta.predicted_at);
});
