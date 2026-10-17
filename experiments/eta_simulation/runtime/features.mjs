// The same finite pre-departure feature contract as features.py and Dart.
const CELL=.0025;
export const FEATURE_NAMES=['distance_km','baseline_minutes','base_speed_kmh','direct_km','detour_ratio',
  'minor_road_share','junction_density','signal_density','turns_per_km','start_lat','start_lng','end_lat','end_lng',
  'hour','hour_sin','hour_cos','weekday','weekend'];
export function distance(a,b) {
  const r=Math.PI/180,lat1=a[1]*r,lat2=b[1]*r;
  const h=Math.sin((lat2-lat1)/2)**2+Math.cos(lat1)*Math.cos(lat2)*Math.sin((b[0]-a[0])*r/2)**2;
  return 6371008.8*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)));
}
export const cellKey=p=>`${Math.floor(p[0]/CELL)},${Math.floor(p[1]/CELL)}`;
export const contextAt=(p,context)=>context.cells[cellKey(p)]??context.default_cell;
export function staticFeatures(route,context) {
  const points=route.geometry?.coordinates,meters=route.distance,seconds=route.duration;
  if(!Array.isArray(points)||points.length<2||!Number.isFinite(meters)||!Number.isFinite(seconds)||meters<=0||seconds<=0
    ||!points.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&Math.abs(p[0])<=180&&Math.abs(p[1])<=90)) throw new Error('INVALID_ETA_ROUTE');
  const lengths=points.slice(1).map((p,i)=>distance(points[i],p)),total=lengths.reduce((a,b)=>a+b,0);
  if(!(total>0))throw new Error('EMPTY_ETA_GEOMETRY');
  const values=[0,0,0];let turns=0,previous=null;
  for(let i=0;i<lengths.length;i++) {
    const a=points[i],b=points[i+1],length=lengths[i];if(length<=.1)continue;
    const dx=(b[0]-a[0])*Math.cos((a[1]+b[1])/2*Math.PI/180),dy=b[1]-a[1],bearing=Math.atan2(dx,dy);
    if(previous!==null&&Math.abs(Math.atan2(Math.sin(bearing-previous),Math.cos(bearing-previous)))>=Math.PI/4)turns++;
    previous=bearing;const probes=Math.max(1,Math.ceil(length/100));
    for(let part=0;part<probes;part++) {
      const p=a.map((v,j)=>v+(b[j]-v)*(part+.5)/probes),cell=contextAt(p,context);
      for(let j=0;j<3;j++)values[j]+=cell[j]*length/probes/total;
    }
  }
  const first=points[0],last=points.at(-1),direct=distance(first,last)/1000;
  return {distance_km:meters/1000,baseline_minutes:seconds/60,base_speed_kmh:Math.min(90,meters/seconds*3.6),
    direct_km:direct,detour_ratio:Math.min(10,meters/Math.max(50,direct*1000)),minor_road_share:values[0],
    junction_density:values[1],signal_density:values[2],turns_per_km:Math.min(30,turns/Math.max(.1,meters/1000)),
    start_lat:first[1],start_lng:first[0],end_lat:last[1],end_lng:last[0]};
}
export function timedFeatures(features,at) {
  const instant=Date.parse(at);if(!Number.isFinite(instant))throw new Error('INVALID_ETA_TIME');
  const wall=new Date(instant+7*3600000),hour=wall.getUTCHours()+wall.getUTCMinutes()/60,weekday=(wall.getUTCDay()+6)%7;
  const values={...features,hour,hour_sin:Math.sin(hour*2*Math.PI/24),hour_cos:Math.cos(hour*2*Math.PI/24),weekday,weekend:weekday>=5?1:0};
  return FEATURE_NAMES.map(key=>Math.floor(values[key]*1e6+.5)/1e6);
}
export function supports(route,metadata) {
  const b=metadata.bounds;
  return route.distance>=metadata.minimum_route_meters&&route.distance<=metadata.maximum_route_meters
    &&route.geometry.coordinates.every(p=>p[0]>=b.min_lng&&p[0]<=b.max_lng&&p[1]>=b.min_lat&&p[1]<=b.max_lat);
}
