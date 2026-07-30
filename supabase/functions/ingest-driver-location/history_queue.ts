export const GPS_HISTORY_QUEUE_KEY = "gps:history:queue";

const HISTORY_DEDUPE_PREFIX = "gps:history:dedupe:";
const HISTORY_DEDUPE_TTL_SEC = 5;
const COORDINATE_PRECISION = 5;

export type RedisCommand = (command: unknown[]) => Promise<unknown>;

export type GpsHistoryPayload = {
  driver_id: string;
  user_id: string;
  lat: number;
  lng: number;
  heading: number | null;
  speed: number | null;
  created_at: string;
};

function resultOf(response: unknown): unknown {
  if (
    typeof response === "object" &&
    response !== null &&
    "result" in response
  ) {
    return (response as { result: unknown }).result;
  }
  return response;
}

function dedupeKey(point: GpsHistoryPayload): string {
  const lat = point.lat.toFixed(COORDINATE_PRECISION);
  const lng = point.lng.toFixed(COORDINATE_PRECISION);
  return `${HISTORY_DEDUPE_PREFIX}${point.driver_id}:${lat}:${lng}`;
}

/// Claims a short-lived key before LPUSH so concurrent callers cannot add the
/// same driver coordinate twice. GEO/latest updates remain unaffected.
export async function enqueueHistoryOnce(
  redis: RedisCommand,
  point: GpsHistoryPayload,
): Promise<boolean> {
  const lockKey = dedupeKey(point);
  const claimed = await redis([
    "SET",
    lockKey,
    "1",
    "NX",
    "EX",
    HISTORY_DEDUPE_TTL_SEC,
  ]);

  if (resultOf(claimed) !== "OK") return false;

  try {
    await redis([
      "LPUSH",
      GPS_HISTORY_QUEUE_KEY,
      JSON.stringify(point),
    ]);
    return true;
  } catch (error) {
    // Allow a retry when the claim succeeded but the queue write failed.
    try {
      await redis(["DEL", lockKey]);
    } catch {
      // Preserve the original LPUSH error.
    }
    throw error;
  }
}
