import test from 'node:test';
import assert from 'node:assert/strict';
import {calculateEta,applyEarlyDeparture,ETA_MODE} from './delivery_eta.mjs';
import {routeTravelMinutes,predictSpeed} from './delivery_eta_traffic.mjs';
import {buildRouteSpeedProfile,demoForecastOrigin} from './delivery_eta_speed_profile.mjs';

const assignedAt='2026-10-11T03:00:00.000Z', now=Date.parse(assignedAt);
const driver={current_lng:106.6765,current_lat:10.779,location_updated_at:assignedAt};
const order={driver_id:'driver',status:'assigned',pickup_lng:106.6684,pickup_lat:10.7849,
  delivery_lng:106.651842,delivery_lat:10.793838};
const getRoute=async(from,to)=>({distance_meters:to[0]===order.pickup_lng?1000:5000,
  osrm_seconds:999,points:[from,to]});
const forecast=key=>calculateEta({order:{...order,traffic_demo_key:key},driver,assignedAt,now,getRoute});

test('same driver and route: peak is slower, with a later real-world timestamp',async()=>{
  const peak=await forecast('peak'), off=await forecast('off_peak');
  assert.deepEqual(peak.approach.route_points,off.approach.route_points);
  assert.deepEqual(peak.delivery.route_points,off.delivery.route_points);
  assert.equal(peak.delivery.distance_meters,off.delivery.distance_meters);
  assert.ok(peak.initial_total_minutes-off.initial_total_minutes>4.5);
  assert.ok(peak.delivery.predicted_speed_kmh<off.delivery.predicted_speed_kmh);
  assert.equal(peak.calculation_mode,ETA_MODE);
  assert.equal(peak.computed_at,assignedAt);
  assert.ok(Date.parse(peak.predicted_at)>now);
  assert.ok(Date.parse(peak.predicted_at)<now+3600000);
  assert.equal(peak.ai_clock_at,'2024-04-03T00:00:00.000Z');
  assert.equal(off.ai_clock_at,'2024-04-03T07:00:00.000Z');
});
test('saved section speeds exactly reconstruct the travel contribution to ETA',async()=>{
  for(const key of ['peak','off_peak']) {
    const eta=await forecast(key);
    for(const leg of [eta.approach,eta.delivery]) {
      const minutes=leg.speed_profile.reduce((sum,s)=>sum+(s.end_meters-s.start_meters)/1000/s.speed_kmh*60,0);
      assert.ok(Math.abs(minutes-leg.travel_minutes)<1e-10);
      assert.equal(leg.speed_profile[0].start_meters,0);
      assert.equal(leg.speed_profile.at(-1).end_meters,leg.distance_meters);
      for(const s of leg.speed_profile) assert.equal(s.speed_kmh,predictSpeed(s.forecast_at));
    }
    assert.equal(eta.initial_total_minutes,15+eta.approach.travel_minutes+eta.delivery.travel_minutes);
  }
});
test('early departure and refresh preserve the entire saved speed profile',async()=>{
  const eta=await forecast('peak');
  const early=applyEarlyDeparture(eta,new Date(now+30000).toISOString());
  assert.deepEqual(early.approach,eta.approach);
  assert.deepEqual(early.delivery,eta.delivery);
  assert.equal(early.initial_total_minutes,eta.initial_total_minutes);
  const refreshed=await calculateEta({order:{...order,traffic_demo_key:'off_peak',delivery_eta:early},driver,assignedAt,now:now+600000,
    getRoute:()=>{throw Error('must not recalculate');}});
  assert.deepEqual(refreshed,early);
});
test('ordinary orders use actual assignment time and unsupported routes use fallback',()=>{
  assert.equal(demoForecastOrigin(null,assignedAt),now);
  const route={distance_meters:1250,points:[[105,20],[105.01,20.01]]};
  const profile=buildRouteSpeedProfile(route,assignedAt);
  assert.equal(profile.used_ai,false);
  assert.equal(profile.travel_minutes,3);
  assert.ok(profile.speed_profile.every(s=>s.speed_kmh===25));
});
test('profile agrees with the original speed integration across hour boundaries',()=>{
  const route={distance_meters:12000,points:[[106.67,10.78],[106.70,10.80]]};
  const at='2024-04-03T08:55:00+07:00';
  assert.equal(buildRouteSpeedProfile(route,at).travel_minutes,routeTravelMinutes(route,at));
});
