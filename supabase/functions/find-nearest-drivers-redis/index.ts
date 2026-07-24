// Edge Function: tìm tài xế gần pickup bằng Redis GEO.
// Fallback phía client vẫn dùng PostGIS/Haversine nếu function lỗi.
// Secrets: UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const GEO_KEY = "drivers:geo";
const LOC_PREFIX = "driver:loc:";

type Body = {
  pickup_lat?: number;
  pickup_lng?: number;
  radius_meters?: number;
  max_results?: number;
};

async function redis(command: unknown[]) {
  const url = Deno.env.get("UPSTASH_REDIS_REST_URL");
  const token = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");
  if (!url || !token) throw new Error("Redis secrets missing");
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(command),
  });
  if (!res.ok) throw new Error(`Redis ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.result;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Unauthorized" }, 401);

    const body = (await req.json()) as Body;
    const lat = Number(body.pickup_lat);
    const lng = Number(body.pickup_lng);
    const radius = Number(body.radius_meters ?? 15000);
    const maxResults = Math.min(Number(body.max_results ?? 20), 50);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return json({ error: "Invalid pickup" }, 400);
    }

    // GEORADIUS ... WITHDIST WITHCOORD ASC COUNT n
    const geo = await redis([
      "GEORADIUS",
      GEO_KEY,
      lng,
      lat,
      radius,
      "m",
      "WITHDIST",
      "WITHCOORD",
      "ASC",
      "COUNT",
      maxResults,
    ]) as unknown[] | null;

    if (!geo || !Array.isArray(geo) || geo.length === 0) {
      return json({ drivers: [], source: "redis" });
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const drivers: Record<string, unknown>[] = [];

    for (const item of geo) {
      // item: [member, dist, [lng, lat]]
      if (!Array.isArray(item) || item.length < 1) continue;
      const userId = String(item[0]);
      const dist = item[1] != null ? Number(item[1]) : null;
      let dLat: number | null = null;
      let dLng: number | null = null;
      if (Array.isArray(item[2]) && item[2].length >= 2) {
        dLng = Number(item[2][0]);
        dLat = Number(item[2][1]);
      }

      // Meta từ Redis JSON (available flag)
      let meta: Record<string, unknown> | null = null;
      try {
        const raw = await redis(["GET", `${LOC_PREFIX}${userId}`]);
        if (typeof raw === "string") meta = JSON.parse(raw);
      } catch {
        /* ignore */
      }

      if (meta && meta.is_available === false) continue;

      // Bỏ tài xế đang bận đơn (source of truth: Postgres)
      const { data: busy } = await admin
        .from("orders")
        .select("id")
        .eq("driver_id", userId)
        .in("status", ["assigned", "picking_up", "delivering"])
        .limit(1)
        .maybeSingle();
      if (busy) continue;

      // Phải approved
      const { data: row } = await admin
        .from("drivers")
        .select("user_id, approval_status, is_available")
        .eq("user_id", userId)
        .maybeSingle();
      if (!row || row.approval_status !== "approved") continue;
      if (row.is_available !== true) continue;

      drivers.push({
        user_id: userId,
        lat: dLat ?? meta?.lat,
        lng: dLng ?? meta?.lng,
        current_lat: dLat ?? meta?.lat,
        current_lng: dLng ?? meta?.lng,
        distance_meters: dist,
      });
    }

    return json({ drivers, source: "redis" });
  } catch (e) {
    return json(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
