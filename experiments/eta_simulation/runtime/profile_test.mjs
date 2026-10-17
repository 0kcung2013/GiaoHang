import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {EtaCorrectionModel} from './model.mjs';
import {buildEtaProfile} from './profile.mjs';
import {distance} from './features.mjs';
import {buildEtaProfile as server} from '../../../supabase/functions/_shared/delivery_eta_sim_profile.mjs';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const model=new EtaCorrectionModel(read('packages/giaohang_mobile/assets/ml/eta_simulation_model.json'));
const context=read('packages/giaohang_mobile/assets/ml/eta_simulation_context.json');
const fixtures=read('packages/giaohang_mobile/test/fixtures/eta_simulation_profiles.json');
const at='2026-10-07T18:00:00+07:00',noon='2026-10-07T12:00:00+07:00';
const route=points=>{const meters=points.slice(1).reduce((sum,p,i)=>sum+distance(points[i],p),0);return {distance:meters,duration:meters*.144,geometry:{coordinates:points},legs:[]};};
function verify(p,r) {
  assert.equal(p.profile_version,6);assert.equal(p.used_ai,true);assert.equal(p.is_synthetic,true);
  assert.equal(p.ai_coverage_ratio,1);assert.equal(p.color_metric,'speed_kmh');
  assert.equal(p.speed_profile[0].start_meters,0);assert.equal(p.speed_profile.at(-1).end_meters,r.distance);
  let end=0;
  for(const s of p.speed_profile) {
    assert.ok(Math.abs(s.start_meters-end)<1e-8);assert.ok(s.end_meters>s.start_meters);
    assert.ok(s.speed_kmh>=15&&s.speed_kmh<=50);assert.equal(s.used_ai,true);end=s.end_meters;
  }
  const minutes=p.speed_profile.reduce((sum,s)=>sum+(s.end_meters-s.start_meters)*.06/s.speed_kmh,0);
  assert.ok(Math.abs(minutes-p.travel_minutes)<1e-8);
}
test('1000 exported trees reproduce held-out Python predictions',()=>{
  for(const f of read('packages/giaohang_mobile/test/fixtures/eta_simulation_vectors.json'))
    assert.ok(Math.abs(model.predict(f.features)-f.expected_speed_kmh)<1e-8);
});
test('AI is the primary speed/ETA source; Edge and preview profiles match',()=>{
  for(const f of fixtures) {
    const p=buildEtaProfile(f.route,f.at,model,context);verify(p,f.route);
    assert.deepEqual(p,server(f.route,f.at,model,context));
    assert.deepEqual(p,{...f.expected_profile,coverage_version:'hcm_training_bounds_v1'});
  }
});
test('changing learned model predictions changes movement time and speeds',()=>{
  const f=fixtures[0];
  const profiles=[20,40].map(n=>buildEtaProfile(f.route,at,{metadata:model.metadata,predict:()=>n},context));
  assert.ok(profiles[0].speed_profile.every(s=>s.speed_kmh===20));
  assert.ok(profiles[1].speed_profile.every(s=>s.speed_kmh===40));
  assert.ok(Math.abs(profiles[0].travel_minutes/profiles[1].travel_minutes-2)<1e-8);
  for(const [prediction,expected] of [[0,15],[100,50]]) {
    const p=buildEtaProfile(f.route,at,{metadata:model.metadata,predict:()=>prediction},context);
    assert.ok(p.speed_profile.every(s=>s.speed_kmh===expected));
  }
  assert.throws(()=>buildEtaProfile(f.route,at,{metadata:model.metadata,predict:()=>{throw Error('model failed');}},context));
});
test('shared fallback road features survive endpoint and route-duration changes',()=>{
  const a=route([[106.6001,10.7503],[106.6409,10.7503]]);
  const b={...route([[106.5982,10.7503],[106.6205,10.7503],[106.6462,10.7503]]),duration:160};
  const shared=new Map(buildEtaProfile(b,at,model,context).speed_profile.map(s=>[s.segment_id,s.speed_kmh]));
  for(const s of buildEtaProfile(a,at,model,context).speed_profile) assert.equal(s.speed_kmh,shared.get(s.segment_id));
});
test('partial shared OSRM roads retain speeds despite changed route total and next junctions',()=>{
  const f=fixtures[0],r=f.route,a=r.legs[0].annotation,n=Math.min(30,r.geometry.coordinates.length-1);
  const section={...r,distance:a.distance.slice(0,n).reduce((s,v)=>s+v,0),duration:300,
    geometry:{coordinates:r.geometry.coordinates.slice(0,n+1)},
    legs:[{annotation:{nodes:a.nodes.slice(0,n+1),distance:a.distance.slice(0,n),duration:a.duration.slice(0,n)}}],
    junction_points:[[106.6009,10.7503]]};
  const shared=new Map(buildEtaProfile(r,noon,model,context).speed_profile.map(s=>[s.segment_id,s.speed_kmh]));
  for(const s of buildEtaProfile(section,noon,model,context).speed_profile) assert.equal(s.speed_kmh,shared.get(s.segment_id));
});
test('120 arbitrary routes remain deterministic, covered, and slower during peak',()=>{
  const routes=read('output/eta_simulation/routes.json');let seed=73;
  for(let i=0;i<120;i++) {
    seed=seed*48271%2147483647;const r=routes[seed%routes.length].route;
    const p=buildEtaProfile(r,at,model,context),off=buildEtaProfile(r,noon,model,context);
    verify(p,r);verify(off,r);assert.ok(p.travel_minutes>off.travel_minutes);
    assert.deepEqual(p,buildEtaProfile(r,at,model,context));
  }
});
test('unseen routes inside training bounds still invoke AI with fallback road features',()=>{
  const missing={...context,cells:{},speed_roads:null};
  for(const r of [route([[106.5,10.85],[106.52,10.87]]),route([[106.6,10.75],[106.8,10.66],[106.89,10.7]]),
    route([[106.6,10.75],[106.60001,10.75001]])]) verify(buildEtaProfile(r,at,model,missing),r);
});

