import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

function setup(t, { role = 'support', allowed = ['order-a'], valid = true } = {}) {
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.includes('/auth/v1/user')) return Response.json({ id: 'staff' }, { status: valid ? 200 : 401 });
    if (url.includes('/users?')) return Response.json([{ role }]);
    assert.ok(url.includes('orders?select=id&id=in.('));
    return Response.json(allowed.map(id => ({ id })));
  });
  const day = new Date().toISOString().slice(0, 10).replaceAll('-', '/');
  const stale = new Date(Date.now() - 16 * 86400000).toISOString().slice(0, 10).replaceAll('-', '/');
  let listed = 0;
  const env = { SUPABASE_URL: 'https://test.supabase.co', SUPABASE_ANON_KEY: 'anon', ALLOWED_ORIGINS: '',
    GPS_BUCKET: { async list(options) {
      listed++;
      assert.equal(options.prefix, 'orders/');
      return { objects: [
        { key: `orders/order-a/gps/${day}/chunk-1.jsonl.gz` },
        { key: `orders/order-a/gps/${day}/chunk-2.jsonl.gz` },
        { key: `orders/hidden/gps/${day}/chunk.jsonl.gz` },
        { key: `orders/stale/gps/${stale}/chunk.jsonl.gz` },
        { key: 'orders/other/cargo/photo.webp' },
      ], truncated: true, cursor: 'more' };
    } },
  };
  const request = (body = {}) => new Request('https://gateway.test/v1/gps/archives', {
    method: 'POST', headers: { authorization: 'Bearer token' }, body: JSON.stringify(body),
  });
  return { env, request, listed: () => listed };
}

for (const role of ['customer', 'driver', null]) {
  test(`archive listing rejects ${role} before R2 access`, async t => {
    const s = setup(t, { role });
    assert.equal((await worker.fetch(s.request(), s.env)).status, 403);
    assert.equal(s.listed(), 0);
  });
}
test('archive listing requires valid session', async t => {
  const s = setup(t, { valid: false });
  assert.equal((await worker.fetch(s.request(), s.env)).status, 401);
  assert.equal(s.listed(), 0);
});
test('lists retained GPS files only, respects order RLS, preserves cursor', async t => {
  const s = setup(t);
  const response = await worker.fetch(s.request(), s.env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const data = await response.json();
  assert.equal(data.archives.length, 1);
  assert.equal(data.archives[0].orderId, 'order-a');
  assert.equal(data.archives[0].chunks, 2);
  assert.equal(data.nextCursor, 'more');
});
test('invalid cursor rejected without listing', async t => {
  const s = setup(t);
  assert.equal((await worker.fetch(s.request({ cursor: 2 }), s.env)).status, 400);
  assert.equal(s.listed(), 0);
});
test('empty or unauthorized pages still keep pagination', async t => {
  const s = setup(t, { allowed: [] });
  const data = await (await worker.fetch(s.request(), s.env)).json();
  assert.deepEqual(data.archives, []);
  assert.equal(data.nextCursor, 'more');
});
