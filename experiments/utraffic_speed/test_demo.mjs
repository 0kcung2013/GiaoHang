// Regression for the current storefront demo, using production ETA code.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {calculateEta} from '../../supabase/functions/_shared/delivery_eta.mjs';
import {rankDriversByRoadDistance} from '../../supabase/functions/_shared/road_distance.mjs';

const read = name => JSON.parse(readFileSync(new URL(`../../apps/delivery_app/test/fixtures/${name}.json`, import.meta.url),'utf8'));
const fixtures = read('utraffic_demo_assignment'), dispatch = read('traffic_demo_dispatch');
const convert = r => ({distance_meters:r.distance,points:r.geometry.coordinates,
  osrm_seconds:r.duration,annotation_nodes:r.legs[0].annotation?.nodes??[]});
const assignedAt = '2026-10-12T03:00:00.000Z';
const near = (a,b) => assert.ok(Math.abs(a-b)<1e-7, `${a} != ${b}`);

test('selectable demo is fully covered in preview and both assignment legs',()=>{
  const previews=read('utraffic_demo');
  for(const [key,v] of Object.entries(fixtures)) {
    for(const [leg,profile] of Object.entries({preview:previews[key].profile,approach:v.approach,delivery:v.delivery})) {
      assert.equal(profile.all_sections_ai,true,`${key}/${leg} contains fallback sections`);
      near(profile.ai_coverage_ratio,1);
      assert.ok(profile.speed_profile.length>0);
      assert.ok(profile.speed_profile.every(s=>s.used_ai&&s.source==='utraffic_lightgbm'));
    }
  }
});

test('fully covered demo keeps the rounded peak ETA higher than off peak',()=>{
  const previews=read('utraffic_demo');
  assert.ok(Math.ceil(previews.congested.profile.travel_minutes+5)>Math.ceil(previews.clear.profile.travel_minutes+5),
    'The customer quote must display a visible time difference');
  assert.ok(Math.ceil(fixtures.congested.initial_total_minutes)>Math.ceil(fixtures.clear.initial_total_minutes),
    'The assignment ETA must display a visible time difference');
});

test('new demo remains eligible through the production road-distance offer ranker',async()=>{
  const result=await rankDriversByRoadDistance([dispatch.driver],dispatch.pickup,{
    fetcher:async()=>Response.json(dispatch.table),
  });
  assert.equal(result.length,1);
  assert.ok(result[0].distance_meters<=2000);
});

test('new demo speeds stay usable after preparation and pickup; ETA keeps the same section speeds',async()=>{
  for (const [key,scenario] of Object.entries(fixtures)) {
    const order={driver_id:'fixture-driver',status:'assigned',traffic_demo_key:key==='congested'?'peak':'off_peak',
      pickup_lat:dispatch.pickup.lat,pickup_lng:dispatch.pickup.lng};
    const target=scenario.routes.delivery.geometry.coordinates.at(-1);
    Object.assign(order,{delivery_lng:target[0],delivery_lat:target[1]});
    const eta=await calculateEta({order,driver:{current_lat:dispatch.driver.lat,current_lng:dispatch.driver.lng,
      location_updated_at:assignedAt},assignedAt,now:Date.parse(assignedAt),
      getRoute:async(_from,to)=>convert(scenario.routes[to[0]===order.pickup_lng?'approach':'delivery'])});
    near(eta.initial_total_minutes,scenario.initial_total_minutes);
    assert.equal(eta.calculation_mode,'assignment_once_v1');
    for(const name of ['approach','delivery']) {
      const leg=eta[name],reference=scenario[name];
      near(leg.travel_minutes,reference.travel_minutes);
      near(leg.travel_minutes,leg.speed_profile.reduce((sum,s)=>sum+(s.end_meters-s.start_meters)*.06/s.speed_kmh,0));
      assert.equal(leg.speed_profile.length,reference.speed_profile.length);
      leg.speed_profile.forEach((s,i)=>near(s.speed_kmh,reference.speed_profile[i].speed_kmh));
      const slowMeters=leg.speed_profile.filter(s=>s.used_ai&&s.speed_kmh<15)
        .reduce((sum,s)=>sum+s.end_meters-s.start_meters,0);
      // The real storefront route has one ~30 m slow section near 103 Linh Dong.
      // Preserve it; require the rest of the trip to avoid sustained crawling.
      assert.ok(slowMeters<=35,`${key}/${name} has prolonged very slow sections`);
    }
  }
});
