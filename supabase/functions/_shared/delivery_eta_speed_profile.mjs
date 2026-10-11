import { predictSpeed, supportsPoint } from './delivery_eta_traffic.mjs';

export function demoForecastOrigin(key, assignedAt) {
  if (key === 'peak') return Date.parse('2024-04-03T07:00:00+07:00');
  if (key === 'off_peak') return Date.parse('2024-04-03T14:00:00+07:00');
  return Date.parse(assignedAt);
}

// A forecast profile, not a GPS history. Distance is the exact OSRM length.
export function buildRouteSpeedProfile(route, at, {fallbackSpeed = 25} = {}) {
  const start = Date.parse(at);
  if (!Number.isFinite(start) || !Number.isFinite(route?.distance_meters)
      || route.distance_meters < 0 || !Array.isArray(route.points)
      || route.points.length < 2) return null;
  const supported = route.distance_meters >= 100 && route.distance_meters <= 25000
    && route.points.every(supportsPoint);
  let minutes = 0, usedAi = supported;
  const sections = [];
  for (let from = 0; from < route.distance_meters; from += 250) {
    const to = Math.min(from + 250, route.distance_meters);
    const forecast = new Date(start + minutes * 60000).toISOString();
    const predicted = supported ? predictSpeed(forecast) : null;
    const speed = predicted ?? fallbackSpeed;
    if (predicted === null) usedAi = false;
    const travel = (to - from) / 1000 / speed * 60;
    sections.push({start_meters:from,end_meters:to,speed_kmh:speed,
      forecast_at:forecast,travel_minutes:travel});
    minutes += travel;
  }
  return {travel_minutes:minutes,used_ai:usedAi,route_points:route.points,
    speed_profile:sections,forecast_at:new Date(start).toISOString()};
}
