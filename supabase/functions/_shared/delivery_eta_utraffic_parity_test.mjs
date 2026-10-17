import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {modelMetadata} from './delivery_eta_model_data.mjs';
import {SpeedModel} from './delivery_eta_utraffic_model.mjs';
import {buildRouteSpeedProfile} from './delivery_eta_speed_profile.mjs';
const read=name=>JSON.parse(readFileSync(new URL(`../../../apps/delivery_app/test/fixtures/utraffic_${name}.json`,import.meta.url),'utf8'));
test('deployed speed evaluator agrees with 2720 LightGBM fixtures',()=>{
  const model=new SpeedModel(modelMetadata);
  for(const c of read('parity')) assert.ok(Math.abs(model.speedAt(c.road,c.at)-c.speed_kmh)<1e-8);
});
test('deployed matcher/profile agrees with Python on 10 full route/time fixtures',()=>{
  for(const c of read('route_parity')) {
    const route=c.route;
    const actual=buildRouteSpeedProfile({distance_meters:route.distance,points:route.geometry.coordinates,
      annotation_nodes:route.legs[0].annotation.nodes},c.at);
    assert.ok(Math.abs(actual.travel_minutes-c.expected.travel_minutes)<1e-6);
    assert.equal(actual.speed_profile.length,c.expected.speed_profile.length);
    actual.speed_profile.forEach((s,i)=>{
      const expected=c.expected.speed_profile[i];
      assert.equal(s.segment_id,expected.segment_id); assert.equal(s.used_ai,expected.used_ai);
      assert.equal(s.match_method,expected.match_method);
      assert.ok(Math.abs(s.speed_kmh-expected.speed_kmh)<1e-8);
      assert.ok(Math.abs(s.start_meters-expected.start_meters)<1e-6);
      assert.ok(Math.abs(s.end_meters-expected.end_meters)<1e-6);
    });
  }
});
