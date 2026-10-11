export function validPoint(lat, lng) {
  return typeof lat === 'number' && typeof lng === 'number' &&
    Number.isFinite(lat) && Number.isFinite(lng) &&
    Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && (lat !== 0 || lng !== 0);
}

export function distanceMeters(a, b) {
  const rad = Math.PI / 180;
  const sinLat = Math.sin((b[1] - a[1]) * rad / 2);
  const sinLng = Math.sin((b[0] - a[0]) * rad / 2);
  const h = sinLat ** 2 + Math.cos(a[1] * rad) * Math.cos(b[1] * rad) * sinLng ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
}

function supportsTraffic(points, traffic) {
  try {
    return typeof traffic?.supportsPoint === 'function' &&
      typeof traffic?.predict === 'function' &&
      Number.isFinite(Date.parse(traffic.at)) &&
      points.every(point => traffic.supportsPoint(point));
  } catch {
    return false;
  }
}

function trafficAdjustedSeconds(route, traffic) {
  try {
    const points = route.geometry?.coordinates;
    if (route.geometry?.type !== 'LineString' ||
      !Number.isFinite(route.distance) || route.distance < 0 ||
      !Array.isArray(points) || points.length < 2 ||
      !points.every(p => Array.isArray(p) && validPoint(p[1], p[0]))) {
      return route.duration;
    }
    const multiplier = traffic.predict({
      distance_meters: route.distance, points,
    }, traffic.at);
    return Number.isFinite(multiplier) && multiplier >= 1
      ? Math.min(86400, route.duration * multiplier)
      : route.duration;
  } catch {
    // Model unavailable: retain the valid OSRM duration and existing buffers.
    return route.duration;
  }
}

export async function quoteRoute(points, fetcher = fetch, traffic = null) {
  const useTraffic = supportsTraffic(points, traffic);
  try {
    const coords = points.map(p => p.join(',')).join(';');
    const geometry = useTraffic
      ? 'overview=full&geometries=geojson'
      : 'overview=false';
    const response = await fetcher(
      `https://router.project-osrm.org/route/v1/driving/${coords}?${geometry}`,
      { signal: AbortSignal.timeout(4000) },
    );
    if (!response.ok) throw new Error('ROUTE_UNAVAILABLE');
    const result = await response.json();
    const route = result.routes?.[0];
    let seconds = route?.duration;
    if (result.code !== 'Ok' || !Number.isFinite(seconds) || seconds < 0 || seconds > 86400) {
      throw new Error('INVALID_ROUTE');
    }
    if (useTraffic) seconds = trafficAdjustedSeconds(route, traffic);
    return { seconds: Math.ceil(seconds), source: 'osrm' };
  } catch {
    // Conservative fallback: road distance = direct distance * 1.5 at 20 km/h.
    let distance = 0;
    for (let i = 1; i < points.length; i++) distance += distanceMeters(points[i - 1], points[i]);
    return { seconds: Math.min(86400, Math.ceil(distance * 1.5 / (20000 / 3600))), source: 'distance_fallback' };
  }
}
