// Public place pins, not interpolated carriageway coordinates. No backend edits.
import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';
import {buildTrafficProfile} from '../../supabase/functions/_shared/delivery_eta_traffic.mjs';
import {calculateEta, roadRoute} from '../../supabase/functions/_shared/delivery_eta.mjs';

const dir = 'output/utraffic_speed/routes';
const locations = {
  pickup: {address:'Cửa hàng Thiên Anh · 19A Linh Đông', point:[106.7459414,10.8456193],
    source_url:'https://www.openstreetmap.org/node/4698366796'},
  delivery: {address:'Co.op Food · 103 Linh Đông', point:[106.747684,10.850616],
    source_url:'https://www.foody.vn/ho-chi-minh/co-op-food-linh-dong'},
  driver: {address:'Cửa hàng Thu Thảo · 68A Linh Đông', point:[106.747293,10.84923],
    source_url:'https://www.openstreetmap.org/node/4698366795'},
};
const clocks = ['2020-12-16T18:00:00+07:00','2020-12-16T12:00:00+07:00'];
async function fetchRoute(endpoints) {
  const source_url = `https://router.project-osrm.org/route/v1/driving/${endpoints.map(p=>p.join(',')).join(';')}?overview=full&geometries=geojson&annotations=nodes,distance&steps=true`;
  const response = await fetch(source_url, {headers:{'User-Agent':'DATN-GiaoHang-Demo-Location-Audit/1.0'},signal:AbortSignal.timeout(30000)});
  assert.ok(response.ok, `OSRM ${response.status}`);
  const data = await response.json();
  assert.equal(data.code,'Ok');
  return {source_url,route:data.routes[0],waypoints:data.waypoints};
}
const delivery = await fetchRoute([locations.pickup.point, locations.delivery.point]);
const approach = await fetchRoute([locations.driver.point, locations.pickup.point]);
const input = r => ({distance_meters:r.distance,points:r.geometry.coordinates,annotation_nodes:r.legs[0].annotation.nodes});
const previews = clocks.map(at=>buildTrafficProfile(input(delivery.route),at));
const approaches = clocks.map(at=>buildTrafficProfile(input(approach.route),new Date(Date.parse(at)+5*60000).toISOString()));
const shifted = clocks.map((at,i)=>buildTrafficProfile(input(delivery.route),new Date(Date.parse(at)+(10+approaches[i].travel_minutes)*60000).toISOString()));
const summarize = p => {
  const bands = {clear:0,moderate:0,heavy:0,congested:0,unavailable:0};
  const values = p.speed_profile.map(s=>({speed:s.speed_kmh,meters:s.end_meters-s.start_meters})).sort((a,b)=>a.speed-b.speed);
  const quantile = f => {let d=0;for(const v of values){d+=v.meters;if(d>=p.distance_meters*f)return v.speed;}return values.at(-1)?.speed;};
  for(const s of p.speed_profile) bands[!s.used_ai?'unavailable':s.speed_kmh>40?'clear':s.speed_kmh>34?'moderate':s.speed_kmh>28?'heavy':'congested']+=s.end_meters-s.start_meters;
  const below15 = values.filter(v=>v.speed<15).reduce((sum,v)=>sum+v.meters,0);
  return {minutes:p.travel_minutes,coverage:p.ai_coverage_ratio,all_sections_ai:p.all_sections_ai,bands,
    effective_speed_kmh:p.distance_meters*.06/p.travel_minutes,ai_speed_p10:quantile(.1),ai_speed_median:quantile(.5),ai_speed_p90:quantile(.9),
    speed_min_kmh:values[0]?.speed,speed_max_kmh:values.at(-1)?.speed,below_15_meters:below15,below_15_ratio:below15/p.distance_meters};
};
const profiles = [...previews,...approaches,...shifted];
assert.ok(profiles.every(p=>p.all_sections_ai),'Both legs and previews must remain fully predicted');
// A short slow section near 103 Linh Dong remains the true model output.
// Reject sustained crawling; never floor the speeds or recolor a section.
assert.ok(profiles.every(p=>summarize(p).below_15_meters<=35),'Unexpected sustained very slow section');
assert.ok(approach.route.distance>100 && approach.route.distance<2000,'Driver must have a real approach within the offer radius');
assert.ok([...delivery.waypoints,...approach.waypoints].every(w=>w.distance>3 && w.distance<25),'Pins must remain beside, rather than on, the routed centerline');
assert.ok(Math.ceil(previews[0].travel_minutes+5)>Math.ceil(previews[1].travel_minutes+5));
const totals = approaches.map((p,i)=>15+p.travel_minutes+shifted[i].travel_minutes);
assert.ok(Math.ceil(totals[0])>Math.ceil(totals[1]));
const replay = [];
for(const key of ['peak','off_peak']) {
  const at = new Date().toISOString(), routes = [];
  const order = {driver_id:'real-place-replay',status:'assigned',traffic_demo_key:key,
    pickup_lng:locations.pickup.point[0],pickup_lat:locations.pickup.point[1],
    delivery_lng:locations.delivery.point[0],delivery_lat:locations.delivery.point[1]};
  const eta = await calculateEta({order,assignedAt:at,now:Date.parse(at),driver:{
    current_lng:locations.driver.point[0],current_lat:locations.driver.point[1],location_updated_at:at},
    getRoute:async(from,to)=>{const route=await roadRoute(from,to);routes.push(route);return route;}});
  for(const name of ['approach','delivery']) assert.equal(eta[name].all_sections_ai,true,`${key}/${name} production OSRM contains fallback`);
  replay.push({key,eta,routes});
}
const result = {source:'linh_dong_real_places',...delivery,endpoints:[locations.pickup.point,locations.delivery.point],
  driver_origin:locations.driver.point,approach_route:approach.route,approach_source_url:approach.source_url,
  profiles:previews,peak:summarize(previews[0]),off:summarize(previews[1]),approach:approaches.map(summarize),shifted:shifted.map(summarize),
  distance_meters:delivery.route.distance,suitable:true,fully_covered:true,locations};
writeFileSync(`${dir}/fully_covered_confirmed.json`,JSON.stringify([result]));
writeFileSync(`${dir}/real_places_production_replay.json`,JSON.stringify(replay));
const locationFixture = {locations,delivery_waypoints:delivery.waypoints.map(({location,distance})=>({location,distance})),
  approach_waypoints:approach.waypoints.map(({location,distance})=>({location,distance}))};
writeFileSync('apps/delivery_app/test/fixtures/traffic_demo_locations.json',JSON.stringify(locationFixture));
console.log(JSON.stringify({distance:result.distance_meters,approach_distance:approach.route.distance,locations,
  peak:result.peak,off:result.off,approach:result.approach,shifted:result.shifted,initial_total_minutes:totals,
  production_replay:replay.map(({key,eta})=>({key,approach_coverage:eta.approach.ai_coverage_ratio,delivery_coverage:eta.delivery.ai_coverage_ratio,total:eta.initial_total_minutes}))},null,2));
