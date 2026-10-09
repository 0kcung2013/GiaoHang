import { requiredEnv, requiredSecret } from "./http.js";

export async function runGpsHistoryFlush(env) {
  const url = `${requiredEnv(env, "SUPABASE_URL")}/functions/v1/flush-gps-history`;
  const secret = requiredSecret(env.GPS_INGEST_SECRET, "GPS_INGEST_SECRET");
  const response = await fetch(url, {
    method: "POST", signal: AbortSignal.timeout(60000),
    headers: { "content-type": "application/json", "x-gps-ingest-secret": secret },
    body: "{}",
  });
  if (!response.ok) throw new Error(`GPS archive failed (HTTP ${response.status})`);
  const result = await response.json();
  if (result.ok !== true) throw new Error("GPS archive failed: invalid acknowledgement");
  console.info("[GpsArchiveCron]", JSON.stringify(result));
  return result;
}
