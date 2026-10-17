import assert from "node:assert/strict";
import {
  CLEANUP_LOCATION_BATCH_SCRIPT,
  CLEANUP_LOCATION_SCRIPT,
  NEW_OFFLINE_SCRIPT,
  SCHEDULE_OFFLINE_SCRIPT,
  WRITE_LOCATION_SCRIPT,
} from "../driver_location_retention.mjs";

// Service fake for orchestration tests. Lua is also exercised separately with
// Redis-compatible EVAL during verification; this fake permits race injection.
export function driverRedisFixture() {
  const values = new Map();
  const sorted = new Map();
  const calls = [];
  const zset = (key) => {
    if (!sorted.has(key)) sorted.set(key, new Map());
    return sorted.get(key);
  };
  const redis = async (command) => {
    calls.push(command);
    const [name, ...args] = command;
    if (name === "GET") return values.get(args[0]) ?? null;
    if (name === "MGET") return args.map((key) => values.get(key) ?? null);
    if (name === "SET") {
      values.set(args[0], args[1]);
      return "OK";
    }
    if (name === "ZSCAN") return ["0", [...zset(args[0])].flat()];
    if (name === "ZRANGE") {
      return [...zset(args[0])]
        .filter(([, due]) => due <= Number(args[2]))
        .sort((a, b) => a[1] - b[1]).slice(0, args[6]).map(([id]) => id);
    }
    assert.equal(name, "EVAL");
    const [script, count] = args;
    const keys = args.slice(2, 2 + count);
    const argv = args.slice(2 + count);
    if (script === CLEANUP_LOCATION_BATCH_SCRIPT) {
      const results = [];
      for (let i = 0; i < count / 4; i++) {
        results.push(
          await redis([
            "EVAL",
            CLEANUP_LOCATION_SCRIPT,
            4,
            ...keys.slice(i * 4, i * 4 + 4),
            ...argv.slice(i * 5, i * 5 + 5),
          ]),
        );
      }
      return results;
    }
    if (script === SCHEDULE_OFFLINE_SCRIPT) {
      return keys.filter((_, index) => index % 2 === 1).map((key, index) => {
        const latestKey = keys[index * 2 + 2];
        let location;
        try {
          location = JSON.parse(values.get(latestKey));
        } catch { /* no valid location */ }
        const wasOnline = location?.is_available === true;
        if (wasOnline) {
          values.set(
            latestKey,
            JSON.stringify({ ...location, is_available: false }),
          );
        }
        if (!values.has(key) || wasOnline) {
          values.set(key, argv[2 * index + 2]);
          zset(keys[0]).set(argv[2 * index + 1], Number(argv[0]));
        }
        return values.get(key);
      });
    }
    const [id, marker] = argv;
    if (script === NEW_OFFLINE_SCRIPT) {
      try {
        const location = JSON.parse(values.get(keys[2]));
        if (location.is_available === true) {
          values.set(
            keys[2],
            JSON.stringify({ ...location, is_available: false }),
          );
        }
      } catch { /* no valid location */ }
      values.set(keys[0], marker);
      zset(keys[1]).set(id, Number(argv[2]));
      return marker;
    }
    if (script === WRITE_LOCATION_SCRIPT) {
      if ((values.get(keys[0]) ?? "") !== marker) return 0;
      if (argv[2] === "1") {
        values.delete(keys[0]);
        zset(keys[1]).delete(id);
      } else if (marker && JSON.parse(marker).due_at <= argv[3]) {
        if (argv[4] !== "1") return 0;
        if (!zset(keys[1]).has(id)) zset(keys[1]).set(id, Number(argv[3]));
      }
      zset(keys[2]).set(id, Number(argv[5]));
      values.set(keys[3], argv[7]);
      return 1;
    }
    assert.equal(script, CLEANUP_LOCATION_SCRIPT);
    if (
      values.get(keys[0]) !== marker || !zset(keys[1]).has(id) ||
      zset(keys[1]).get(id) > argv[2]
    ) return 0;
    if (argv[3] === "online") {
      values.delete(keys[0]);
      zset(keys[1]).delete(id);
    } else if (argv[3] === "active") {
      zset(keys[1]).set(id, Number(argv[2]) + 60000);
    } else {
      if ((values.get(keys[3]) ?? "") !== argv[4]) return 0;
      values.delete(keys[3]);
      zset(keys[2]).delete(id);
      zset(keys[1]).delete(id);
    }
    return 1;
  };
  return { redis, values, sorted, calls, zset };
}
