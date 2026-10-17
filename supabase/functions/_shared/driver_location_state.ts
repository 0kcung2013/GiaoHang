import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export const ACTIVE_DRIVER_ORDER_STATUSES = [
  "assigned",
  "picking_up",
  "delivering",
  "return_approved",
  "returning",
];

export function createDriverStateReader(admin: SupabaseClient) {
  return async (userIds: string[]) => {
    const [drivers, orders] = await Promise.all([
      admin.from("drivers").select("user_id, is_available").in(
        "user_id",
        userIds,
      ),
      admin.from("orders").select("driver_id").in("driver_id", userIds)
        .in("status", ACTIVE_DRIVER_ORDER_STATUSES),
    ]);
    if (drivers.error || orders.error) {
      throw new Error("Cannot verify driver GPS retention state");
    }
    const active = new Set((orders.data ?? []).map((order) => order.driver_id));
    return new Map((drivers.data ?? []).map((driver) => [driver.user_id, {
      isAvailable: driver.is_available === true,
      hasActiveOrder: active.has(driver.user_id),
    }]));
  };
}
