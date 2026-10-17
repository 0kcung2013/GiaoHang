import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {calculateEta,applyEarlyDeparture} from '../../supabase/functions/_shared/delivery_eta.mjs';
import {buildTrafficProfile,modelVersion} from '../../supabase/functions/_shared/delivery_eta_synthetic.mjs';

const read=name=>JSON.parse(readFileSync(`output/utraffic_speed/routes/${name}.json`,'utf8')).route;
const approach=read('short_demo_driver_to_pickup'),delivery=read('short_demo');
const convert=r=>({distance_meters:r.distance,osrm_seconds:r.duration,points:r.geometry.coordinates,
  annotation_nodes:r.legs?.[0]?.annotation?.nodes??[],annotation_distances:r.legs?.[0]?.annotation?.distance??[],annotation_durations:r.legs?.[0]?.annotation?.duration??[]});
const accepted='2026-10-12T08:00:00.000Z',now=Date.parse(accepted);
const pick=delivery.geometry.coordinates[0],drop=delivery.geometry.coordinates.at(-1),origin=approach.geometry.coordinates[0];
const order={driver_id:'driver',status:'assigned',pickup_lng:pick[0],pickup_lat:pick[1],delivery_lng:drop[0],delivery_lat:drop[1]};
const driver={current_lng:origin[0],current_lat:origin[1],location_updated_at:accepted};
const options={order,driver,assignedAt:accepted,now,getRoute:async(from,to)=>convert(to[0]===pick[0]?approach:delivery)};

test('default server ETA uses trained LightGBM speeds for both legs',async()=>{
  const eta=await calculateEta({...options,order:{...order,traffic_demo_key:'peak'}});
  assert.equal(eta.model_version,modelVersion);
  assert.equal(eta.is_synthetic,true);
  assert.equal(eta.uses_realtime_traffic,false);
  assert.equal(eta.version,10);
  assert.equal(eta.preparation_minutes+eta.pickup_minutes+eta.handoff_minutes,15);
  for(const leg of [eta.approach,eta.delivery]) {
    assert.equal(leg.used_ai,true);assert.ok(leg.speed_profile.every(s=>s.traffic_available&&s.used_ai));assert.equal(leg.is_synthetic,true);
    assert.ok(Math.abs(leg.baseline_minutes-leg.osrm_seconds/60)<1e-8);
    const sum=leg.speed_profile.reduce((v,s)=>v+(s.end_meters-s.start_meters)*3.6/s.speed_kmh,0);
    assert.ok(Math.abs(sum-leg.travel_minutes*60)<1e-6);
    assert.ok(leg.speed_profile.every(s=>s.speed_kmh>=15&&s.speed_kmh<=50));
  }
  assert.ok(Math.abs(eta.initial_total_minutes-15-eta.approach.travel_minutes-eta.delivery.travel_minutes)<1e-8);
  assert.ok(Math.abs(Date.parse(eta.predicted_at)-now-eta.initial_total_minutes*60000)<1);
});
test('new model keeps accepted timestamps and old snapshots during refresh',async()=>{
  const initial=await calculateEta(options),early=applyEarlyDeparture(initial,new Date(now+30000).toISOString());
  assert.equal(early.preparation_removed_minutes,5);
  assert.deepEqual(early.delivery,initial.delivery);
  const stored={...early,model_version:'legacy_model'};
  const actual=await calculateEta({...options,order:{...order,delivery_eta:stored},driver:{},now:now+600000,
    getRoute:()=>{throw Error('must not request a new route');}});
  assert.deepEqual(actual,stored);
});
test('peak/off-peak demo changes travel and preserves handling and geometry',async()=>{
  const peak=await calculateEta({...options,order:{...order,traffic_demo_key:'peak'}});
  const off=await calculateEta({...options,order:{...order,traffic_demo_key:'off_peak'}});
  assert.deepEqual(peak.delivery.route_points,off.delivery.route_points);
  assert.ok(peak.delivery.travel_minutes>off.delivery.travel_minutes);
  assert.equal(peak.handoff_minutes,off.handoff_minutes);
  assert.equal(peak.pickup_minutes,off.pickup_minutes);
});
test('unseen OSRM routes receive primary AI ETA identical to preview',()=>{
  const fixtures=JSON.parse(readFileSync('output/eta_simulation/segment_ai/parity_profiles.json','utf8'));
  for(const fixture of fixtures) {
    const profile=buildTrafficProfile(convert(fixture.route),fixture.at);
    assert.equal(profile.used_ai,true);
    assert.ok(profile.speed_profile.every(s=>s.traffic_available));
    assert.ok(Math.abs(profile.travel_minutes-fixture.expected_profile.travel_minutes)<1e-6);
  }
});
