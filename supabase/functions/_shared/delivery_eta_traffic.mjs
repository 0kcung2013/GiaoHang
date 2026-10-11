import { modelPayload, modelVersion } from './delivery_eta_model_data.mjs';
export { modelVersion };
const data = new DataView(Uint8Array.from(atob(modelPayload), c => c.charCodeAt(0)).buffer);
const trees = [];
if (data.getUint32(0) !== 0x45544131) throw new Error('INVALID_ETA_MODEL');
let offset = 6;
for (let t = 0; t < data.getUint16(4, true); t++) {
  const count = data.getUint16(offset, true); offset += 2;
  const nodes = [];
  for (let n = 0; n < count; n++, offset += 15) nodes.push({
    feature: data.getInt16(offset, true), value: data.getFloat64(offset + 2, true),
    left: data.getInt16(offset + 10, true), right: data.getInt16(offset + 12, true),
  });
  trees.push(nodes);
}
if (offset !== data.byteLength) throw new Error('INVALID_ETA_MODEL_SIZE');

// Existing demo boundary; not a claim of measured dataset coverage.
export function supportsPoint(point) {
  return Array.isArray(point) && Number.isFinite(point[0]) && Number.isFinite(point[1])
    && point[1] >= 10.740268807 && point[1] <= 10.88658775
    && point[0] >= 106.58906115 && point[0] <= 106.7949388485;
}
export function predictSpeed(at) {
  const time = new Date(at).getTime();
  if (!Number.isFinite(time)) return null;
  const wall = new Date(time + 7 * 3600000), day = (wall.getUTCDay() + 6) % 7;
  const f = [wall.getUTCHours() + wall.getUTCMinutes()/60, day, day >= 5 ? 1 : 0];
  let speed = 0;
  for (const nodes of trees) {
    let node = nodes[0];
    while (node.feature >= 0) node = nodes[f[node.feature] <= node.value ? node.left : node.right];
    speed += node.value;
  }
  return Number.isFinite(speed) && speed > 0 && speed <= 90 ? speed : null;
}
export function routeTravelMinutes(route, at) {
  if (!Number.isFinite(route?.distance_meters) || route.distance_meters < 100 || route.distance_meters > 25000
    || !Array.isArray(route.points) || route.points.length < 2 || !route.points.every(supportsPoint)) return null;
  const start = new Date(at).getTime();
  if (!Number.isFinite(start)) return null;
  let minutes = 0;
  // Time model: use exact OSRM length in <=250m steps and advance predicted time.
  for (let remaining = route.distance_meters; remaining > 0; remaining -= 250) {
    const speed = predictSpeed(start + minutes*60000);
    if (speed === null) return null;
    minutes += Math.min(250, remaining)/1000/speed*60;
  }
  return minutes;
}
// Compatibility for route colors/legacy quote helper: 50 is a display reference.
export function predictMultiplier(point, at) {
  const speed = supportsPoint(point) ? predictSpeed(at) : null;
  return speed === null ? null : 50/speed;
}
export function routeMultiplier(route, at) {
  const minutes = routeTravelMinutes(route, at);
  return minutes === null ? null : minutes/(route.distance_meters/1000/50*60);
}
