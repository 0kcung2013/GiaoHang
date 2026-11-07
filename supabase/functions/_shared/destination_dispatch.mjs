import { quoteDestinationLegs, quotePickupRoute, rankDriversByRoadDistance } from './road_distance.mjs';

export const DESTINATION_PICKUP_LIMIT = 3000;

// Each completed delivery must leave the driver closer to B by road.
export function isAlongDestinationRoute(pickup, direct, delivery, remaining) {
  return [pickup, direct, delivery, remaining].every(n => Number.isFinite(n) && n >= 0) &&
    pickup <= DESTINATION_PICKUP_LIMIT && direct > 300 && remaining < direct;
}

export async function rankDispatchDrivers(candidates, order, options = {}) {
  const pickup = { lat: order.pickup_lat, lng: order.pickup_lng };
  const delivery = { lat: order.delivery_lat, lng: order.delivery_lng };
  // Preserve every eligible candidate until AFTER routing and mode filtering.
  const ranked = await rankDriversByRoadDistance(candidates, pickup, {
    ...options, automaticRoadLimit: Math.max(DESTINATION_PICKUP_LIMIT, options.automaticRoadLimit ?? 2000),
  });
  const ordinary = ranked.filter(c => c.dispatch_mode !== 'destination' && c.distance_meters <= (options.automaticRoadLimit ?? 2000));
  const limited = ordinary.filter(c => c.dispatch_mode === 'nearby' && c.nearby_delivery_limit_m != null);
  let deliveryQuote = null;
  if (limited.length) {
    try { deliveryQuote = await quotePickupRoute(pickup, delivery, options); }
    catch { /* Only drivers requiring a delivery quote must wait for a retry. */ }
  }
  const result = ordinary.flatMap(c => {
    if (c.dispatch_mode !== 'nearby' || c.nearby_delivery_limit_m == null) return [c];
    return deliveryQuote && deliveryQuote.distance_meters < c.nearby_delivery_limit_m
      ? [{...c, delivery_route: deliveryQuote}] : [];
  });
  const destinations = ranked.filter(c => c.dispatch_mode === 'destination' && c.distance_meters <= DESTINATION_PICKUP_LIMIT);
  for (const {candidate, direct, delivery: deliveryMeters, remaining} of await quoteDestinationLegs(destinations, pickup, delivery, options)) {
      if (!isAlongDestinationRoute(candidate.distance_meters, direct, deliveryMeters, remaining)) continue;
      result.push({ ...candidate, destination_route: {
        destination_lat: candidate.destination_lat, destination_lng: candidate.destination_lng,
        delivery_lat: delivery.lat, delivery_lng: delivery.lng,
        expires_at: candidate.destination_expires_at,
        direct_meters: direct, delivery_meters: deliveryMeters, remaining_meters: remaining,
      } });
  }
  // Stable sort keeps existing road distance/rating ordering within each mode.
  return result.sort((a, b) => Number(b.dispatch_mode === 'destination') - Number(a.dispatch_mode === 'destination'));
}
