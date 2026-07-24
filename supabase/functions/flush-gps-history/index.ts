// Edge Function: bulk pop GPS queue (Redis) → insert driver_locations (Postgres).
// Deploy với --no-verify-jwt để cron-job.org không bị 401 ở API gateway
// (một số cron strip header Authorization).
//
// Auth chấp nhận (một trong các cách):
//   1) Header apikey: <SERVICE_ROLE_KEY>
//   2) Header Authorization: Bearer <SERVICE_ROLE_KEY>
//   3) Header x-cron-secret: <CRON_SECRET>  (optional secret riêng)
//
// Secrets: UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN
//          SUPABASE_SERVICE_ROLE_KEY (auto), CRON_SECRET (optional)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const QUEUE_KEY = "gps:history:queue";
const MAX_BATCH = 50;

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
  if (!res.ok) {
    throw new Error(`Redis ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  return data.result;
}

/** Decode JWT payload (không verify chữ ký — đủ cho DATN flush worker). */
function jwtRole(token: string): string | null {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const json = atob(padded);
    const payload = JSON.parse(json) as { role?: string; ref?: string };
    // Đúng project DATN
    if (payload.ref && payload.ref !== "erlpzwfbpjogvaulcxni") return null;
    return payload.role ?? null;
  } catch {
    return null;
  }
}

function isAuthorized(req: Request): boolean {
  const serviceKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
  // Fallback demo khi không set được secrets qua CLI (403).
  const cronSecret = (
    Deno.env.get("CRON_SECRET") ??
    "giaohang_flush_2026"
  ).trim();

  const authHeader = (req.headers.get("Authorization") ?? "").trim();
  const apiKey = (req.headers.get("apikey") ?? "").trim();
  const cronHeader = (req.headers.get("x-cron-secret") ?? "").trim();
  const bearer = authHeader.replace(/^Bearer\s+/i, "").trim();

  // 1) So khớp env service_role (nếu Edge inject được)
  if (serviceKey) {
    if (apiKey === serviceKey) return true;
    if (bearer === serviceKey) return true;
  }

  // 2) JWT có claim role=service_role (khi env key khác / không inject)
  //    → fix lỗi 401 dù PowerShell đã gửi đúng service_role key
  if (bearer && jwtRole(bearer) === "service_role") return true;
  if (apiKey && jwtRole(apiKey) === "service_role") return true;

  // 3) Secret cron
  if (cronSecret && cronHeader === cronSecret) return true;

  try {
    const url = new URL(req.url);
    const q = (url.searchParams.get("secret") ?? "").trim();
    if (cronSecret && q === cronSecret) return true;
    if (serviceKey && q === serviceKey) return true;
  } catch {
    /* ignore */
  }

  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type, x-cron-secret",
      },
    });
  }

  try {
    if (req.method !== "POST" && req.method !== "GET") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (!isAuthorized(req)) {
      return json(
        {
          error: "Unauthorized",
          hint:
            "Gửi apikey=service_role, hoặc Authorization Bearer service_role, hoặc x-cron-secret / ?secret=",
        },
        401,
      );
    }

    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(supabaseUrl, serviceKey);
    const rows: Record<string, unknown>[] = [];

    for (let i = 0; i < MAX_BATCH; i++) {
      const raw = await redis(["RPOP", QUEUE_KEY]);
      if (raw == null) break;
      try {
        const p = typeof raw === "string" ? JSON.parse(raw) : raw;
        if (!p?.driver_id || p.lat == null || p.lng == null) continue;
        rows.push({
          driver_id: p.driver_id,
          lat: Number(p.lat),
          lng: Number(p.lng),
          heading: p.heading ?? null,
          speed: p.speed ?? null,
          is_active: true,
          created_at: p.created_at ?? new Date().toISOString(),
        });
      } catch {
        // skip bad payload
      }
    }

    if (rows.length === 0) {
      return json({ ok: true, inserted: 0, queue_empty: true });
    }

    const { error } = await admin.from("driver_locations").insert(rows);
    if (error) {
      for (const r of rows.reverse()) {
        try {
          await redis([
            "LPUSH",
            QUEUE_KEY,
            JSON.stringify({
              driver_id: r.driver_id,
              lat: r.lat,
              lng: r.lng,
              heading: r.heading,
              speed: r.speed,
              created_at: r.created_at,
            }),
          ]);
        } catch {
          /* ignore */
        }
      }
      return json({ error: error.message, requeued: rows.length }, 500);
    }

    return json({ ok: true, inserted: rows.length });
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
