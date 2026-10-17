// Private GPS archiver. The handler checks exact server-side secrets itself.
import { createGpsArchiveHandler } from "./archive.mjs";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { cleanupOfflineDriverLocations } from "../_shared/driver_location_cleanup.mjs";
import { createDriverStateReader } from "../_shared/driver_location_state.ts";

Deno.serve(createGpsArchiveHandler({
  getEnv: (name: string) => Deno.env.get(name),
  maintainLocations: ({ redis, now }) => {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    return cleanupOfflineDriverLocations({
      redis,
      now,
      loadStates: createDriverStateReader(admin),
    });
  },
}));
