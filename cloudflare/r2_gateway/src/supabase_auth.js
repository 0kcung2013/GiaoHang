import { httpError, requiredEnv } from "./http.js";

export async function requireUser(request, env) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    throw httpError(401, "Missing bearer token");
  }
  const response = await fetch(
    `${requiredEnv(env, "SUPABASE_URL")}/auth/v1/user`,
    {
      headers: {
        authorization,
        apikey: requiredEnv(env, "SUPABASE_ANON_KEY"),
      },
    },
  );
  if (!response.ok) throw httpError(401, "Invalid or expired session");
  const user = await response.json();
  if (!user?.id) throw httpError(401, "Invalid user response");
  return user;
}

export async function currentRole(userId, request, env) {
  const rows = await restRows(
    `users?id=eq.${encodeURIComponent(userId)}&select=role&limit=1`,
    request,
    env,
  );
  return rows[0]?.role ?? null;
}

export async function requireRestRow(path, request, env) {
  const rows = await restRows(`${path}&limit=1`, request, env);
  if (rows.length === 0) {
    throw httpError(403, "Resource is not available to this user");
  }
  return rows[0];
}

async function restRows(path, request, env) {
  const authorization = request.headers.get("authorization");
  const response = await fetch(
    `${requiredEnv(env, "SUPABASE_URL")}/rest/v1/${path}`,
    {
      headers: {
        authorization,
        apikey: requiredEnv(env, "SUPABASE_ANON_KEY"),
      },
    },
  );
  if (!response.ok) {
    throw httpError(
      response.status === 401 ? 401 : 403,
      "Database authorization failed",
    );
  }
  const rows = await response.json();
  return Array.isArray(rows) ? rows : [];
}
