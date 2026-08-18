export type VnpayParams = Record<string, string | number | undefined>;

function formEncode(value: string): string {
  return encodeURIComponent(value).replace(/%20/g, "+");
}

export function canonicalQuery(params: VnpayParams): string {
  return Object.entries(params)
    .filter(([key, value]) =>
      key !== "vnp_SecureHash" &&
      key !== "vnp_SecureHashType" &&
      value !== undefined &&
      String(value).length > 0
    )
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${formEncode(key)}=${formEncode(String(value))}`)
    .join("&");
}

export async function signVnpayParams(
  params: VnpayParams,
  secret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(canonicalQuery(params)),
  );
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function verifyVnpaySignature(
  params: VnpayParams,
  secret: string,
): Promise<boolean> {
  const received = String(params.vnp_SecureHash ?? "").toLowerCase();
  if (!/^[a-f0-9]{128}$/.test(received)) return false;
  const expected = await signVnpayParams(params, secret);
  let difference = expected.length ^ received.length;
  for (let index = 0; index < expected.length; index++) {
    difference |= expected.charCodeAt(index) ^ received.charCodeAt(index);
  }
  return difference === 0;
}

export function buildVnpayPaymentUrl(
  baseUrl: string,
  params: VnpayParams,
  signature: string,
): string {
  const query = canonicalQuery({
    ...params,
    vnp_SecureHash: undefined,
  });
  return `${baseUrl}?${query}&vnp_SecureHash=${signature}`;
}

export function formatVnpayDate(date: Date): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "";
  return `${value("year")}${value("month")}${value("day")}` +
    `${value("hour")}${value("minute")}${value("second")}`;
}
