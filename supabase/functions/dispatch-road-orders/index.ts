import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { rankDriversByRoadDistance } from '../_shared/road_distance.mjs';
import { createRoadRedis, roadRouteOptions, withRoadLease } from '../_shared/road_redis.mjs';

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json' },
});

Deno.serve(async req => {
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  const secret = req.headers.get('x-road-dispatch-secret');
  if (!secret) return json({ error: 'AUTH_REQUIRED' }, 401);
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } });
  // Authentication is checked against Vault by a service-role-only RPC.
  const { data: work, error: authError } = await admin.rpc('road_dispatch_work', { p_secret: secret });
  if (authError) return json({ error: 'AUTH_REQUIRED' }, 401);
  try {
    const redis = createRoadRedis(name => Deno.env.get(name));
    const result = await withRoadLease(redis, async assertOwner => {
      const started = Date.now();
      let offered = 0, waiting = 0;
      for (const order of work ?? []) {
        if (Date.now() - started > 18000) break;
        const { data: candidates, error } = await admin.rpc('road_dispatch_candidates', { p_order_id: order.id });
        if (error) throw new Error('DISPATCH_LOOKUP_FAILED');
        if (!candidates?.length) { waiting++; continue; }
        const ranked = await rankDriversByRoadDistance(candidates,
          { lat: order.pickup_lat, lng: order.pickup_lng },
          roadRouteOptions(redis, Deno.env.get('OSRM_BASE_URL')));
        await assertOwner();
        const { data: driverId, error: commitError } = await admin.rpc('commit_road_driver_offer',
          { p_order_id: order.id, p_candidates: ranked });
        if (commitError) throw new Error('DISPATCH_COMMIT_FAILED');
        if (driverId) offered++; else waiting++;
      }
      return { ok: true, offered, waiting };
    });
    console.log(JSON.stringify({ event: 'road_dispatch', ...result }));
    return json(result);
  } catch (error) {
    // Cron retries pending orders. Never select using a direct-distance fallback.
    console.error(JSON.stringify({ event: 'road_dispatch_unavailable',
      reason: error instanceof Error ? error.message : 'DISPATCH_UNAVAILABLE' }));
    return json({ error: 'ROAD_DISPATCH_UNAVAILABLE' }, 503);
  }
});
