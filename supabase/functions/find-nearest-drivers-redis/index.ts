// Road-distance lookup. Assignment remains atomic in PostgreSQL.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { rankDriversByRoadDistance } from '../_shared/road_distance.mjs';
import { createRoadRedis, roadRouteOptions } from '../_shared/road_redis.mjs';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS','Content-Type': 'application/json',
};
const json = (body: unknown,status = 200) => new Response(JSON.stringify(body),{status,headers});
Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null,{headers});
  if (req.method !== 'POST') return json({error:'METHOD_NOT_ALLOWED'},405);
  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({error:'AUTH_REQUIRED'},401);
    const url = Deno.env.get('SUPABASE_URL')!;
    const userClient = createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{
      global:{headers:{Authorization:authorization}},auth:{persistSession:false},
    });
    const {data:{user},error:authError} = await userClient.auth.getUser();
    if (authError || !user) return json({error:'AUTH_REQUIRED'},401);
    const body = await req.json();
    const lat = body.pickup_lat, lng = body.pickup_lng;
    const radius = body.radius_meters ?? 2000;
    if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) ||
      !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180 ||
      typeof radius !== 'number' || !Number.isFinite(radius) || radius <= 0) {
      return json({error:'INVALID_PICKUP'},400);
    }
    const admin = createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    // PostgreSQL is authoritative for online status and latest GPS. Route ALL eligible points.
    const {data:candidates,error} = await admin.rpc('road_lookup_candidates',{
      pickup_lat:lat,pickup_lng:lng,radius_meters:Math.min(radius,2000),max_results:50,
    });
    if (error) return json({error:'DRIVER_LOOKUP_FAILED'},503);
    if (!candidates?.length) return json({drivers:[],source:'osrm'});
    const redis = createRoadRedis(name => Deno.env.get(name));
    const ranked = await rankDriversByRoadDistance(candidates,{lat,lng},
      roadRouteOptions(redis,Deno.env.get('OSRM_BASE_URL')));
    const limit = Number.isInteger(body.max_results) ? Math.min(Math.max(body.max_results,1),50) : 20;
    return json({drivers:ranked.filter(d => d.distance_meters <= Math.min(radius,2000)).slice(0,limit),source:'osrm'});
  } catch {
    return json({error:'ROAD_ROUTING_UNAVAILABLE'},503);
  }
});
