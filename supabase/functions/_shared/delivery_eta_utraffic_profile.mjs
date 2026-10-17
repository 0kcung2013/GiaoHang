import {distance} from './delivery_eta_road_matcher.mjs';
function appendSection(sections,section) {
  const keys=['speed_kmh','used_ai','segment_id','match_method','training_count'],last=sections.at(-1);
  if (last&&keys.every(key=>last[key]===section[key])) {
    last.end_meters=section.end_meters; last.travel_minutes+=section.travel_minutes;
  } else sections.push(section);
}
export function buildRouteSpeedProfile(route,at,model,matcher,{fallbackSpeed=25}={}) {
  const points=route.geometry?.coordinates,total=route.distance,start=Date.parse(at);
  if (!Number.isFinite(start)||!Number.isFinite(total)||total<=0||!Array.isArray(points)||points.length<2
      ||!Number.isFinite(fallbackSpeed)||fallbackSpeed<=0||fallbackSpeed>90) throw new Error('INVALID_ROUTE_PROFILE');
  if (!points.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&Math.abs(p[1])<=90&&Math.abs(p[0])<=180)) throw new Error('INVALID_ROUTE_GEOMETRY');
  const lengths=points.slice(1).map((p,i)=>distance(points[i],p)),geometryLength=lengths.reduce((a,b)=>a+b,0);
  if (!geometryLength) throw new Error('EMPTY_ROUTE_GEOMETRY');
  const nodes=route.legs?.[0]?.annotation?.nodes??[],aligned=nodes.length===points.length;
  let along=0,minutes=0,aiDistance=0; const sections=[];
  for (let i=0;i<lengths.length;i++) {
    const a=points[i],b=points[i+1],length=lengths[i]; if (!length) continue;
    const count=Math.max(1,Math.ceil(length/matcher.policy.probe_meters));
    for (let part=0;part<count;part++) {
      const first=a.map((v,j)=>v+(b[j]-v)*part/count),second=a.map((v,j)=>v+(b[j]-v)*(part+1)/count);
      let [road,method]=matcher.match(first,second,aligned?[nodes[i],nodes[i+1]]:null);
      const forecast=new Date(start+minutes*60000).toISOString(); let predicted=null;
      if (road&&total<=25000&&model) { try { predicted=model.speedAt(road,forecast); } catch {} }
      const usedAi=Number.isFinite(predicted)&&predicted>0&&predicted<=90;
      if (road&&!usedAi) method=total>25000?'distance_outside_scope':'model_unavailable_or_invalid';
      const speed=usedAi?predicted:fallbackSpeed,from=along;
      along+=length/count*total/geometryLength;
      const travel=(along-from)*.06/speed;
      appendSection(sections,{start_meters:from,end_meters:along,speed_kmh:speed,used_ai:usedAi,forecast_at:forecast,
        travel_minutes:travel,segment_id:road?.segment_id??null,source:usedAi?'utraffic_lightgbm':'fallback_25_kmh',
        match_method:method,training_count:road?.training_count??0});
      minutes+=travel; if (usedAi) aiDistance+=along-from;
    }
  }
  const last=sections.at(-1),correction=total-last.end_meters;
  minutes+=correction*.06/last.speed_kmh; last.travel_minutes+=correction*.06/last.speed_kmh; last.end_meters=total;
  if (last.used_ai) aiDistance+=correction;
  return {distance_meters:total,route_points:points,forecast_at:new Date(start).toISOString(),speed_profile:sections,
    travel_minutes:minutes,used_ai:aiDistance>0,all_sections_ai:sections.every(s=>s.used_ai),ai_distance_meters:aiDistance,
    ai_coverage_ratio:aiDistance/total,model_version:model?.metadata.version??null};
}
