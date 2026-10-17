import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {EtaCorrectionModel} from './model.mjs';
import {buildEtaProfile} from './profile.mjs';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const out='output/eta_simulation/segment_ai';
const model=new EtaCorrectionModel(read(out+'/model.json')),context=read(out+'/context.json');
let maximum=0;
for(const v of read(out+'/parity_vectors.json')) maximum=Math.max(maximum,Math.abs(model.predict(v.features)-v.expected_speed_kmh));
assert.ok(maximum<1e-8);
const original=read('output/eta_simulation/parity_routes.json'), timings=[];
const profiles=original.map(f=>{
  const tick=performance.now(),p=buildEtaProfile(f.route,f.at,model,context);
  timings.push(performance.now()-tick);
  assert.equal(p.used_ai,true);assert.equal(p.profile_version,6);
  assert.ok(p.speed_profile.every(s=>s.speed_kmh>=15&&s.speed_kmh<=50&&s.used_ai));
  const sum=p.speed_profile.reduce((v,s)=>v+(s.end_meters-s.start_meters)*3.6/s.speed_kmh,0);
  assert.ok(Math.abs(sum-p.travel_minutes*60)<1e-6);
  return {name:f.name,route:f.route,at:f.at,expected_profile:p};
});
writeFileSync(out+'/parity_profiles.json',JSON.stringify(profiles));
const names=new Set(read('apps/delivery_app/test/fixtures/eta_simulation_profiles.json').map(f=>f.name));
writeFileSync('apps/delivery_app/test/fixtures/eta_simulation_profiles.json',JSON.stringify(profiles.filter(f=>names.has(f.name))));
timings.sort((a,b)=>a-b);
const report={model_cases:1000,route_cases:profiles.length,maximum_tree_error:maximum,
  warm_p50_ms:timings[Math.floor(timings.length*.5)],warm_p90_ms:timings[Math.floor(timings.length*.9)],
  minimum_speed:Math.min(...profiles.flatMap(f=>f.expected_profile.speed_profile.map(s=>s.speed_kmh)))};
writeFileSync(out+'/javascript_verification.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report));
