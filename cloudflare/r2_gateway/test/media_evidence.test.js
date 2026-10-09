import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../src/index.js';

for (const visible of [true, false]) {
  test(`risk photo download ${visible ? 'uses unified evidence' : 'respects denied evidence access'}`, async (t) => {
    const calls = [];
    const objectUri = 'r2://media/orders/order-1/risk-evidence/report-1/photo.webp';
    t.mock.method(globalThis, 'fetch', async (input, options) => {
      const url = new URL(input);
      calls.push(url);
      assert.equal(options.headers.authorization, 'Bearer session-for-test');
      if (url.pathname === '/auth/v1/user') return Response.json({ id: 'customer-1' });
      if (url.pathname === '/rest/v1/users') return Response.json([{ role: 'customer' }]);
      assert.equal(url.pathname, '/rest/v1/risk_report_evidence');
      assert.equal(url.searchParams.get('evidence_type'), 'eq.photo');
      assert.equal(url.searchParams.get('storage_path'), `eq.${objectUri}`);
      return Response.json(visible ? [{ id: 'evidence-1' }] : []);
    });
    const response = await worker.fetch(new Request('https://gateway.test/v1/media/download-ticket', {
      method: 'POST',
      headers: { authorization: 'Bearer session-for-test', 'content-type': 'application/json' },
      body: JSON.stringify({ objectUri }),
    }), {
      SUPABASE_URL: 'https://database.test', SUPABASE_ANON_KEY: 'test-key',
      SIGNING_SECRET: 'signing-secret-long-enough-for-tests', ALLOWED_ORIGINS: '',
    });
    assert.equal(response.status, visible ? 200 : 403);
    assert.equal(calls.length, 3);
    if (visible) {
      const download = new URL((await response.json()).downloadUrl);
      assert.equal(download.pathname, '/v1/ticket/download');
      assert.ok(download.searchParams.get('payload'));
      assert.ok(download.searchParams.get('signature'));
    }
  });
}
