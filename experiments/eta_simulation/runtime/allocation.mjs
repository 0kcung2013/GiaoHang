import {contextAt,distance} from './features.mjs';

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const decoded=new WeakMap();
function junctions(point,context) {
  let cache=decoded.get(context);if(!cache){cache=new Map();decoded.set(context,cache);}
  const scale=context.junction_coordinate_scale??100000,ticks=context.junction_cell_ticks??250;
  const cx=Math.floor(point[0]*scale/ticks),cy=Math.floor(point[1]*scale/ticks),result=[];
  for(let x=cx-1;x<=cx+1;x++)for(let y=cy-1;y<=cy+1;y++) {
    const key=`${x},${y}`;let points=cache.get(key);
    if(!points) {
      const encoded=context.junction_cells?.[key],bytes=encoded?atob(encoded):'';points=[];
      for(let i=0;i+1<bytes.length;i+=2)points.push({id:`${key}:${i}`,point:[(x*ticks+bytes.charCodeAt(i))/scale,(y*ticks+bytes.charCodeAt(i+1))/scale]});
      cache.set(key,points);
    }
    result.push(...points);
  }
  return result;
}

function stopZones(route,context,lengths,totalGeometry) {
  const points=route.geometry.coordinates,candidates=new Map(),ratio=route.distance/totalGeometry;
  let along=0,previous=null;
  for(let i=0;i<lengths.length;i++) {
    const a=points[i],b=points[i+1],length=lengths[i];if(length<=.1)continue;
    const cosine=Math.cos((a[1]+b[1])/2*Math.PI/180),dx=(b[0]-a[0])*cosine,dy=b[1]-a[1];
    const denominator=dx*dx+dy*dy,bearing=Math.atan2(dx,dy);
    if(previous!==null&&Math.abs(Math.atan2(Math.sin(bearing-previous),Math.cos(bearing-previous)))>=Math.PI/4)
      candidates.set(`turn:${i}`,{at:along*ratio,source:'route_turn',priority:2,error:0});
    previous=bearing;
    const probes=Math.max(1,Math.ceil(length/100)),seen=new Set();
    for(let probe=0;probe<probes;probe++) {
      const midpoint=a.map((v,k)=>v+(b[k]-v)*(probe+.5)/probes);
      for(const junction of junctions(midpoint,context)) {
        if(seen.has(junction.id))continue;seen.add(junction.id);
        const p=junction.point,px=(p[0]-a[0])*cosine,py=p[1]-a[1];
        const t=clamp((px*dx+py*dy)/denominator,0,1);
        const error=Math.hypot(px-dx*t,py-dy*t)*111195;
        if(error>8)continue;
        const at=(along+t*length)*ratio,key=`${junction.id}:${Math.floor(at/80)}`;
        const existing=candidates.get(key);
        if(!existing||error<existing.error)candidates.set(key,{at,source:'osm_junction',priority:1,error});
      }
    }
    along+=length;
  }
  const accepted=[];
  for(const candidate of [...candidates.values()].filter(c=>c.at>=20&&c.at<=route.distance-20)
    .sort((a,b)=>b.priority-a.priority||a.at-b.at||a.error-b.error)) {
    if(accepted.some(c=>Math.abs(c.at-candidate.at)<80))continue;
    accepted.push(candidate);
  }
  return accepted.sort((a,b)=>a.at-b.at).map(c=>({at_meters:c.at,start_meters:Math.max(0,c.at-25),
    end_meters:Math.min(route.distance,c.at+25),source:c.source,weight:c.priority}));
}

