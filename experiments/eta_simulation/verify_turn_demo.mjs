import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {buildEtaProfile} from './runtime/profile.mjs';
import {EtaCorrectionModel} from './runtime/model.mjs';
import {distance} from './runtime/features.mjs';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const model=new EtaCorrectionModel(read('apps/delivery_app/assets/ml/eta_simulation_model.json'));
const context={...read('apps/delivery_app/assets/ml/eta_simulation_context.json'),speed_roads:null};
const points=[[106.65,10.8],[106.653,10.8],[106.653,10.803]];
const lengths=points.slice(1).map((p,i)=>distance(points[i],p));
const route={distance:lengths.reduce((s,v)=>s+v,0),duration:lengths.reduce((s,v)=>s+v,0)*.072,
  geometry:{coordinates:points},legs:[{annotation:{distance:lengths,duration:lengths.map(v=>v*.072)}}]};
const profile=buildEtaProfile(route,'2026-10-07T12:00:00+07:00',model,context);
const stages=[['straight',20],['braking',lengths[0]-35],['corner',lengths[0]],['accelerating',lengths[0]+25],['recovered',route.distance-20]]
  .map(([name,at])=>{
    const i=at<lengths[0]?0:1,t=(at-(i?lengths[0]:0))/lengths[i];
    return {name,meters:at,point:points[i].map((v,axis)=>v+(points[i+1][axis]-v)*t),
      speed_kmh:profile.speed_profile.find(s=>at<s.end_meters)?.speed_kmh};
  });
assert.ok(stages[0].speed_kmh>40&&stages[2].speed_kmh<23&&stages[4].speed_kmh>40);
const result={route,profile,stages};
writeFileSync('apps/delivery_app/test/fixtures/eta_turn_profile.json',JSON.stringify(result));
writeFileSync('output/eta_simulation/segment_ai/turn_demo_verification.json',JSON.stringify(result,null,2));
console.log(JSON.stringify({travel_minutes:profile.travel_minutes,stages}));
