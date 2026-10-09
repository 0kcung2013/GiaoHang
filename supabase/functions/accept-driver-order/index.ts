import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { quoteRoute, validPoint } from './deadline.mjs';
import { AUTOMATIC_ROAD_LIMIT, FREE_PICK_ROAD_LIMIT, quotePickupRoute } from '../_shared/road_distance.mjs';
import { createRoadRedis, roadRouteOptions } from '../_shared/road_redis.mjs';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({ error: 'AUTH_REQUIRED' }, 401);
    const url = Deno.env.get('SUPABASE_URL')!;
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return json({ error: 'AUTH_REQUIRED' }, 401);
    const body = await req.json();
    if (typeof body.order_id !== 'string' ||
      !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(body.order_id) ||
      (body.free_pick !== undefined && typeof body.free_pick !== 'boolean') ||
      (body.existing_only !== undefined && typeof body.existing_only !== 'boolean')) {
      return json({ error: 'INVALID_REQUEST' }, 400);
    }
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
      auth: { persistSession: false },
    });
    const [{ data: order, error: orderError }, { data: driver, error: driverError }] = await Promise.all([
      admin.from('orders').select('id,driver_id,offered_driver_id,status,pickup_lat,pickup_lng,delivery_lat,delivery_lng,estimated_delivery_at')
        .eq('id', body.order_id).maybeSingle(),
      admin.from('drivers').select('current_lat,current_lng,location_updated_at,approval_status')
        .eq('user_id', user.id).maybeSingle(),
    ]);
    if (orderError || driverError) return json({ error: 'LOOKUP_FAILED' }, 500);
    if (!driver || driver.approval_status !== 'approved') return json({ error: 'DRIVER_NOT_APPROVED' }, 403);
    if (!order || (order.driver_id !== null && order.driver_id !== user.id) ||
      (order.driver_id === null && !body.free_pick && order.offered_driver_id !== user.id)) {
      return json({ error: 'ORDER_NOT_AVAILABLE' }, 409);
    }
    const points: number[][] = [];
    const age = Date.now() - Date.parse(driver.location_updated_at ?? '');
    const fresh = Number.isFinite(age) && age >= -30000 && age <= 180000;
    const hasOrigin = fresh && validPoint(driver.current_lat, driver.current_lng);
    let pickupQuote = null;
    if (body.free_pick === true && order.driver_id === null) {
      if (!hasOrigin) return json({ error: 'DRIVER_LOCATION_STALE' }, 409);
      try {
        const redis = createRoadRedis(name => Deno.env.get(name));
        pickupQuote = await quotePickupRoute(driver, { lat: order.pickup_lat, lng: order.pickup_lng },
          roadRouteOptions(redis, Deno.env.get('OSRM_BASE_URL')));
      } catch {
        return json({ error: 'ROAD_ROUTING_UNAVAILABLE' }, 503);
      }
      if (!pickupQuote || pickupQuote.distance_meters <= AUTOMATIC_ROAD_LIMIT ||
        pickupQuote.distance_meters > FREE_PICK_ROAD_LIMIT) {
        return json({ error: 'FREE_PICK_OUT_OF_RANGE' }, 409);
      }
    }
    if (hasOrigin) points.push([driver.current_lng, driver.current_lat]);
    if (!validPoint(order.pickup_lat,order.pickup_lng) || !validPoint(order.delivery_lat,order.delivery_lng)) {
      return json({ error: 'INVALID_ORDER_COORDINATES' }, 409);
    }
    if (order.status !== 'delivering' || !hasOrigin) points.push([order.pickup_lng,order.pickup_lat]);
    points.push([order.delivery_lng,order.delivery_lat]);
    const quote = await quoteRoute(points);
    // No fresh driver origin: add 15 minutes and mark the estimate as fallback.
    const seconds = Math.min(86400, quote.seconds + (hasOrigin ? 0 : 900));
    const { data, error } = await admin.rpc('accept_driver_order_with_road_quote', {
      p_order_id: order.id, p_driver_id: user.id,
      p_route_duration_s: seconds, p_free_pick: body.free_pick === true,
      p_quote_source: hasOrigin ? quote.source : 'distance_fallback',
      p_existing_only: body.existing_only === true,
      p_pickup_quote: pickupQuote,
    });
    if (error) return json({ error: error.message }, 409);
    return json(data);
  } catch {
    return json({ error: 'ACCEPT_ORDER_UNAVAILABLE' }, 500);
  }
});
