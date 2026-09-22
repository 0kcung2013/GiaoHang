import {
  encoder,
  gzip,
  httpError,
  json,
  objectUri,
  readJson,
  safeSegment,
  safeStringEqual,
} from "./http.js";

const gpsBucketAlias = "gps";

export async function storeGpsChunk(request, env) {
  const secret = request.headers.get("x-gps-ingest-secret");
  if (!secret || !safeStringEqual(secret, env.GPS_INGEST_SECRET)) {
    throw httpError(401, "Invalid GPS ingest secret");
  }
  const body = await readJson(request);
  if (
    !Array.isArray(body.points) ||
    body.points.length === 0 ||
    body.points.length > 5000
  ) {
    throw httpError(400, "GPS chunk must contain between 1 and 5000 points");
  }
  const points = body.points.map(validateGpsPoint);
  const receivedAt = new Date();
  const grouped = groupByOrder(points);
  const objects = [];
  for (const [orderId, orderPoints] of grouped) {
    const object = await storeOrderChunk(
      env.GPS_BUCKET,
      orderId,
      orderPoints,
      receivedAt,
    );
    objects.push(object);
  }
  return json({ objects, pointCount: points.length }, 201);
}

function groupByOrder(points) {
  const grouped = new Map();
  for (const point of points) {
    const orderPoints = grouped.get(point.order_id) ?? [];
    orderPoints.push(point);
    grouped.set(point.order_id, orderPoints);
  }
  return grouped;
}

async function storeOrderChunk(bucket, orderId, points, receivedAt) {
  const day = receivedAt.toISOString().slice(0, 10).replaceAll("-", "/");
  const timestamp = receivedAt.toISOString().replaceAll(":", "-");
  const key =
    `orders/${safeSegment(orderId)}/gps/${day}/` +
    `${timestamp}_${crypto.randomUUID()}.jsonl.gz`;
  const jsonl = points.map((point) => JSON.stringify(point)).join("\n") + "\n";
  const compressed = await gzip(encoder.encode(jsonl));
  await bucket.put(key, compressed, {
    httpMetadata: {
      contentType: "application/x-ndjson",
      contentEncoding: "gzip",
    },
    customMetadata: {
      orderId,
      pointCount: String(points.length),
      receivedAt: receivedAt.toISOString(),
    },
  });
  return {
    objectUri: objectUri(gpsBucketAlias, key),
    orderId,
    pointCount: points.length,
  };
}

function validateGpsPoint(point) {
  const lat = Number(point?.lat);
  const lng = Number(point?.lng);
  if (
    !point?.driver_id ||
    !point?.order_id ||
    !Number.isFinite(lat) ||
    !Number.isFinite(lng)
  ) {
    throw httpError(400, "Invalid GPS point");
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw httpError(400, "GPS coordinates are outside valid bounds");
  }
  return {
    driver_id: String(point.driver_id),
    user_id: point.user_id == null ? null : String(point.user_id),
    order_id: safeSegment(point.order_id),
    lat,
    lng,
    heading: finiteOrNull(point.heading),
    speed: finiteOrNull(point.speed),
    created_at: new Date(point.created_at ?? Date.now()).toISOString(),
  };
}

function finiteOrNull(value) {
  if (value == null) return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
