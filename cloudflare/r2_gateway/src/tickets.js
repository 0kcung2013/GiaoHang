import {
  encoder,
  httpError,
  requiredSecret,
  safeStringEqual,
} from "./http.js";

export async function signTicket(payload, secret) {
  requiredSecret(secret, "SIGNING_SECRET");
  const encoded = base64UrlEncode(encoder.encode(JSON.stringify(payload)));
  const signature = await hmac(encoded, secret);
  return { payload: encoded, signature };
}

export async function verifyTicket(url, secret, expectedAction) {
  const payload = url.searchParams.get("payload");
  const signature = url.searchParams.get("signature");
  if (!payload || !signature) throw httpError(401, "Missing ticket");
  const expected = await hmac(
    payload,
    requiredSecret(secret, "SIGNING_SECRET"),
  );
  if (!safeStringEqual(signature, expected)) {
    throw httpError(401, "Invalid ticket");
  }

  let decoded;
  try {
    decoded = JSON.parse(new TextDecoder().decode(base64UrlDecode(payload)));
  } catch (_) {
    throw httpError(401, "Malformed ticket");
  }
  if (decoded.action !== expectedAction || decoded.exp < unixSeconds()) {
    throw httpError(401, "Expired or invalid ticket");
  }
  return decoded;
}

export function ticketUrl(requestUrl, path, ticket) {
  const url = new URL(path, requestUrl);
  url.searchParams.set("payload", ticket.payload);
  url.searchParams.set("signature", ticket.signature);
  return url.toString();
}

export function unixSeconds() {
  return Math.floor(Date.now() / 1000);
}

async function hmac(value, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(value),
  );
  return base64UrlEncode(new Uint8Array(signature));
}

function base64UrlEncode(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

function base64UrlDecode(value) {
  const base64 = value
    .replaceAll("-", "+")
    .replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}
