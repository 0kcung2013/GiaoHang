const CELL=.001, METERS=111195.0802335329;
const radians=value=>value*Math.PI/180;
export function distance(a,b) {
  const lat1=radians(a[1]),lat2=radians(b[1]);
  const h=Math.sin((lat2-lat1)/2)**2+Math.cos(lat1)*Math.cos(lat2)*Math.sin(radians(b[0]-a[0])/2)**2;
  return 6371008.8*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)));
}
export class RoadMatcher {
  constructor(network) {
    this.policy=network.matching_policy; this.bounds=network.bounds;
    this.roads=network.roads.map(values=>Object.fromEntries(network.fields.map((key,i)=>[key,values[i]])));
    this.grid=new Map(); this.nodePairs=new Map();
    this.roads.forEach((road,index)=>{
      road.midpoint_lat=(road.start_lat+road.end_lat)/2; road.midpoint_lng=(road.start_lng+road.end_lng)/2;
      for (let x=Math.floor(Math.min(road.start_lng,road.end_lng)/CELL);x<=Math.floor(Math.max(road.start_lng,road.end_lng)/CELL);x++)
        for (let y=Math.floor(Math.min(road.start_lat,road.end_lat)/CELL);y<=Math.floor(Math.max(road.start_lat,road.end_lat)/CELL);y++) {
          const key=`${x},${y}`; if (!this.grid.has(key)) this.grid.set(key,[]); this.grid.get(key).push(index);
        }
      const key=`${road.s_node_id},${road.e_node_id}`; if (!this.nodePairs.has(key)) this.nodePairs.set(key,[]); this.nodePairs.get(key).push(index);
    });
  }
  supports(p) { return Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)
    &&p[0]>=this.bounds.min_lng&&p[0]<=this.bounds.max_lng&&p[1]>=this.bounds.min_lat&&p[1]<=this.bounds.max_lat; }
  match(a,b,nodePair=null) {
    if (!this.supports(a)||!this.supports(b)) return [null,'outside_scope'];
    const midpoint=[(a[0]+b[0])/2,(a[1]+b[1])/2],x=Math.floor(midpoint[0]/CELL),y=Math.floor(midpoint[1]/CELL);
    const candidates=new Set();
    for (const dx of [-1,0,1]) for (const dy of [-1,0,1]) for (const i of this.grid.get(`${x+dx},${y+dy}`)??[]) candidates.add(i);
    const exact=new Set(nodePair?this.nodePairs.get(nodePair.join(','))??[]:[]),scored=[],cosine=Math.cos(radians(midpoint[1]));
    for (const i of candidates) {
      const r=this.roads[i],rx=(r.end_lng-r.start_lng)*cosine*METERS,ry=(r.end_lat-r.start_lat)*METERS;
      const length=Math.hypot(rx,ry),ex=(b[0]-a[0])*cosine*METERS,ey=(b[1]-a[1])*METERS,edge=Math.hypot(ex,ey);
      if (!length||!edge||(rx*ex+ry*ey)/(length*edge)<Math.cos(radians(this.policy.maximum_heading_degrees))) continue;
      let lateral=0,accepted=true;
      for (const p of [a,midpoint,b]) {
        const px=(p[0]-r.start_lng)*cosine*METERS,py=(p[1]-r.start_lat)*METERS,projection=(px*rx+py*ry)/length;
        lateral=Math.max(lateral,Math.abs(px*ry-py*rx)/length);
        if (projection< -this.policy.endpoint_slack_meters||projection>length+this.policy.endpoint_slack_meters) accepted=false;
      }
      if (accepted&&lateral<=this.policy.maximum_lateral_meters) scored.push([lateral,i]);
    }
    if (!scored.length) return [null,'no_directed_geometry_match'];
    scored.sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
    const exactScored=scored.filter(p=>exact.has(p[1]));
    if (exactScored.length===1) return [this.roads[exactScored[0][1]],'directed_nodes_and_geometry'];
    if (scored.length>1&&scored[1][0]-scored[0][0]<this.policy.ambiguity_margin_meters) return [null,'ambiguous_parallel_or_overlapping'];
    return [this.roads[scored[0][1]],'directed_geometry'];
  }
}
