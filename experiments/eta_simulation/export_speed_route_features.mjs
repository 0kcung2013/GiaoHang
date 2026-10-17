// The exact runtime geometry/OSM feature extraction is used for route evaluation.
import {readFileSync,writeFileSync} from 'node:fs';
import {buildSegmentSpeeds} from './runtime/segment_speeds.mjs';
const out='output/eta_simulation/segment_ai';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const context=read('apps/delivery_app/assets/ml/eta_simulation_context.json');
const stub={metadata:{target:'segment_speed_kmh'},predict:()=>30};
const cases=[];
for(const record of read(out+'/reserved_routes.json')) for(const hour of [7.75,12,17.5]) {
  const at=`2026-10-07T${String(Math.floor(hour)).padStart(2,'0')}:${hour%1?'45':'00'}:00+07:00`;
  // 17.5 is 17:30, not 17:45.
  const timestamp=hour===17.5?'2026-10-07T17:30:00+07:00':at;
  cases.push({route_id:record.route_id,hour,sections:buildSegmentSpeeds(record.route,context,timestamp,stub)
    .map(s=>({features:s.features,meters:s.end_meters-s.start_meters}))});
}
writeFileSync(out+'/held_out_route_features.json',JSON.stringify(cases));
console.log(JSON.stringify({cases:cases.length,sections:cases.reduce((n,c)=>n+c.sections.length,0)}));
