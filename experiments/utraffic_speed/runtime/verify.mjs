import {readFileSync,writeFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import assert from 'node:assert/strict';
import {SpeedModel} from '../../../supabase/functions/_shared/delivery_eta_utraffic_model.mjs';
import {RoadMatcher} from '../../../supabase/functions/_shared/delivery_eta_road_matcher.mjs';
import {buildRouteSpeedProfile} from '../../../supabase/functions/_shared/delivery_eta_utraffic_profile.mjs';
const dir=process.argv[2]??'output/utraffic_speed/runtime';
const read=name=>JSON.parse(readFileSync(`${dir}/${name}.json`,'utf8'));
const started=performance.now(),model=new SpeedModel(read('model')),matcher=new RoadMatcher(read('network'));
const loadMs=performance.now()-started;
let maximumSpeedError=0,maximumFeatureError=0;
const cases=read('parity');
for (const c of cases) {
  const vector=model.featuresAt(c.road,c.at);
  c.features.forEach((v,i)=>maximumFeatureError=Math.max(maximumFeatureError,Math.abs(v-vector[i])));
  maximumSpeedError=Math.max(maximumSpeedError,Math.abs(model.predict(vector)-c.speed_kmh));
}
assert.ok(maximumFeatureError<1e-10); assert.ok(maximumSpeedError<1e-8);
const routes=read('route_parity'),timings=[];
let maximumRouteError=0;
for (const fixture of routes) {
  const tick=performance.now(),actual=buildRouteSpeedProfile(fixture.route,fixture.at,model,matcher),expected=fixture.expected;
  timings.push({name:fixture.name,milliseconds:performance.now()-tick,sections:actual.speed_profile.length,payload_bytes:Buffer.byteLength(JSON.stringify(actual))});
  assert.equal(actual.speed_profile.length,expected.speed_profile.length,fixture.name);
  maximumRouteError=Math.max(maximumRouteError,Math.abs(actual.travel_minutes-expected.travel_minutes));
  assert.ok(Math.abs(actual.ai_coverage_ratio-expected.ai_coverage_ratio)<1e-10);
  actual.speed_profile.forEach((s,i)=>{
    const e=expected.speed_profile[i];
    assert.equal(s.segment_id,e.segment_id); assert.equal(s.used_ai,e.used_ai); assert.equal(s.match_method,e.match_method);
    assert.ok(Math.abs(s.speed_kmh-e.speed_kmh)<1e-8);
    assert.ok(Math.abs(s.start_meters-e.start_meters)<1e-6); assert.ok(Math.abs(s.end_meters-e.end_meters)<1e-6);
    assert.ok(Math.abs(Date.parse(s.forecast_at)-Date.parse(e.forecast_at))<=1);
  });
}
assert.ok(maximumRouteError<1e-6);
const result={language:'JavaScript',speed_cases:cases.length,route_cases:routes.length,maximum_speed_error:maximumSpeedError,
  maximum_feature_error:maximumFeatureError,maximum_route_minutes_error:maximumRouteError,cold_load_milliseconds:loadMs,
  node_heap_used_mb:process.memoryUsage().heapUsed/1024/1024,route_timings:timings};
writeFileSync(`${dir}/javascript_verification.json`,JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));
