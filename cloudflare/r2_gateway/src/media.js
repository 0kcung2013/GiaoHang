import {
  httpError,
  json,
  objectUri,
  parseObjectUri,
  readJson,
  requiredSecret,
  safeSegment,
  safeStringEqual,
} from "./http.js";
import { currentRole, requireRestRow, requireUser } from "./supabase_auth.js";
import { signTicket, ticketUrl, unixSeconds, verifyTicket } from "./tickets.js";

const mediaBucketAlias = "media";
const maximumTicketSeconds = 3600;
const purposePolicy = {
  order_cargo: { maxBytes: 8 * 1024 * 1024, prefix: "order-cargo" },
  delivery_proof: { maxBytes: 5 * 1024 * 1024, prefix: "delivery-proofs" },
  risk_evidence: { maxBytes: 5 * 1024 * 1024, prefix: "risk-evidence" },
  driver_kyc: { maxBytes: 8 * 1024 * 1024, prefix: "driver-kyc" },
  driver_profile_change: {
    maxBytes: 8 * 1024 * 1024,
    prefix: "driver-profile-changes",
  },
  avatar: { maxBytes: 5 * 1024 * 1024, prefix: "avatars" },
};

export async function createUploadTicket(request, env) {
  const user = await requireUser(request, env);
  const body = await readJson(request);
  const policy = purposePolicy[body.purpose];
  if (!policy) throw httpError(400, "Unsupported media purpose");
  if (
    !Number.isInteger(body.size) ||
    body.size <= 0 ||
    body.size > policy.maxBytes
  ) {
    throw httpError(413, "File is empty or exceeds the permitted size");
  }
  const extension = validatedExtension(body.extension, body.contentType);
  await authorizeUpload(user.id, body, request, env);

  const key = objectKeyFor(user.id, body, policy.prefix, extension);
  const ticket = await signTicket(
    {
      action: "upload",
      bucket: mediaBucketAlias,
      key,
      contentType: body.contentType,
      maxBytes: policy.maxBytes,
      subject: user.id,
      exp: unixSeconds() + 10 * 60,
    },
    env.SIGNING_SECRET,
  );
  return json({
    objectUri: objectUri(mediaBucketAlias, key),
    uploadUrl: ticketUrl(request.url, "/v1/ticket/upload", ticket),
    expiresIn: 600,
  });
}

export async function uploadWithTicket(request, env, url) {
  const ticket = await verifyTicket(url, env.SIGNING_SECRET, "upload");
  const contentType = request.headers
    .get("content-type")
    ?.split(";")[0]
    .trim();
  if (contentType !== ticket.contentType) {
    throw httpError(400, "Content-Type does not match upload ticket");
  }
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > ticket.maxBytes) {
    throw httpError(413, "File is empty or too large");
  }
  await env.MEDIA_BUCKET.put(ticket.key, bytes, {
    httpMetadata: { contentType },
    customMetadata: { owner: ticket.subject },
  });
  return json({ objectUri: objectUri(mediaBucketAlias, ticket.key) }, 201);
}

export async function createDownloadTicket(request, env) {
  const user = await requireUser(request, env);
  const body = await readJson(request);
  const parsed = parseObjectUri(body.objectUri);
  if (parsed.bucket !== mediaBucketAlias) {
    throw httpError(400, "Unsupported object bucket");
  }
  await authorizeRead(user.id, parsed.key, body.objectUri, request, env);

  const requestedSeconds = Number(body.expiresIn ?? 600);
  const expiresIn = Math.min(
    maximumTicketSeconds,
    Math.max(
      60,
      Number.isFinite(requestedSeconds) ? requestedSeconds : 600,
    ),
  );
  const ticket = await signTicket(
    {
      action: "download",
      bucket: mediaBucketAlias,
      key: parsed.key,
      subject: user.id,
      exp: unixSeconds() + expiresIn,
    },
    env.SIGNING_SECRET,
  );
  return json({
    downloadUrl: ticketUrl(request.url, "/v1/ticket/download", ticket),
    expiresIn,
  });
}

export async function downloadWithTicket(env, url) {
  const ticket = await verifyTicket(url, env.SIGNING_SECRET, "download");
  const object = await env.MEDIA_BUCKET.get(ticket.key);
  if (!object) throw httpError(404, "Object not found");

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("cache-control", "private, max-age=300");
  headers.set("x-content-type-options", "nosniff");
  return new Response(object.body, { headers });
}

export async function deleteOwnedObject(request, env) {
  const user = await requireUser(request, env);
  const body = await readJson(request);
  const parsed = parseObjectUri(body.objectUri);
  if (parsed.bucket !== mediaBucketAlias) {
    throw httpError(400, "Unsupported object bucket");
  }
  const object = await env.MEDIA_BUCKET.head(parsed.key);
  if (!object) return json({ deleted: true });
  if (object.customMetadata?.owner !== user.id) {
    throw httpError(403, "Only the owner can delete this object");
  }
  await env.MEDIA_BUCKET.delete(parsed.key);
  return json({ deleted: true });
}

