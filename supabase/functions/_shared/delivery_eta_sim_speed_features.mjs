// OSM identifiers are stable across destination changes. Decode once per worker.
import {gunzipSync} from 'node:zlib';
const indexes = new WeakMap();
export class RoadNodeIndex {
  constructor(context) {
    const road = context.speed_roads;
    const encoded = road ? Uint8Array.from(atob(road.payload), c => c.charCodeAt(0)) : [];
    const bytes = road?.compression==='gzip'?gunzipSync(encoded):encoded;
    this.ids = new Float64Array(road?.node_count ?? 0);
    this.values = new Uint8Array(this.ids.length);
    let offset = 0, previous = 0;
    const take = () => {
      let delta = 0, factor = 1, byte;
      do { byte = bytes[offset++]; delta += (byte & 127) * factor; factor *= 128; } while (byte & 128);
      return delta;
    };
    for (let i = 0; i < this.ids.length;) {
      const v4=road.encoding==='attribute_optional_delta_run_v4';
      const head=v4?bytes[offset++]:null;
      const start = previous + (v4?((head&64)?take():1):take());
      const v3 = road.encoding === 'delta_attribute_optional_run_v3';
      const oldCount = road.encoding === 'delta_varint_run_count_attribute_v2' ? take() : 1;
      const attribute = v4?head:bytes[offset++];
      const count = (v3||v4) && (attribute & 128) ? take() : oldCount;
      const value = (v3||v4) ? attribute & 63 : attribute;
      if (count < 1 || i+count > this.ids.length) throw new Error('INVALID_SPEED_ROAD_INDEX');
      for(let n=0;n<count;n++,i++) { this.ids[i] = start+n; this.values[i] = value; }
      previous = start+count-1;
    }
    if (offset !== bytes.length) throw new Error('INVALID_SPEED_ROAD_INDEX');
  }
  get(id) {
    let low = 0, high = this.ids.length - 1;
    while (low <= high) {
      const middle = (low + high) >>> 1, value = this.ids[middle];
      if (value === id) return this.values[middle];
      if (value < id) low = middle + 1; else high = middle - 1;
    }
    return null;
  }
}
export function roadIndex(context) {
  if (!indexes.has(context)) indexes.set(context, new RoadNodeIndex(context));
  return indexes.get(context);
}
export function trafficClock(at) {
  const wall = new Date(Date.parse(at) + 7 * 3600000);
  const hour = wall.getUTCHours() + Math.floor(wall.getUTCMinutes() / 15) / 4;
  const weekend = [0, 6].includes(wall.getUTCDay()) ? 1 : 0;
  const peak = Math.max(Math.exp(-.5 * ((hour - 7.8) / 1.05) ** 2), Math.exp(-.5 * ((hour - 17.5) / 1.25) ** 2)) * (weekend ? .65 : 1);
  return [Math.round(peak * 1e6) / 1e6, weekend];
}
export function roadFeatures(first, second, fallbackClass, clock) {
  const found = [first, second].filter(v => v !== null);
  const kind = found.length ? Math.min(...found.map(v => v & 3)) : fallbackClass;
  const bend = found.length ? Math.max(...found.map(v => (v >> 2) & 3)) / 3 : 0;
  const junction = found.length ? found.reduce((s, v) => s + ((v >> 4) & 1), 0) / found.length : 0;
  const signal = found.length ? Math.max(...found.map(v => (v >> 5) & 1)) : 0;
  return [kind, Math.round(bend * 1e6) / 1e6, junction, signal, ...clock];
}
