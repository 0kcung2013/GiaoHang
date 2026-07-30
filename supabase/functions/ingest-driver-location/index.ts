// Edge Function: GPS hot path
// Redis GEO + latest + history queue; Postgres drivers UPDATE (throttled) cho Realtime.
// Secrets: UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  enqueueHistoryOnce,
  type GpsHistoryPayload,
} from "./history_queue.ts";

const GEO_KEY = "drivers:geo";
const PG_TOUCH_PREFIX = "gps:pg_touch:";
const LOC_PREFIX = "driver:loc:";
const PG_TOUCH_TTL_SEC = 8;

type Body = {
  driver_profile_id?: string;
  driver_user_id?: string;
  lat?: number;
  lng?: number;
  heading?: number;
  speed?: number;
  client_ts?: string;
};

async function redis(command: unknown[]) {
  const url = Deno.env.get("UPSTASH_REDIS_REST_URL");
  const token = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");
  if (!url || !token) {
    throw new Error("Redis secrets missing");
  }
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(command),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Redis ${res.status}: ${t}`);
  }
  return await res.json();
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
    if (!authHeader) {
      return json({ error: "Unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = (await req.json()) as Body;
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return json({ error: "Invalid lat/lng" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    let profileId = body.driver_profile_id?.trim() || "";
    let userId = body.driver_user_id?.trim() || user.id;

    // Resolve drivers row
    let q = admin.from("drivers").select("id, user_id, is_available");
    if (profileId) {
      q = q.eq("id", profileId);
    } else {
      q = q.eq("user_id", userId);
    }
    const { data: driver, error: dErr } = await q.maybeSingle();
    if (dErr || !driver) {
      return json({ error: "Driver profile not found" }, 404);
    }
    // Chỉ cho chính tài xế đó cập nhật
    if (driver.user_id !== user.id) {
      return json({ error: "Forbidden" }, 403);
    }
    profileId = driver.id as string;
    userId = driver.user_id as string;

    const now = new Date().toISOString();
    const member = userId; // GEO member = user_id (khớp nearest filter)

    // Hot: GEO + latest JSON
    await redis(["GEOADD", GEO_KEY, lng, lat, member]);
    await redis([
      "SET",
      `${LOC_PREFIX}${userId}`,
      JSON.stringify({
        user_id: userId,
        profile_id: profileId,
        lat,
        lng,
        heading: body.heading ?? null,
        speed: body.speed ?? null,
        is_available: driver.is_available === true,
        updated_at: now,
      }),
    ]);

    // Queue history (cold path), idempotent across tabs/callers.
    const historyPoint: GpsHistoryPayload = {
      driver_id: profileId,
      user_id: userId,
      lat,
      lng,
      heading: body.heading ?? null,
      speed: body.speed ?? null,
      created_at: body.client_ts || now,
    };
    const historyEnqueued = await enqueueHistoryOnce(redis, historyPoint);

    // Throttle UPDATE drivers → Realtime khách vẫn nhận được, ít ghi hơn
    const touchKey = `${PG_TOUCH_PREFIX}${profileId}`;
    const touched = await redis(["SET", touchKey, "1", "NX", "EX", PG_TOUCH_TTL_SEC]);
    let pgUpdated = false;
    // Upstash returns "OK" when set; null when NX fails
    if (touched?.result === "OK" || touched === "OK") {
      const { error: uErr } = await admin
        .from("drivers")
        .update({
          current_lat: lat,
          current_lng: lng,
          location_updated_at: now,
          updated_at: now,
        })
        .eq("id", profileId);
      pgUpdated = !uErr;
    }

    return json({
      ok: true,
      redis: true,
      history_enqueued: historyEnqueued,
      pg_updated: pgUpdated,
      profile_id: profileId,
      user_id: userId,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: msg }, 500);
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
