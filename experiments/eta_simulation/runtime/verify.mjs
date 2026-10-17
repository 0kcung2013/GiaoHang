import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {staticFeatures,timedFeatures} from './features.mjs';
import {EtaCorrectionModel} from './model.mjs';
import {buildEtaProfile} from './profile.mjs';
const directory='output/eta_simulation';
const read=name=>JSON.parse(readFileSync(`${directory}/${name}.json`,'utf8'));
const start=performance.now(),model=new EtaCorrectionModel(read('model')),context=read('context');
const coldLoad=performance.now()-start;
let maximumModelError=0,maximumFeatureError=0,maximumDurationError=0;
for(const fixture of read('parity_vectors'))maximumModelError=Math.max(maximumModelError,Math.abs(model.predict(fixture.features)-fixture.expected_ratio));
const profiles=[],timings=[];
for(const fixture of read('parity_routes')) {
  const vector=timedFeatures(staticFeatures(fixture.route,context),fixture.at);
  vector.forEach((v,i)=>maximumFeatureError=Math.max(maximumFeatureError,Math.abs(v-fixture.features[i])));
  const tick=performance.now(),profile=buildEtaProfile(fixture.route,fixture.at,model,context);
  timings.push(performance.now()-tick);
  assert.equal(profile.used_ai,false,fixture.name);
  maximumDurationError=Math.max(maximumDurationError,Math.abs(profile.lightgbm_travel_minutes*60-fixture.expected_model_seconds));
  assert.equal(profile.speed_profile[0].start_meters,0);
  assert.equal(profile.speed_profile.at(-1).end_meters,fixture.route.distance);
  assert.ok(profile.speed_profile.every(s=>s.speed_kmh>=1&&s.speed_kmh<=90&&s.reference_speed_kmh>=1&&s.reference_speed_kmh<=90));
  profiles.push({...fixture,expected_profile:profile});
}
assert.ok(maximumModelError<1e-8,maximumModelError);
assert.ok(maximumFeatureError<1e-8,maximumFeatureError);
assert.ok(maximumDurationError<1e-6,maximumDurationError);
timings.sort((a,b)=>a-b);
const result={language:'JavaScript',model_cases:1000,route_cases:profiles.length,maximum_model_error:maximumModelError,
  maximum_feature_error:maximumFeatureError,maximum_duration_error_seconds:maximumDurationError,cold_load_ms:coldLoad,
  warm_route_p50_ms:timings[Math.floor(timings.length*.5)],warm_route_p90_ms:timings[Math.floor(timings.length*.9)],
  heap_used_mb:process.memoryUsage().heapUsed/1024/1024};
writeFileSync(`${directory}/parity_profiles.json`,JSON.stringify(profiles));
writeFileSync(`${directory}/javascript_verification.json`,JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));
