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

export async function quoteRoute(points, fetcher = fetch) {
  try {
    const coords = points.map(p => p.join(',')).join(';');
    const response = await fetcher(
      `https://router.project-osrm.org/route/v1/driving/${coords}?overview=false`,
      { signal: AbortSignal.timeout(4000) },
    );
    if (!response.ok) throw new Error('ROUTE_UNAVAILABLE');
    const result = await response.json();
    const seconds = result.routes?.[0]?.duration;
    if (result.code !== 'Ok' || !Number.isFinite(seconds) || seconds < 0 || seconds > 86400) {
      throw new Error('INVALID_ROUTE');
    }
    return { seconds: Math.ceil(seconds), source: 'osrm' };
  } catch {
    // Conservative fallback: road distance = direct distance * 1.5 at 20 km/h.
    let distance = 0;
    for (let i = 1; i < points.length; i++) distance += distanceMeters(points[i - 1], points[i]);
    return { seconds: Math.min(86400, Math.ceil(distance * 1.5 / (20000 / 3600))), source: 'distance_fallback' };
  }
}
