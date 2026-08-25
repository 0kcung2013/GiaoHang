import { assertEquals, assertStringIncludes } from "jsr:@std/assert";

const migrationUrl = new URL(
  "../migrations/20260825032233_driver_profile_change_requests.sql",
  import.meta.url,
);
const migrationSql = await Deno.readTextFile(migrationUrl);

Deno.test("empty requested changes use PostgreSQL-supported JSONB primitives", () => {
  assertEquals(migrationSql.includes("jsonb_object_length("), false);
  assertStringIncludes(
    migrationSql,
    "requested_changes <> '{}'::jsonb",
  );
});
