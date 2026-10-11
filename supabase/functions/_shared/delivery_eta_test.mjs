import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { calculateEta, etaPhase, freshGps, roadRoute, applyEarlyDeparture, fixedEtaForOrder, ETA_MODE } from './delivery_eta.mjs';
import { predictMultiplier, routeTravelMinutes, predictSpeed, modelVersion } from './delivery_eta_traffic.mjs';

const now=Date.parse('2026-08-07T10:30:00Z');
const order={driver_id:'driver-1',status:'assigned',pickup_lng:106.68,pickup_lat:10.78,
  delivery_lng:106.71,delivery_lat:10.80,pickup_arrived_at:null,actual_picked_up_at:null};
const driver={current_lng:106.67,current_lat:10.77,location_updated_at:new Date(now).toISOString()};
const route=(meters)=>({distance_meters:meters,osrm_seconds:999,
  points:[[106.68,10.78],[106.71,10.80]]});
const base={order,driver,assignedAt:new Date(now).toISOString(),now,
  getRoute:async(from,to)=>route(to[0]===order.pickup_lng?1000:5000),predict:r=>r.distance_meters/1000/25*60};
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} != ${b}`);

test('pending/confirmed/terminal orders have no ETA, even with an old deadline',async()=>{
  for (const status of ['pending','confirmed','delivered','cancelled','returning']) {
    assert.equal(await calculateEta({...base,order:{...order,status,estimated_delivery_at:'2026-01-01'}}),null);
  }
  assert.equal(etaPhase({...order,driver_id:null},null),null);
});
test('initial ETA uses actual two road legs at 25 km/h plus 5+5+5 minutes',async()=>{
  const eta=await calculateEta(base);
  near(eta.remaining_minutes,29.4);
  near(eta.approach.travel_minutes,2.4);
  near(eta.delivery.travel_minutes,12);
  assert.equal(eta.reference_speed_kmh,25);
  assert.equal(eta.predicted_at,new Date(now+29.4*60000).toISOString());
});
test('traffic corrects travel separately and never multiplies handling or preparation',async()=>{
  let n=0;
  const eta=await calculateEta({...base,predict:r=>r.distance_meters/1000/25*60*(++n===1?1.5:1.2)});
  near(eta.remaining_minutes,33);
  near(eta.approach.baseline_minutes,2.4);
  near(eta.preparation_minutes,5);
  near(eta.pickup_minutes,5);
  near(eta.handoff_minutes,5);
});
test('initial timestamp stays anchored to acceptance even when the first request is delayed',async()=>{
  const earlier=new Date(now-2*60000).toISOString();
  const a=await calculateEta({...base,assignedAt:earlier});
  const b=await calculateEta({...base,assignedAt:earlier});
  near(a.preparation_minutes,5);
  assert.equal(a.predicted_at,new Date(now-2*60000+29.4*60000).toISOString());
  assert.equal(a.predicted_at,b.predicted_at);
  const expired=await calculateEta({...base,assignedAt:new Date(now-6*60000).toISOString()});
  assert.equal(expired.preparation_minutes,5);
  assert.equal(expired.predicted_at,new Date(now-6*60000+29.4*60000).toISOString());
});
test('early departure subtracts exactly five minutes from the initial timestamp once',async()=>{
  const initial=await calculateEta(base);
  const departure=new Date(now+2*60000).toISOString();
  const eta=applyEarlyDeparture(initial,departure);
  assert.equal(eta.preparation_minutes,0);
  assert.equal(eta.preparation_removed_minutes,5);
  near(eta.remaining_minutes,24.4);
  assert.equal(Date.parse(initial.predicted_at)-Date.parse(eta.predicted_at),5*60000);
  assert.equal(eta.computed_at,initial.computed_at);
  assert.deepEqual(eta.approach,initial.approach);
  assert.deepEqual(eta.delivery,initial.delivery);
  assert.deepEqual(applyEarlyDeparture(eta,departure),eta);
});
test('departure before the first commit applies the same five-minute exception',async()=>{
  const eta=await calculateEta({...base,departedAt:new Date(now-5000).toISOString()});
  // A timestamp before acceptance cannot prove early departure for this assignment.
  assert.equal(eta.preparation_minutes,5);
  const early=await calculateEta({...base,departedAt:new Date(now+5000).toISOString()});
  assert.equal(early.preparation_minutes,0);
  near(early.remaining_minutes,24.4);
});
test('departure at or after the five-minute boundary does not shorten ETA',async()=>{
  const initial=await calculateEta(base);
  for (const minutes of [5,6,20]) {
    const eta=applyEarlyDeparture(initial,new Date(now+minutes*60000).toISOString());
    assert.equal(eta.predicted_at,initial.predicted_at);
    assert.equal(eta.preparation_minutes,5);
    assert.equal(eta.preparation_removed_minutes,0);
  }
});
test('driver proximity changes the approach leg, without a fabricated 2 km',async()=>{
  const eta=await calculateEta({...base,getRoute:async(from,to)=>route(to[0]===order.pickup_lng?100:5000)});
  near(eta.approach.baseline_minutes,0.24);
  near(eta.remaining_minutes,27.24);
});
test('delivery forecast uses the expected future departure after approach and pickup',async()=>{
  const times=[];
  await calculateEta({...base,predict:(r,at)=>{times.push(at);return r.distance_meters/1000/25*60;}});
  assert.equal(times[0],new Date(now+5*60000).toISOString());
  assert.equal(times[1],new Date(now+(5+2.4+5)*60000).toISOString());
});
test('early pickup arrival, pickup completion and delivery arrival keep every initial value',async()=>{
  const initial=await calculateEta(base);
  for (const stage of [
    {status:'picking_up',pickup_arrived_at:new Date(now+60000).toISOString()},
    {status:'delivering',actual_picked_up_at:new Date(now+2*60000).toISOString()},
    {status:'delivering',delivery_arrived_at:new Date(now+3*60000).toISOString()},
  ]) {
    const eta=await calculateEta({...base,order:{...order,...stage,delivery_eta:initial},now:now+4*60000,
      getRoute:()=>{throw new Error('must not recalculate route');},predict:()=>{throw new Error('must not rerun model');}});
    assert.deepEqual(eta,initial);
  }
});
test('waiting at pickup preserves the initial five-minute allowance and fixed timestamp',async()=>{
  const initial=await calculateEta(base);
  const eta=await calculateEta({...base,order:{...order,delivery_eta:initial,
    pickup_arrived_at:new Date(now).toISOString()},now:now+10*60000});
  assert.deepEqual(eta,initial);
  assert.equal(eta.pickup_minutes,5);
  assert.equal(eta.handoff_minutes,5);
});
test('later driver positions and traffic changes cannot recompute an accepted ETA',async()=>{
  let routeCalls=0,modelCalls=0;
  const initial=await calculateEta({...base,getRoute:async(from,to)=>{routeCalls++;return base.getRoute(from,to);},
    predict:r=>{modelCalls++;return r.distance_meters/1000/25*60;}});
  const eta=await calculateEta({...base,order:{...order,delivery_eta:initial},driver:{...driver,current_lng:106.71},
    now:now+60000,getRoute:()=>{routeCalls++;throw new Error('unexpected route');},
    predict:()=>{modelCalls++;return 2.2;}});
  assert.deepEqual(eta,initial);
  assert.equal(routeCalls,2);
  assert.equal(modelCalls,2);
});
test('later stale GPS or OSRM failures do not invalidate the fixed prediction',async()=>{
  const initial=await calculateEta(base);
  const updatedOrder={...order,delivery_eta:initial,status:'delivering'};
  const eta=await calculateEta({...base,order:updatedOrder,driver:{},now:now+10*60000,
    getRoute:()=>{throw new Error('must not route');}});
  assert.deepEqual(eta,initial);
  assert.deepEqual(fixedEtaForOrder(updatedOrder),initial);
});

test('existing forecasts keep the handling allowances saved before the policy change',async()=>{
  const initial=await calculateEta(base);
  const previousTimestamp=new Date(now+24.4*60000).toISOString();
  const previous={...initial,pickup_minutes:3,handoff_minutes:2,
    initial_total_minutes:24.4,remaining_minutes:24.4,
    initial_predicted_at:previousTimestamp,predicted_at:previousTimestamp};
  const eta=await calculateEta({...base,order:{...order,delivery_eta:previous},now:now+60000,
    getRoute:()=>{throw new Error('must not recalculate an existing forecast');},
    predict:()=>{throw new Error('must not rerun model');}});
  assert.deepEqual(eta,previous);
});
test('passing the forecast timestamp does not extend it or mark delivery complete',async()=>{
  const initial=await calculateEta(base);
  const eta=await calculateEta({...base,order:{...order,delivery_eta:initial,status:'delivering'},now:now+60*60000});
  assert.equal(eta.predicted_at,initial.predicted_at);
  assert.ok(Date.parse(eta.predicted_at)<now+60*60000);
  assert.equal(eta.phase,'fixed');
  assert.equal(eta.calculation_mode,ETA_MODE);
});
test('a different assignment cannot reuse the previous driver prediction',async()=>{
  const initial=await calculateEta(base);
  const changed={...order,driver_id:'driver-2',delivery_eta:initial};
  assert.equal(fixedEtaForOrder(changed),null);
  const eta=await calculateEta({...base,order:changed});
  assert.equal(eta.driver_id,'driver-2');
});
test('missing assignment time is not replaced by a client clock',async()=>{
  await assert.rejects(()=>calculateEta({...base,assignedAt:null}),/ETA_ASSIGNMENT_TIME_MISSING/);
});
test('stale/missing/impossible GPS cannot produce a fresh estimate',async()=>{
  for (const invalid of [{...driver,location_updated_at:null},{...driver,current_lat:NaN},
    {...driver,location_updated_at:new Date(now-180001).toISOString()},
    {...driver,location_updated_at:new Date(now+31000).toISOString()}]) {
    assert.equal(freshGps(invalid,now),false);
    await assert.rejects(()=>calculateEta({...base,driver:invalid}),/ETA_LOCATION_STALE/);
  }
});
test('OSRM time is retained for comparison and does not alter the 25 km/h baseline',async()=>{
  for (const seconds of [10,720,732,9999]) {
    const eta=await calculateEta({...base,getRoute:async()=>({...route(1000),osrm_seconds:seconds})});
    near(eta.approach.travel_minutes,2.4);
    near(eta.delivery.travel_minutes,2.4);
    assert.equal(eta.approach.osrm_seconds,seconds);
  }
});
test('missing AI coverage falls back to 25 km/h without a second peak heuristic',async()=>{
  const eta=await calculateEta({...base,predict:()=>null});
  near(eta.remaining_minutes,29.4);
  assert.equal(eta.approach.used_ai,false);
  assert.equal(eta.delivery.multiplier,1);
});
test('stored ETA contains no GPS coordinates or route geometry',async()=>{
  const eta=await calculateEta(base);
  assert.doesNotMatch(JSON.stringify(eta),/current_lat|current_lng|points|geometry|106\.68|10\.78/);
  assert.equal(eta.uses_realtime_traffic,false);
});
test('invalid OSRM responses fail explicitly without using direct distance',async()=>{
  for (const body of [{code:'NoRoute'},{code:'Ok',routes:[{distance:NaN}]},
    {code:'Ok',routes:[{distance:1000,geometry:{coordinates:[[0,0],[106.7,10.8]]}}]}]) {
    await assert.rejects(()=>roadRoute([106.7,10.7],[106.8,10.8],async()=>({ok:true,json:async()=>body})),/ETA_ROAD_UNAVAILABLE/);
  }
  await assert.rejects(()=>roadRoute([106.7,10.7],[106.8,10.8],async()=>({ok:false})),/ETA_ROAD_UNAVAILABLE/);
});
test('valid OSRM route uses longitude-latitude and full geometry',async()=>{
  let url;
  const r=await roadRoute([106.7,10.7],[106.8,10.8],async u=>{url=u;return {ok:true,json:async()=>({code:'Ok',routes:[{
    distance:2000,duration:500,geometry:{coordinates:[[106.7,10.7],[106.8,10.8]]}}]})};});
  assert.match(url,/106\.7,10\.7;106\.8,10\.8/);
  assert.match(url,/overview=full&geometries=geojson/);
  assert.equal(r.distance_meters,2000);
});
test('historical traffic uses the same Vietnam instant regardless of input timezone',()=>{
  const point=[106.68,10.78];
  assert.equal(predictMultiplier(point,'2026-08-07T17:30:00+07:00'),predictMultiplier(point,'2026-08-07T10:30:00Z'));
  assert.equal(predictMultiplier([106.68,11.05],new Date(now)),null);
  assert.equal(modelVersion,'smarttraffic_hcm_speed_v1');
});
test('SmartTraffic predicts speed consistently with Python for every minute in a week',()=>{
  const cases=JSON.parse(readFileSync(new URL('../../../apps/delivery_app/test/fixtures/smarttraffic_speed_parity.json',import.meta.url)));
  for(const c of cases) near(predictSpeed(c.at),c.speed);
});
test('synthetic time model changes ETA by time, not road name',()=>{
  const r=route(6000);
  const peak=routeTravelMinutes(r,'2026-10-12T08:00:00+07:00');
  const noon=routeTravelMinutes(r,'2026-10-12T12:00:00+07:00');
  assert.ok(peak>noon+4);
  near(predictMultiplier([106.68,10.78],new Date(now)),predictMultiplier([106.70,10.80],new Date(now)));
});
test('AI speed may reduce baseline time; service allowances remain unchanged',async()=>{
  const eta=await calculateEta({...base,predict:routeTravelMinutes});
  assert.ok(eta.delivery.travel_minutes<eta.delivery.baseline_minutes);
  assert.equal(eta.is_synthetic,true);
  assert.ok(eta.delivery.predicted_speed_kmh>25);
  near(eta.remaining_minutes,15+eta.approach.travel_minutes+eta.delivery.travel_minutes);
});
test('route leaving demo region and invalid time use no AI',()=>{
  assert.equal(routeTravelMinutes({...route(1000),points:[[106.68,10.78],[106.68,11.0],[106.71,10.80]]},new Date(now)),null);
  assert.equal(routeTravelMinutes(route(1000),'bad-time'),null);
});
test('invalid or throwing speed inference uses the fixed fallback',async()=>{
  for(const value of [null,NaN,Infinity,-5,0]) {
    const eta=await calculateEta({...base,predict:()=>value});
    near(eta.remaining_minutes,29.4);
    assert.equal(eta.delivery.used_ai,false);
  }
  const eta=await calculateEta({...base,predict:()=>{throw Error('unavailable');}});
  near(eta.remaining_minutes,29.4);
});
