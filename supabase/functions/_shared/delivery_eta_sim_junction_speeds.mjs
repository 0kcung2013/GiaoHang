const cache = new WeakMap(), CELL = .0025, METERS = 111195.0802335329;

export function routeJunctions(raw) {
  const points = new Map();
  const add = p => {
    if (Array.isArray(p) && p.length === 2 && p.every(Number.isFinite)
      && Math.abs(p[0]) <= 180 && Math.abs(p[1]) <= 90) points.set(p.join(','), p);
  };
  for (const p of raw.junction_points ?? []) add(p);
  for (const leg of raw.legs ?? []) for (const step of leg.steps ?? [])
    for (const intersection of step.intersections ?? [])
      if (intersection.bearings?.length >= 3) add(intersection.location);
  return [...points.values()];
}

export function junctionField(context, points) {
  const decoded = cache.get(context) ?? new Map(); cache.set(context, decoded);
  const extra = new Map();
  // Complete regional OSM coverage takes precedence over route-derived points:
  // choosing a different endpoint must never add/remove a nearby slowdown.
  for (const p of context.junction_bounds ? [] : points) {
    const key = `${Math.floor(p[0] / CELL)},${Math.floor(p[1] / CELL)}`;
    if (!extra.has(key)) extra.set(key, []); extra.get(key).push(p);
  }
  return point => {
    const scale = context.junction_coordinate_scale ?? 100000, ticks = context.junction_cell_ticks ?? 250;
    const x = Math.floor(point[0] * scale / ticks), y = Math.floor(point[1] * scale / ticks);
    let nearest = Infinity;
    for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
      const cx = x + dx, cy = y + dy, key = `${cx},${cy}`;
      if (!decoded.has(key)) {
        const bytes = atob(context.junction_cells?.[key] ?? ''), values = [];
        for (let i = 0; i + 1 < bytes.length; i += 2)
          values.push([(cx * ticks + bytes.charCodeAt(i)) / scale, (cy * ticks + bytes.charCodeAt(i + 1)) / scale]);
        decoded.set(key, values);
      }
      for (const p of [...decoded.get(key), ...(extra.get(key) ?? [])]) {
        const meters = Math.hypot((p[0] - point[0]) * Math.cos(point[1] * Math.PI / 180), p[1] - point[1]) * METERS;
        nearest = Math.min(nearest, meters);
      }
    }
    // These spatial zones apply even at noon. They do not depend on whether
    // this particular route turns left, right, or continues through the node.
    return nearest <= 18 ? .6 : nearest <= 36 ? .32 : 0;
  };
}
