import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { quoteFreePickOrders } from '../_shared/road_distance.mjs';
import { createRoadRedis, roadRouteOptions } from '../_shared/road_redis.mjs';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({ error: 'AUTH_REQUIRED' }, 401);
    const url = Deno.env.get('SUPABASE_URL')!;
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authorization } }, auth: { persistSession: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return json({ error: 'AUTH_REQUIRED' }, 401);
    const body = await req.json();
    const keys = ['p_south','p_west','p_north','p_east'];
    if (keys.some(k => typeof body[k] !== 'number' || !Number.isFinite(body[k])) ||
      (body.p_limit !== undefined && (!Number.isInteger(body.p_limit) || body.p_limit < 1 || body.p_limit > 50))) {
      return json({ error: 'INVALID_REQUEST' }, 400);
    }
    const { data: orders, error } = await userClient.rpc('get_free_pick_orders_in_view', {
      p_south: body.p_south, p_west: body.p_west, p_north: body.p_north, p_east: body.p_east,
      p_limit: body.p_limit ?? 50,
    });
    if (error) return json({ error: error.message }, 409);
    if (!orders?.length) return json([]);
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
    const { data: driver, error: driverError } = await admin.from('drivers')
      .select('current_lat,current_lng,location_updated_at').eq('user_id',user.id).single();
    if (driverError || !driver || Date.now() - Date.parse(driver.location_updated_at) > 180000) {
      return json({ error: 'DRIVER_LOCATION_STALE' }, 409);
    }
    const redis = createRoadRedis(name => Deno.env.get(name));
    return json(await quoteFreePickOrders(driver, orders, roadRouteOptions(redis,Deno.env.get('OSRM_BASE_URL'))));
  } catch {
    return json({ error: 'ROAD_ROUTING_UNAVAILABLE' }, 503);
  }
});
