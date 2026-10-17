// Research candidate. Supabase/App runtime is not modified by this module.
export class SpeedModel {
  constructor(metadata) {
    this.metadata = metadata;
    const bytes = Uint8Array.from(atob(metadata.payload), c => c.charCodeAt(0));
    const data = new DataView(bytes.buffer);
    if (data.byteLength < 6 || data.getUint32(0) !== 0x45544131) throw new Error('INVALID_MODEL');
    this.trees = [];
    let offset = 6;
    for (let t = 0; t < data.getUint16(4, true); t++) {
      const count = data.getUint16(offset, true); offset += 2;
      const nodes = [];
      for (let n = 0; n < count; n++, offset += 15) nodes.push({feature:data.getInt16(offset,true),
        value:data.getFloat64(offset+2,true),left:data.getInt16(offset+10,true),right:data.getInt16(offset+12,true)});
      this.trees.push(nodes);
    }
    if (offset !== data.byteLength) throw new Error('INVALID_MODEL_SIZE');
  }
  featuresAt(road, at) {
    const time = Date.parse(at);
    if (!Number.isFinite(time)) throw new Error('INVALID_FORECAST_TIME');
    const wall = new Date(time + 7 * 3600000), weekday = (wall.getUTCDay()+6)%7;
    const hour = wall.getUTCHours()+wall.getUTCMinutes()/60;
    const values = {...road,hour,weekday,weekend:weekday>=5?1:0,
      hour_sin:Math.sin(hour*2*Math.PI/24),hour_cos:Math.cos(hour*2*Math.PI/24)};
    return this.metadata.feature_names.map(name=>values[name]);
  }
  predict(vector) {
    if (vector.length !== this.metadata.feature_names.length || !vector.every(Number.isFinite)) throw new Error('INVALID_MODEL_FEATURES');
    let result = 0;
    for (const nodes of this.trees) {
      let node = nodes[0];
      while (node.feature >= 0) node = nodes[vector[node.feature] <= node.value ? node.left : node.right];
      result += node.value;
    }
    if (this.metadata.target === 'log1p') result = Math.expm1(result);
    if (!Number.isFinite(result)) return null;
    return Math.max(this.metadata.minimum_speed_kmh, Math.min(this.metadata.maximum_speed_kmh,result));
  }
  speedAt(road, at) { return this.predict(this.featuresAt(road,at)); }
}
