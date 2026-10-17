import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { createRoadRedis } from "../_shared/road_redis.mjs";
import { changeDriverLocationPresence } from "./presence.mjs";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  const authorization = request.headers.get("Authorization");
  if (!authorization) return json({ error: "Unauthorized" }, 401);
  try {
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: { user }, error } = await userClient.auth.getUser();
    if (error || !user) return json({ error: "Unauthorized" }, 401);
    const { event } = await request.json();
    if (event !== "online" && event !== "offline") {
      return json({ error: "Invalid presence event" }, 400);
    }
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    // Identity always comes from the verified JWT, never a body-supplied ID.
    const result = await changeDriverLocationPresence({
      event,
      goOffline: async () => {
        const { error } = await userClient.rpc("set_driver_availability", {
          p_is_available: false,
        });
        if (error) throw error;
      },
      loadDriver: async () => {
        const { data, error } = await admin.from("drivers")
          .select(
            "id, user_id, is_available, current_lat, current_lng, location_updated_at",
          )
          .eq("user_id", user.id).maybeSingle();
        if (error) throw error;
        return data;
      },
      // Resolve secrets lazily so a Redis outage does not undo a successful OFF.
      redis: (command: unknown[]) =>
        createRoadRedis((name: string) => Deno.env.get(name))(command),
    });
    return json(result);
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 400);
  }
});
