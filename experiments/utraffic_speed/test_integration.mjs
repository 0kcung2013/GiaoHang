import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {calculateEta,applyEarlyDeparture} from '../../supabase/functions/_shared/delivery_eta.mjs';
import {buildRouteSpeedProfile,demoForecastOrigin} from '../../supabase/functions/_shared/delivery_eta_speed_profile.mjs';
const read=name=>JSON.parse(readFileSync(`output/utraffic_speed/routes/${name}.json`,'utf8')).route;
const convert=r=>({distance_meters:r.distance,points:r.geometry.coordinates,osrm_seconds:r.duration,annotation_nodes:r.legs[0].annotation?.nodes??[]});
const approach=convert(read('driver_to_pickup')),delivery=convert(read('cmt8_pham_van_dong'));
const assignedAt='2026-10-12T03:00:00.000Z',now=Date.parse(assignedAt);
const order={driver_id:'fixture-driver',status:'assigned',pickup_lng:106.6684,pickup_lat:10.7849,delivery_lng:106.7421,delivery_lat:10.8505};
const driver={current_lng:106.6765,current_lat:10.7790,location_updated_at:assignedAt};
const getRoute=async(from,to)=>to[0]===order.pickup_lng?approach:delivery;
const estimate=key=>calculateEta({order:{...order,traffic_demo_key:key},driver,assignedAt,now,getRoute});
const near=(a,b,tolerance=1e-8)=>assert.ok(Math.abs(a-b)<tolerance,`${a} != ${b}`);
const comparisons={peak:await estimate('peak'),off_peak:await estimate('off_peak')};

test('one directed profile gives exactly the ETA travel contribution, including partial fallback',async()=>{
  for (const key of ['peak','off_peak']) {
    const eta=await estimate(key);
    assert.equal(eta.model_version,'hcm_utraffic_segment_speed_v1');
    assert.equal(eta.dataset_version,6); assert.equal(eta.is_synthetic,false);
    for (const leg of [eta.approach,eta.delivery]) {
      assert.ok(leg.ai_coverage_ratio>0&&leg.ai_coverage_ratio<1);
      assert.ok(leg.speed_profile.some(s=>s.used_ai)&&leg.speed_profile.some(s=>!s.used_ai));
      near(leg.travel_minutes,leg.speed_profile.reduce((sum,s)=>sum+(s.end_meters-s.start_meters)*.06/s.speed_kmh,0));
      assert.equal(leg.speed_profile[0].start_meters,0);
      assert.equal(leg.speed_profile.at(-1).end_meters,leg.distance_meters);
    }
    near(eta.initial_total_minutes,15+eta.approach.travel_minutes+eta.delivery.travel_minutes);
    near(Date.parse(eta.initial_predicted_at),Date.parse(assignedAt)+eta.initial_total_minutes*60000,1);
    assert.equal(eta.calculation_mode,'assignment_once_v1');
  }
});
test('same routes and driver, model-selected 18h and 12h differ without speed assignment',async()=>{
  const peak=await estimate('peak'),off=await estimate('off_peak');
  assert.deepEqual(peak.approach.route_points,off.approach.route_points);
  assert.deepEqual(peak.delivery.route_points,off.delivery.route_points);
  assert.ok(peak.initial_total_minutes>off.initial_total_minutes);
  assert.ok(new Set(peak.delivery.speed_profile.filter(s=>s.used_ai).map(s=>s.speed_kmh)).size>10);
  assert.equal(demoForecastOrigin('peak',assignedAt),Date.parse('2020-12-16T18:00:00+07:00'));
  assert.equal(demoForecastOrigin(null,assignedAt),now);
});
test('early departure adjusts only preparation once; initial deadline anchor and profile stay fixed',async()=>{
  const initial=await estimate('peak'),departure=new Date(now+30000).toISOString();
  const early=applyEarlyDeparture(initial,departure);
  assert.deepEqual(early.approach,initial.approach); assert.deepEqual(early.delivery,initial.delivery);
  assert.deepEqual(applyEarlyDeparture(early,departure),early);
  assert.equal(early.initial_predicted_at,initial.initial_predicted_at);
  assert.equal(Date.parse(initial.predicted_at)-Date.parse(early.predicted_at),300000);
  const refresh=await calculateEta({order:{...order,traffic_demo_key:'off_peak',delivery_eta:early},driver:{},assignedAt,now:now+3600000,getRoute:()=>{throw Error('NO_RECALCULATION');}});
  assert.deepEqual(refresh,early);
});
test('zero distance keeps a zero travel leg, without division by zero or artificial delay',()=>{
  const profile=buildRouteSpeedProfile({distance_meters:0,points:[[106.66,10.78],[106.66,10.78]]},assignedAt);
  assert.equal(profile.travel_minutes,0); assert.deepEqual(profile.speed_profile,[]);
});
