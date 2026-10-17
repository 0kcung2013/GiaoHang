import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {buildEtaProfile} from './profile.mjs';
import {EtaCorrectionModel} from './model.mjs';
import {distance} from './features.mjs';

const read=p=>JSON.parse(readFileSync(p,'utf8'));
const model=new EtaCorrectionModel(read('apps/delivery_app/assets/ml/eta_simulation_model.json'));
const context={...read('apps/delivery_app/assets/ml/eta_simulation_context.json'),speed_roads:null};
const noon='2026-10-07T12:00:00+07:00';
function route(points, rawSpeed=50) {
  const lengths=points.slice(1).map((p,i)=>distance(points[i],p));
  return {distance:lengths.reduce((s,v)=>s+v,0),duration:lengths.reduce((s,v)=>s+v,0)*3.6/rawSpeed,
    geometry:{coordinates:points},legs:[{annotation:{distance:lengths,duration:lengths.map(v=>v*3.6/rawSpeed)}}]};
}
const cornerRoute=route([[106.65,10.8],[106.653,10.8],[106.653,10.803]]);
const speedAt=(p,at)=>p.speed_profile.find(s=>s.end_meters>at)?.speed_kmh??p.speed_profile.at(-1).speed_kmh;
test('90-degree turn brakes beforehand, slows at the apex and accelerates afterwards',()=>{
  const p=buildEtaProfile(cornerRoute,noon,model,context);
  const apex=distance(...cornerRoute.geometry.coordinates.slice(0,2));
  assert.ok(speedAt(p,20)>40);
  assert.ok(speedAt(p,apex-35)<speedAt(p,20)-5);
  assert.ok(speedAt(p,apex)>=15&&speedAt(p,apex)<=23);
  assert.ok(speedAt(p,apex+25)>speedAt(p,apex)+3);
  assert.ok(speedAt(p,p.distance_meters-20)>40);
});
test('a straight residential road runs above 31 km/h and is slower in peak time',()=>{
  const r=route([[106.65,10.8],[106.655,10.8]],30);
  const off=buildEtaProfile(r,noon,model,context),peak=buildEtaProfile(r,'2026-10-07T17:30:00+07:00',model,context);
  assert.ok(off.speed_profile.every(s=>s.speed_kmh>31&&s.speed_kmh<=41));
  assert.ok(peak.travel_minutes>off.travel_minutes);
});
test('different destination turns change only the local turning region',()=>{
  const straight=route([[106.65,10.8],[106.653,10.8],[106.656,10.8]]);
  const a=buildEtaProfile(cornerRoute,noon,model,context),b=buildEtaProfile(straight,noon,model,context);
  assert.equal(speedAt(a,100),speedAt(b,100));
  assert.ok(speedAt(a,310)<speedAt(b,310));
});
