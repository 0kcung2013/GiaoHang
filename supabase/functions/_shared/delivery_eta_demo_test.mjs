import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {calculateEta,applyEarlyDeparture,ETA_MODE} from './delivery_eta.mjs';
import {routeTravelMinutes} from './delivery_eta_synthetic.mjs';
import {buildRouteSpeedProfile,demoForecastOrigin} from './delivery_eta_speed_profile.mjs';

const assignedAt='2026-10-11T03:00:00.000Z', now=Date.parse(assignedAt);
const driver={current_lng:106.6765,current_lat:10.779,location_updated_at:assignedAt};
const order={driver_id:'driver',status:'assigned',pickup_lng:106.6684,pickup_lat:10.7849,
  delivery_lng:106.7421,delivery_lat:10.8505};
const routes=JSON.parse(readFileSync(new URL('../../../packages/giaohang_mobile/test/fixtures/utraffic_routes.json',import.meta.url),'utf8'));
const convert=r=>({distance_meters:r.distance,osrm_seconds:r.duration,points:r.geometry.coordinates,annotation_nodes:r.legs[0].annotation.nodes});
const getRoute=async(from,to)=>convert(routes[to[0]===order.pickup_lng?'driver_to_pickup':'cmt8_pham_van_dong']);
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
  assert.equal(peak.approach.forecast_at,peak.delivery.forecast_at);
  assert.equal(peak.version,10);
  assert.ok(Date.parse(peak.predicted_at)>now);
  assert.ok(Math.abs(Date.parse(peak.predicted_at)-now-peak.initial_total_minutes*60000)<1);
  assert.equal(peak.ai_clock_at,'2020-12-16T11:00:00.000Z');
  assert.equal(off.ai_clock_at,'2020-12-16T05:00:00.000Z');
});
test('saved section speeds exactly reconstruct the travel contribution to ETA',async()=>{
  for(const key of ['peak','off_peak']) {
    const eta=await forecast(key);
    for(const leg of [eta.approach,eta.delivery]) {
      const minutes=leg.speed_profile.reduce((sum,s)=>sum+(s.end_meters-s.start_meters)/1000/s.speed_kmh*60,0);
      assert.ok(Math.abs(minutes-leg.travel_minutes)<1e-10);
      assert.equal(leg.speed_profile[0].start_meters,0);
      assert.equal(leg.speed_profile.at(-1).end_meters,leg.distance_meters);
      for(const s of leg.speed_profile) {
      assert.ok(s.speed_kmh>=15&&s.speed_kmh<=50);
        assert.equal(s.traffic_available,true);
        assert.equal(s.used_ai,true);
      }
    }
    assert.ok(Math.abs(eta.initial_total_minutes-(15+eta.approach.travel_minutes+eta.delivery.travel_minutes))<1e-8);
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
  assert.ok(Math.abs(profile.travel_minutes-3)<1e-8);
  assert.ok(profile.speed_profile.every(s=>s.speed_kmh===25));
});
test('route adapter and AI segment model share the same forecast time',()=>{
  const route=convert(routes.cmt8_pham_van_dong);
  const at='2020-12-16T18:55:00+07:00';
  assert.equal(buildRouteSpeedProfile(route,at).travel_minutes,routeTravelMinutes(route,at));
});