export async function promoteAvatar(request, env) {
  requireInternalRequest(request, env);
  const body = await readJson(request);
  const source = parseObjectUri(body.sourceObjectUri);
  const sourceParts = source.key.split("/");
  const userId = safeSegment(sourceParts[1]);
  const requiredPrefix = `users/${userId}/driver-profile-changes/`;
  if (
    source.bucket !== mediaBucketAlias ||
    sourceParts[0] !== "users" ||
    !source.key.startsWith(requiredPrefix) ||
    !source.key.includes("/avatar/")
  ) {
    throw httpError(400, "Invalid avatar draft object");
  }
  const object = await env.MEDIA_BUCKET.get(source.key);
  if (!object) throw httpError(404, "Avatar draft not found");
  const extension = source.key.split(".").at(-1)?.toLowerCase();
  if (!["jpg", "png", "webp"].includes(extension)) {
    throw httpError(400, "Invalid avatar extension");
  }
  const destination =
    `users/${userId}/avatars/${Date.now()}_${crypto.randomUUID()}.` +
    extension;
  await env.MEDIA_BUCKET.put(destination, object.body, {
    httpMetadata: object.httpMetadata,
    customMetadata: { owner: userId, promotedFrom: source.key },
  });
  return json({
    objectUri: objectUri(mediaBucketAlias, destination),
    sourceObjectUri: body.sourceObjectUri,
  });
}

export async function deleteInternalObject(request, env) {
  requireInternalRequest(request, env);
  const body = await readJson(request);
  const object = parseObjectUri(body.objectUri);
  if (object.bucket !== mediaBucketAlias) {
    throw httpError(400, "Unsupported object bucket");
  }
  await env.MEDIA_BUCKET.delete(object.key);
  return json({ deleted: true });
}

async function authorizeUpload(userId, body, request, env) {
  if (body.purpose === "delivery_proof") {
    if (
      !body.contextId ||
      !["pickup", "delivery", "return"].includes(body.stage)
    ) {
      throw httpError(400, "Delivery proof requires order and stage");
    }
    await requireRestRow(
      `orders?id=eq.${encodeURIComponent(body.contextId)}` +
        `&driver_id=eq.${encodeURIComponent(userId)}&select=id`,
      request,
      env,
    );
  }
  if (body.purpose === "risk_evidence") {
    if (!body.contextId || !body.groupId) {
      throw httpError(400, "Risk evidence requires order and report identifiers");
    }
    await requireRestRow(
      `orders?id=eq.${encodeURIComponent(body.contextId)}&select=id`,
      request,
      env,
    );
  }
}

async function authorizeRead(userId, key, objectReference, request, env) {
  if (key.startsWith(`users/${userId}/`)) return;
  if (key.includes("/avatars/")) return;

  const role = await currentRole(userId, request, env);
  if (role === "admin" || role === "support") return;
  if (key.includes("/delivery-proofs/")) {
    await requireRestRow(
      `order_delivery_proofs?storage_path=eq.${encodeURIComponent(objectReference)}&select=id`,
      request,
      env,
    );
    return;
  }
  if (key.includes("/risk-evidence/")) {
    await requireRestRow(
      `risk_report_evidence?evidence_type=eq.photo&storage_path=eq.${encodeURIComponent(objectReference)}&select=id`,
      request,
      env,
    );
    return;
  }
  if (key.includes("/order-cargo/")) {
    await requireRestRow(
      `orders?item_image_url=eq.${encodeURIComponent(objectReference)}&select=id`,
      request,
      env,
    );
    return;
  }
  throw httpError(403, "Object is not available to this user");
}

function objectKeyFor(userId, body, prefix, extension) {
  const randomName = `${Date.now()}_${crypto.randomUUID()}.${extension}`;
  if (body.purpose === "delivery_proof") {
    return (
      `orders/${safeSegment(body.contextId)}/${prefix}/` +
      `${safeSegment(body.stage)}/proof`
    );
  }
  if (body.purpose === "risk_evidence") {
    return (
      `orders/${safeSegment(body.contextId)}/${prefix}/` +
      `${safeSegment(body.groupId)}/${randomName}`
    );
  }
  const context = body.contextId ? `/${safeSegment(body.contextId)}` : "";
  const stage = body.stage ? `/${safeSegment(body.stage)}` : "";
  return `users/${userId}/${prefix}${context}${stage}/${randomName}`;
}

function validatedExtension(extension, contentType) {
  const allowed = {
    "image/jpeg": ["jpg", "jpeg"],
    "image/png": ["png"],
    "image/webp": ["webp"],
  };
  const normalized = String(extension ?? "")
    .toLowerCase()
    .replace(/^\./, "");
  if (!allowed[contentType]?.includes(normalized)) {
    throw httpError(400, "Unsupported image type or extension");
  }
  return normalized === "jpeg" ? "jpg" : normalized;
}

function requireInternalRequest(request, env) {
  const provided = request.headers.get("x-r2-internal-secret");
  const expected = requiredSecret(env.R2_INTERNAL_SECRET, "R2_INTERNAL_SECRET");
  if (!provided || !safeStringEqual(provided, expected)) {
    throw httpError(401, "Invalid internal secret");
  }
}
