// Read-only live routing smoke check. Saves reproducible routes and summaries.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {buildEtaProfile} from './runtime/profile.mjs';
import {EtaCorrectionModel} from './runtime/model.mjs';
const read = p => JSON.parse(readFileSync(p, 'utf8'));
const routes = read('output/eta_simulation/routes.json');
const model = new EtaCorrectionModel(read('apps/delivery_app/assets/ml/eta_simulation_model.json'));
const context = read('apps/delivery_app/assets/ml/eta_simulation_context.json');
let seed = 20261013;
const choose = () => {seed = seed * 48271 % 2147483647; return routes[seed % routes.length].route.geometry.coordinates;};
const pairs = Array.from({length: 4}, (_, i) => ({name: `random_${i + 1}`, from: choose()[0], to: choose().at(-1)}));
pairs.push({name: 'cu_chi_to_phu_nhuan', from: [106.493, 11.03], to: [106.681, 10.803]},
  {name: 'can_gio_to_district_7', from: [106.867, 10.411], to: [106.717, 10.731]});
const results = [];
async function check(pair) {
  const coords = `${pair.from.join(',')};${pair.to.join(',')}`;
  const response = await fetch(`https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=true&annotations=nodes,distance,duration`, {signal: AbortSignal.timeout(15000)});
  assert.ok(response.ok, `OSRM HTTP ${response.status}`);
  const body = await response.json(); assert.equal(body.code, 'Ok');
  const route = body.routes[0], clock = '2026-10-07T18:00:00+07:00';
  const peak = buildEtaProfile(route, clock, model, context);
  const off = buildEtaProfile(route, '2026-10-07T12:00:00+07:00', model, context);
  assert.ok(peak.is_synthetic && peak.speed_profile.every(s => s.traffic_available));
  assert.ok(peak.used_ai && peak.speed_profile.every(s => s.used_ai && s.speed_kmh >= 15));
  assert.ok(peak.travel_minutes > off.travel_minutes);
  assert.deepEqual(peak.speed_profile, buildEtaProfile(route, clock, model, context).speed_profile);
  assert.ok(Math.abs(peak.speed_profile.reduce((sum, s) => sum + (s.end_meters - s.start_meters) * .06 / s.speed_kmh, 0) - peak.travel_minutes) < 1e-8);
  const colorMeters=[0,0,0,0];
  for(const s of off.speed_profile) {
    colorMeters[s.speed_kmh>=35?0:s.speed_kmh>=25?1:s.speed_kmh>=20?2:3]+=s.end_meters-s.start_meters;
  }
  const summary = {name: pair.name, kilometers: route.distance / 1000, sections: peak.speed_profile.length,
    off_peak_color_percent:colorMeters.map(n=>Math.round(n/off.distance_meters*100)),
    peak_minutes: peak.travel_minutes, off_peak_minutes: off.travel_minutes,
    minimum_speed_kmh: Math.min(...peak.speed_profile.map(s => s.speed_kmh)),
    maximum_speed_kmh: Math.max(...peak.speed_profile.map(s => s.speed_kmh)),
    primary_ai: peak.used_ai, model_version: peak.model_version,
    osm_matched_distance_percent: 100*peak.speed_profile.filter(s=>s.feature_source==='osm_nodes').reduce((v,s)=>v+s.end_meters-s.start_meters,0)/peak.distance_meters};
  return {...pair, route, summary};
}
for (let i = 0; i < pairs.length; i += 2) {
  const batch = await Promise.allSettled(pairs.slice(i, i + 2).map(check));
  for (let j = 0; j < batch.length; j++) {
    const result = batch[j];
    if (result.status === 'fulfilled') {results.push(result.value); console.log(JSON.stringify(result.value.summary));}
    else {results.push({...pairs[i + j], error: String(result.reason)}); console.log(JSON.stringify(results.at(-1)));}
  }
}
mkdirSync('output/eta_simulation', {recursive: true});
writeFileSync('output/eta_simulation/segment_ai/live_routes.json', JSON.stringify(results));
if (results.some(r => r.error)) process.exitCode = 1;
