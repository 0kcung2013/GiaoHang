import type { RedisCommand } from "./history_queue.ts";

export const DRIVERS_SYNC_INTERVAL_SECONDS = 10;
const PG_TOUCH_PREFIX = "gps:pg_touch:";
const RELEASE_FAILED_SYNC =
  "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end";

/** One shared PG write cadence across navigation, foreground and other callers. */
export async function syncLatestDriverLocation(
  redis: RedisCommand,
  profileId: string,
  update: () => Promise<boolean>,
  { force = false, token = crypto.randomUUID() }: {
    force?: boolean;
    token?: string;
  } = {},
): Promise<boolean> {
  const key = `${PG_TOUCH_PREFIX}${profileId}`;
  const response = await redis([
    "SET",
    key,
    token,
    ...(force ? [] : ["NX"]),
    "EX",
    DRIVERS_SYNC_INTERVAL_SECONDS,
  ]);
  const result = typeof response === "object" && response !== null &&
      "result" in response
    ? response.result
    : response;
  if (result !== "OK") return false;

  let updated = false;
  try {
    updated = await update();
    return updated;
  } finally {
    if (!updated) {
      // A failed PG write must allow retry, without deleting a successor's key.
      try {
        await redis(["EVAL", RELEASE_FAILED_SYNC, 1, key, token]);
      } catch {
        // The 10s TTL releases the failed claim during a Redis outage.
      }
    }
  }
}
