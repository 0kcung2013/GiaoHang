import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {RoadNodeIndex} from './runtime/speed_features.mjs';
import {roadContext as edgeContext} from '../../supabase/functions/_shared/delivery_eta_sim_data.mjs';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const source=read('output/eta_simulation/speed_road_nodes.json');
const context=read('apps/delivery_app/assets/ml/eta_simulation_context.json');
const bytes=Buffer.from(source.payload,'base64'),index=new RoadNodeIndex(context),edgeIndex=new RoadNodeIndex(edgeContext);
let offset=0,previous=0,count=0;
while(offset<bytes.length) {
  let delta=0,factor=1,byte;
  do{byte=bytes[offset++];delta+=(byte&127)*factor;factor*=128;}while(byte&128);
  previous+=delta;
  assert.equal(index.ids[count],previous);
  assert.equal(index.values[count],bytes[offset++]);
  assert.equal(edgeIndex.ids[count],index.ids[count]);
  assert.equal(edgeIndex.values[count],index.values[count]);
  count++;
}
assert.equal(count,source.node_count);
const report={encoding:context.speed_roads.encoding,edge_compression:edgeContext.speed_roads.compression,node_count:count,all_ids_and_attributes_identical:true,
  context_bytes:readFileSync('apps/delivery_app/assets/ml/eta_simulation_context.json').length};
writeFileSync('output/eta_simulation/segment_ai/road_index_verification.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report));