test('expanded OSM coverage does not allow AI beyond the training graph',()=>{
  const neverPredict={metadata:model.metadata,predict:()=>{throw Error('outside route must not invoke AI');}};
  for(const points of [
    [[106.5,11.15],[106.52,11.17]],
    [[106.6,10.75],[106.9,10.6],[107.2,10.7]],
    [[106.6,10.75],[106.6,10.95001],[106.61,10.76]],
    [[106.6,10.75],[106.49999,10.8],[106.61,10.76]],
    [[106.6,10.75],[106.90001,10.8],[106.61,10.76]],
  ]) {
    const r=route(points),p=buildEtaProfile(r,at,neverPredict,context);
    assert.equal(p.used_ai,false);assert.equal(p.all_sections_ai,false);
    assert.equal(p.ai_coverage_ratio,0);assert.equal(p.ai_distance_meters,0);
    assert.equal(p.coverage_version,'hcm_training_bounds_v1');
    assert.equal(p.fallback_reason,'outside_training_area');
    assert.equal(p.speed_profile.length,1);assert.equal(p.speed_profile[0].traffic_available,false);
    assert.ok(Math.abs(p.travel_minutes-r.duration/60)<1e-8);
    assert.deepEqual(p,server(r,at,neverPredict,context));
  }
});
test('alleys are slower than arterial roads outside peak, using the trained model',()=>{
  const r=route([[106.6001,10.7503],[106.6029,10.7503]]);
  const withSpeed=speed=>({...r,legs:[{annotation:{distance:[r.distance],duration:[r.distance*3.6/speed]}}]});
  const narrow=buildEtaProfile(withSpeed(15),noon,model,context),wide=buildEtaProfile(withSpeed(50),noon,model,context);
  assert.ok(narrow.speed_profile.every(s=>s.speed_kmh>=15&&s.speed_kmh<25));
  assert.ok(wide.speed_profile.every(s=>s.speed_kmh>=35));
  assert.ok(narrow.travel_minutes>wide.travel_minutes);
});
test('invalid inputs are rejected, outside-region fallback and zero distance stay honest',()=>{
  const r=fixtures[0].route;
  assert.throws(()=>buildEtaProfile({...r,distance:-1},at,model,context));
  assert.throws(()=>buildEtaProfile(r,'bad-time',model,context));
  const other=route([[105.7,21.05],[105.72,21.06]]),p=buildEtaProfile(other,at,model,context);
  assert.equal(p.used_ai,false);assert.equal(p.is_synthetic,false);
  assert.equal(buildEtaProfile({...r,distance:0},at,model,context).travel_minutes,0);
});
