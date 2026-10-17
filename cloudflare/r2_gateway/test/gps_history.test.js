import test from 'node:test';
import assert from 'node:assert/strict';
import { gzipSync } from 'node:zlib';
import worker from '../src/index.js';

function setup(t, {role = 'support', allowed = true, valid = true} = {}) {
  t.mock.method(globalThis, 'fetch', async (url) => {
    if (url.includes('/auth/v1/user')) return Response.json({id: 'staff'}, {status: valid ? 200 : 401});
    if (url.includes('/users?')) return Response.json([{role}]);
    return Response.json(allowed ? [{id: 'order-1'}] : []);
  });
  let listed = 0;
  const now = Date.now();
  const point = (offset, more = {}) => ({order_id: 'order-1', driver_id: 'driver', lat: 10, lng: 106,
    created_at: new Date(now + offset).toISOString(), ...more});
  const env = {SUPABASE_URL: 'https://supabase.test', SUPABASE_ANON_KEY: 'anon', ALLOWED_ORIGINS: '',
    GPS_BUCKET: {
      async list(options) {
        listed++;
        assert.equal(options.prefix, 'orders/order-1/gps/');
        return {objects: [{key: 'orders/order-1/gps/chunk'}], truncated: true, cursor: 'next'};
      },
      async get() { return {body: new Response(gzipSync([
        point(-1000), point(-5000), point(-15 * 86400000), point(60000),
        point(-1000, {order_id: 'other'}), point(-1000, {lat: 100}),
      ].map(JSON.stringify).join('\n'))).body}; },
    },
  };
  const request = () => new Request('https://gateway.test/v1/gps/history', {method: 'POST',
    headers: {authorization: 'Bearer token', 'content-type': 'application/json'}, body: JSON.stringify({orderId: 'order-1'})});
  return {env, request, listed: () => listed};
}
for (const role of ['customer', 'driver', null]) {
  test(`rejects ${role} before accessing R2`, async t => {
    const s = setup(t, {role});
    assert.equal((await worker.fetch(s.request(), s.env)).status, 403);
    assert.equal(s.listed(), 0);
  });
}
test('requires valid JWT and order access', async t => {
  const s = setup(t, {allowed: false});
  assert.equal((await worker.fetch(s.request(), s.env)).status, 403);
  assert.equal(s.listed(), 0);
});
test('invalid session cannot access GPS', async t => {
  const s = setup(t, {valid: false});
  assert.equal((await worker.fetch(s.request(), s.env)).status, 401);
  assert.equal(s.listed(), 0);
});
for (const role of ['support', 'admin']) {
  test(`${role} reads sorted retained points and pagination without cache`, async t => {
    const s = setup(t, {role});
    const response = await worker.fetch(s.request(), s.env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    const body = await response.json();
    assert.equal(body.points.length, 2);
    assert.ok(body.points[0].created_at < body.points[1].created_at);
    assert.equal(body.nextCursor, 'next');
  });
}
test('missing chunk is explicitly reported', async t => {
  const s = setup(t);
  s.env.GPS_BUCKET.get = async () => null;
  const result = await (await worker.fetch(s.request(), s.env)).json();
  assert.equal(result.unavailableChunks, 1);
  assert.deepEqual(result.points, []);
});
