// Geometry describes the actual turn taken, including a turn between OSM ways.
export function routeTurns(points, lengths) {
  const cumulative=[0];
  for(const meters of lengths) cumulative.push(cumulative.at(-1)+meters);
  const candidates=[];
  for(let i=1;i<points.length-1;i++) {
    let before=i-1,after=i+1;
    while(before>0&&cumulative[i]-cumulative[before]<12) before--;
    while(after<points.length-1&&cumulative[after]-cumulative[i]<12) after++;
    if(cumulative[i]-cumulative[before]<2||cumulative[after]-cumulative[i]<2) continue;
    const cos=Math.cos(points[i][1]*Math.PI/180);
    const bearing=(a,b)=>Math.atan2((b[0]-a[0])*cos,b[1]-a[1]);
    const delta=bearing(points[i],points[after])-bearing(points[before],points[i]);
    const angle=Math.abs(Math.atan2(Math.sin(delta),Math.cos(delta)))*180/Math.PI;
    if(angle<30) continue;
    const turn={at:cumulative[i],strength:Math.min(1,angle/90)};
    const previous=candidates.at(-1);
    if(previous&&turn.at-previous.at<25) {
      if(turn.strength>previous.strength) candidates[candidates.length-1]=turn;
    } else candidates.push(turn);
  }
  return candidates;
}
export function turnIntensity(turns,at) {
  let value=0;
  for(const turn of turns) {
    const delta=at-turn.at,zone=delta<0?55+15*turn.strength:35+15*turn.strength;
    value=Math.max(value,turn.strength*Math.max(0,1-Math.max(0,Math.abs(delta)-6)/(zone-6)));
  }
  return Math.round(value*1e6)/1e6;
}
export function turnCuts(turns,start,length) {
  const values=[0,1];
  for(const turn of turns) {
    const from=turn.at-55-15*turn.strength,to=turn.at+35+15*turn.strength;
    if(to<=start||from>=start+length) continue;
    for(let at=from;at<to;at+=8) if(at>start&&at<start+length) values.push((at-start)/length);
    for(const at of [turn.at-6,turn.at,turn.at+6,to]) if(at>start&&at<start+length) values.push((at-start)/length);
  }
  return values;
}
// A stable local road context: destination and total route duration never enter.
export function roadVariation(a,b) {
  const x=(a[0]+b[0])/2,y=(a[1]+b[1])/2;
  const cellX=Math.floor(x/.002),cellY=Math.floor(y/.002);
  return ((cellX*73856093+cellY*19349663)%1009)/1008;
}
