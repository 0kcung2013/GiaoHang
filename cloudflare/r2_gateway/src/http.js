export const encoder = new TextEncoder();

export function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

export async function readJson(request) {
  try {
    return await request.json();
  } catch (_) {
    throw httpError(400, "Invalid JSON body");
  }
}

export function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}

export function requiredEnv(env, name) {
  const value = env[name];
  if (!value) throw httpError(500, `Missing ${name}`);
  return String(value).replace(/\/$/, "");
}

export function requiredSecret(value, name) {
  if (!value || String(value).length < 24) {
    throw httpError(500, `Missing or weak ${name}`);
  }
  return String(value);
}

export function safeSegment(value) {
  const segment = String(value ?? "");
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(segment)) {
    throw httpError(400, "Invalid object segment");
  }
  return segment;
}

export function safeStringEqual(left, right) {
  const a = encoder.encode(String(left ?? ""));
  const b = encoder.encode(String(right ?? ""));
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}

export function parseObjectUri(value) {
  let uri;
  try {
    uri = new URL(String(value));
  } catch (_) {
    throw httpError(400, "Invalid object URI");
  }
  if (uri.protocol !== "r2:" || !uri.hostname || uri.pathname === "/") {
    throw httpError(400, "Invalid object URI");
  }
  return {
    bucket: uri.hostname,
    key: uri.pathname.slice(1).split("/").map(decodeURIComponent).join("/"),
  };
}

export function objectUri(bucket, key) {
  const encodedKey = key.split("/").map(encodeURIComponent).join("/");
  return `r2://${bucket}/${encodedKey}`;
}

export async function gzip(bytes) {
  const stream = new Blob([bytes])
    .stream()
    .pipeThrough(new CompressionStream("gzip"));
  return new Response(stream).arrayBuffer();
}

export function corsHeaders(origin, configuredOrigins = "") {
  const allowed = configuredOrigins
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  const headers = {
    "access-control-allow-headers":
      "authorization,content-type,x-gps-ingest-secret,x-r2-internal-secret",
    "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
    "access-control-max-age": "86400",
    vary: "Origin",
  };
  if (origin && allowed.some((rule) => originMatchesRule(origin, rule))) {
    headers["access-control-allow-origin"] = origin;
  }
  return headers;
}

function originMatchesRule(origin, rule) {
  if (origin === rule) return true;
  if (!rule.endsWith(":*")) return false;

  try {
    const candidate = new URL(origin);
    const expectedBase = rule.slice(0, -2);
    const candidateBase = `${candidate.protocol}//${candidate.hostname}`;
    return (
      candidateBase === expectedBase &&
      (candidate.port === "" || /^\d+$/.test(candidate.port))
    );
  } catch (_) {
    return false;
  }
}

export function appendHeaders(target, source) {
  for (const [key, value] of Object.entries(source)) target.set(key, value);
}
