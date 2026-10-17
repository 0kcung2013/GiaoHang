import {distance, contextAt} from './delivery_eta_sim_features.mjs';
import {roadIndex, roadFeatures, trafficClock} from './delivery_eta_sim_speed_features.mjs';
import {routeTurns,turnIntensity,turnCuts,roadVariation} from './delivery_eta_sim_turn_features.mjs';
export const segmentSpeedVersion = 'hcm_synthetic_segment_speed_v2';
const CELL = .001;
export const coverageVersion = 'hcm_training_bounds_v1';
// Training graph bounds, independent of the expanded OSM attribute index.
export const supportsSpeedSimulation = route => route.geometry.coordinates.every(
  p => p[0] >= 106.50 && p[0] <= 106.90 && p[1] >= 10.65 && p[1] <= 10.95);
function gridCuts(a, b) {
  const cuts = [0, 1];
  for (let axis = 0; axis < 2; axis++) {
    const delta = b[axis] - a[axis];
    if (Math.abs(delta) < 1e-12) continue;
    for (let n = Math.floor(Math.min(a[axis], b[axis]) / CELL) + 1; n * CELL < Math.max(a[axis], b[axis]); n++) {
      const t = (n * CELL - a[axis]) / delta;
      if (t > 1e-9 && t < 1 - 1e-9) cuts.push(t);
    }
  }
  cuts.sort((a, b) => a - b);
  return cuts.filter((v, i) => i === 0 || v - cuts[i - 1] > 1e-9);
}
export function buildSegmentSpeeds(route, context, at, model) {
  if (model.metadata.target !== 'segment_speed_kmh') throw new Error('INVALID_SPEED_MODEL_TARGET');
  const points = route.geometry.coordinates;
  const lengths = points.slice(1).map((p, i) => distance(points[i], p));
  const geometry = lengths.reduce((a, b) => a + b, 0);
  if (!(geometry > 0)) throw Error('EMPTY_ETA_GEOMETRY');
  const scale = route.distance / geometry, index = roadIndex(context), clock = trafficClock(at);
  const turns=routeTurns(points,lengths); let geometryAlong=0;
  const annotation = route.legs?.[0]?.annotation;
  const alignedNodes = annotation?.nodes?.length === points.length;
  const aligned = annotation?.distance?.length === lengths.length && annotation?.duration?.length === lengths.length;
  const sections = [], predictions = new Map(); let along = 0;
  for (let i = 0; i < lengths.length; i++) {
    const a = points[i], b = points[i + 1], length = lengths[i];
    if (length <= 0) continue;
    const first = alignedNodes ? index.get(annotation.nodes[i]) : null;
    const second = alignedNodes ? index.get(annotation.nodes[i + 1]) : null;
    const raw = aligned && Number.isFinite(annotation.distance[i]) && annotation.distance[i] > 0 && Number.isFinite(annotation.duration[i]) && annotation.duration[i] > 0
      ? annotation.distance[i] * 3.6 / annotation.duration[i] : null;
    const cuts = [...gridCuts(a, b),
      ...turnCuts(turns,geometryAlong,length)].sort((a,b)=>a-b).filter((v,i,all)=>i===0||v-all[i-1]>1e-9);
    for (let j = 1; j < cuts.length; j++) {
      const t = (cuts[j - 1] + cuts[j]) / 2;
      const x = Math.floor((a[0] + (b[0] - a[0]) * t) / CELL), y = Math.floor((a[1] + (b[1] - a[1]) * t) / CELL);
      const minor = contextAt([(x + .5) * CELL, (y + .5) * CELL], context)[0];
      const fallbackClass = raw !== null ? (raw < 20 ? 0 : raw < 35 ? 1 : 2) : minor >= .8 ? 0 : minor >= .45 ? 1 : 2;
      const middle=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];
      const vector = [...roadFeatures(first, second, fallbackClass, clock),roadVariation(middle,middle),turnIntensity(turns,geometryAlong+length*t)], key = vector.map(v=>v.toFixed(6)).join(':');
      if (!predictions.has(key)) predictions.set(key, Math.round(Math.max(15, Math.min(50, model.predict(vector))) * 10) / 10);
      const speed = predictions.get(key), meters = length * (cuts[j] - cuts[j - 1]) * scale;
      const end = along + meters, travel = meters * .06 / speed, last = sections.at(-1);
      if (last?.segment_id === key) { last.end_meters = end; last.travel_minutes += travel; }
      else sections.push({start_meters: along, end_meters: end, speed_kmh: speed,
        reference_speed_kmh: [23, 37.5, 48][vector[0]], travel_minutes: travel,
        used_ai: true, traffic_available: true, is_synthetic: true,
        segment_id: key, source: segmentSpeedVersion, features: vector, road_class: vector[0],
        feature_source: first !== null || second !== null ? 'osm_nodes' : raw !== null ? 'osrm_road_class' : 'spatial_road_class',
        forecast_at: new Date(Date.parse(at)).toISOString()});
      along = end;
    }
    geometryAlong+=length;
  }
  sections.at(-1).end_meters = route.distance;
  return sections;
}
