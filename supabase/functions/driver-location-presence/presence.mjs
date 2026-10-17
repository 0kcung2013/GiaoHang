import {
  scheduleOfflineLocation,
  writeLatestDriverLocation,
} from "../_shared/driver_location_retention.mjs";

export async function changeDriverLocationPresence(
  { event, goOffline, loadDriver, redis, now = Date.now, log = console },
) {
  if (event !== "offline" && event !== "online") {
    throw new Error("Invalid presence event");
  }
  const before = event === "offline" ? await loadDriver() : null;
  if (event === "offline" && !before) {
    throw new Error("Driver profile not found");
  }
  if (event === "offline") await goOffline();
  const timestamp = now();
  const driver = await loadDriver();
  if (!driver) throw new Error("Driver profile not found");
  if (event === "online" && driver.is_available !== true) {
    throw new Error("Driver must verify the Online PIN first");
  }
  try {
    if (driver.is_available !== true) {
      await scheduleOfflineLocation(redis, driver.user_id, timestamp, {
        reset: before?.is_available === true,
      });
    } else if (driver.current_lat != null && driver.current_lng != null) {
      await writeLatestDriverLocation({
        redis,
        userId: driver.user_id,
        isAvailable: true,
        now: timestamp,
        location: {
          user_id: driver.user_id,
          profile_id: driver.id,
          lat: driver.current_lat,
          lng: driver.current_lng,
          heading: null,
          speed: null,
          is_available: true,
          updated_at: driver.location_updated_at,
        },
      });
    } else {
      throw new Error("Online driver is missing location");
    }
    return {
      ok: true,
      is_available: driver.is_available === true,
      cache_synced: true,
    };
  } catch (error) {
    // PostgreSQL already committed the business transition. Cron repairs Redis
    // after an outage without falsely reporting that OFF/PIN verification failed.
    log.error("[DriverLocationPresence] Redis synchronization failed", error);
    return {
      ok: true,
      is_available: driver.is_available === true,
      cache_synced: false,
    };
  }
}