export function buildTravelAllocation(route,context,at) {
  const points=route.geometry.coordinates,lengths=points.slice(1).map((p,i)=>distance(points[i],p));
  const totalGeometry=lengths.reduce((a,b)=>a+b,0);
  if(!(totalGeometry>0))throw new Error('EMPTY_ETA_ALLOCATION');
  const annotation=route.legs?.[0]?.annotation,annotated=annotation?.duration?.length===lengths.length
    &&annotation.duration.every(v=>Number.isFinite(v)&&v>=0);
  const wall=new Date(Date.parse(at)+7*3600000),hour=wall.getUTCHours()+wall.getUTCMinutes()/60,weekday=(wall.getUTCDay()+6)%7;
  const peak=Math.max(Math.exp(-.5*((hour-7.8)/1.05)**2),Math.exp(-.5*((hour-17.5)/1.25)**2))*(weekday>=5?.48:1);
  const zones=stopZones(route,context,lengths,totalGeometry),cuts=zones.flatMap(z=>[z.start_meters,z.at_meters,z.end_meters]);
  const parts=[];let along=0,baselineSum=0;
  for(let i=0;i<lengths.length;i++) {
    const a=points[i],b=points[i+1],length=lengths[i];if(length<=.1)continue;
    const count=Math.max(1,Math.ceil(length/100));
    for(let j=0;j<count;j++) {
      const midpoint=a.map((v,k)=>v+(b[k]-v)*(j+.5)/count),cell=contextAt(midpoint,context);
      const meters=length/count*route.distance/totalGeometry;
      const baseline=annotated&&annotation.duration[i]>0?annotation.duration[i]/count:route.duration*length/count/totalGeometry*(.9+.3*cell[0]);
      const from=along,to=along+meters,boundaries=[from,...cuts.filter(c=>c>from+1e-7&&c<to-1e-7),to].sort((a,b)=>a-b);
      for(let k=1;k<boundaries.length;k++) {
        const start=boundaries[k-1],end=boundaries[k],center=(start+end)/2;
        const zone=zones.findIndex(z=>center>=z.start_meters&&center<=z.end_meters);
        const stopWeight=zone>=0?Math.max(0,1-Math.abs(center-zones[zone].at_meters)/25)*zones[zone].weight:0;
        parts.push({from:start,to:end,meters:end-start,baseline:baseline*(end-start)/meters,
          cruise:.98+.10*cell[0]+peak*(.35+.35*cell[0]),stopWeight,zone});
        baselineSum+=baseline*(end-start)/meters;
      }
      along=to;
    }
  }
  if(!parts.length||!(baselineSum>0))throw new Error('EMPTY_ETA_ALLOCATION');
  parts.at(-1).to=route.distance;parts.at(-1).meters=parts.at(-1).to-parts.at(-1).from;
  for(const p of parts)p.referenceSpeed=clamp(p.meters*3.6/(p.baseline*route.duration/baselineSum),1,90);
  return {parts,zones};
}

export function fitTravelAllocation(allocation,seconds) {
  const {parts,zones}=allocation;
  const speed=(p,cruiseScale,waitScale)=>clamp(p.referenceSpeed/(p.cruise*cruiseScale+p.stopWeight*waitScale),1,90);
  const duration=(cruiseScale,waitScale)=>parts.reduce((sum,p)=>sum+p.meters*3.6/speed(p,cruiseScale,waitScale),0);
  let cruiseScale=1,waitScale=0,localized=true;
  if(seconds<duration(1,0)) {
    let low=.001,high=1;
    for(let i=0;i<60;i++){const mid=(low+high)/2;if(duration(mid,0)<seconds)low=mid;else high=mid;}
    cruiseScale=(low+high)/2;
  } else if(seconds>duration(1,0)+1e-7) {
    let high=1;while(high<1048576&&duration(1,high)<seconds)high*=2;
    if(zones.length&&duration(1,high)>=seconds) {
      let low=0;for(let i=0;i<60;i++){const mid=(low+high)/2;if(duration(1,mid)<seconds)low=mid;else high=mid;}
      waitScale=(low+high)/2;
    } else {
      // Keep the model's ETA, but do not invent congestion locations.
      localized=false;let low=.001;high=1048576;
      for(let i=0;i<60;i++){const mid=(low+high)/2;if(duration(mid,0)<seconds)low=mid;else high=mid;}
      cruiseScale=(low+high)/2;
    }
  }
  const speeds=parts.map(p=>speed(p,cruiseScale,waitScale));
  const movingSeconds=parts.reduce((sum,p)=>sum+p.meters*3.6/speed(p,cruiseScale,0),0);
  const actual=parts.reduce((sum,p,i)=>sum+p.meters*3.6/speeds[i],0);
  return {speeds,localized,movingSeconds,waitingSeconds:Math.max(0,actual-movingSeconds)};
}
